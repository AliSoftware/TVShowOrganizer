#!/usr/bin/env ruby

require 'rexml/document'
require 'net/http'

module TheTVDB
  api_key_file = File.expand_path('thetvdb.apikey', File.dirname(__FILE__))
  unless File.exist?(api_key_file)
    Log::error('Missing thetvdb.apikey file')
    exit 1
  end
  API_KEY = File.read(api_key_file).chomp.freeze

  def self.find_shows_for_name(query)
    return nil unless query
    
    url = URI.parse("http://thetvdb.com/api/GetSeries.php?seriesname=#{URI.escape(query)}")
    xml_str = Net::HTTP.get(url)
    begin
      doc = REXML::Document.new(xml_str)
    rescue
      Log::error("Invalid XML at URL #{url}")
      return nil
    end
    
    matches = []
    doc.elements.each('Data/Series') do |e|
      show_id = e.elements['seriesid'].text.to_i
      show_name = e.elements['SeriesName'].text
      matches << { :name => show_name, :id => show_id }
    end
    matches
  end
  
  def self.title_for_episode(show_id, season, episode)
    return nil unless show_id && season && episode

    url = URI.parse("http://thetvdb.com/api/#{API_KEY}/series/#{show_id}/default/#{season}/#{episode}/en.xml")
    res = Net::HTTP.get_response(url)
    begin
      doc = REXML::Document.new(res.body)
      doc.elements['Data/Episode/EpisodeName'].text
    rescue
      Log::error("Invalid XML at URL #{url}. (HTTP code: #{res.code} - XML = #{res.body.to_s})")
      return nil
    end
  end
  
  def self.url(show_id)
    "http://thetvdb.com/?tab=series&id=#{show_id}#fanart"
  end

  def self.episodes_list(show_id)
    return nil unless show_id

    url = URI.parse("http://thetvdb.com/api/#{API_KEY}/series/#{show_id}/all/en.xml")
    xml_str = Net::HTTP.get(url) # get_response takes an URI object
    begin
      doc = REXML::Document.new(xml_str)
    rescue
      Log::error("Invalid XML at URL #{url}")
      return nil
    end
    
    list = []
    doc.elements.each('Data/Episode') do |e|
      seasonNode = e.elements['SeasonNumber']
      next if seasonNode.nil?
      season = seasonNode.text.to_i
      episodeNode = e.elements['EpisodeNumber']
      next if episodeNode.nil?
      episode = episodeNode.text.to_i
      next if episode <= 0
      title = e.elements['EpisodeName'].text
      airdate_text = e.elements['FirstAired'].text
      airdate = airdate_text ? Date.strptime(airdate_text, '%Y-%m-%d') : nil
      list[season] ||= []
      list[season][episode-1] = {
        :season => season, :episode => episode,
        :airdate => airdate, :title => title }
    end
    list
  end

end


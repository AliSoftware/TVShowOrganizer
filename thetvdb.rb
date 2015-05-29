#!/usr/bin/env ruby

require 'rexml/document'
require 'net/http'

module TheTVDB
  API_KEY = File.read(File.expand_path('thetvdb.apikey', File.dirname(__FILE__))).chomp.freeze

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
    xml_str = Net::HTTP.get(url) # get_response takes an URI object
    begin
      doc = REXML::Document.new(xml_str)
    rescue
      Log::error("Invalid XML at URL #{url}")
      return nil
    end
    doc.elements['Data/Episode/EpisodeName'].text
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
      season = e.elements['SeasonNumber'].text.to_i
      episode = e.elements['EpisodeNumber'].text.to_i
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


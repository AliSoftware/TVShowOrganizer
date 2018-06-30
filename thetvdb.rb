#!/usr/bin/env ruby

require 'net/http'
require 'json'

class TheTVDB
  # attr_reader :api_key, :jwt, :http

  def initialize
    api_key_file = File.expand_path('thetvdb.apikey', File.dirname(__FILE__))
    unless File.exist?(api_key_file)
      Log::error('Missing thetvdb.apikey file')
      exit 1
    end
    @api_key = File.read(api_key_file).chomp

    @http = Net::HTTP.new("api.thetvdb.com", 443)
    @http.use_ssl = true
  end

  def self.instance
    @@instance ||= TheTVDB.new
  end

  def jwt
    @jwt ||= begin
      jwt_res = @http.request_post('/login',
        { :apikey => @api_key }.to_json,
        { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
      )
      JSON.load(jwt_res.body)
    end
  end

  # Executes an API request to TheTVDB, authenticating beforehand if necessary,
  # parsing the result as JSON and logging potential errors
  #
  # @param [String] url
  #
  # @return [(Hash, Hash)]
  #         A tuple containing the data entry and the links entry
  #
  def request(url)
    headers = {
      'Accept' => 'application/json',
      'Accept-Language' => 'en',
      'Authorization' => "Bearer #{jwt['token']}"
    }
    res = @http.request_get(url, headers)
    begin
      json = JSON.load(res.body)
      Log::error(json['Error']) if json['Error']
      [json['data'], json['links']]
    rescue
      Log::error("Invalid JSON at URL #{url}. (HTTP code: #{res.code} - Body = #{res.body.to_s})")
      return [nil, nil]
    end
  end

  ######

  def find_shows_for_name(query)
    return nil unless query
    
    data, _ = request("/search/series?name=#{URI.escape(query)}")
    return nil unless data
    data.map do |d|
      {
        :name => d['seriesName'],
        :id => d['id'],
        :date => d['firstAired'],
        :overview => d['overview']
      }
    end
  end
  
  def title_for_episode(show_id, season, episode)
    return nil unless show_id && season && episode

    data, _ = request("/series/#{show_id}/episodes/query?airedSeason=#{season}&airedEpisode=#{episode}")
    return nil unless data
    data.first['episodeName']
  end
  
  def url(show_id)
    "http://thetvdb.com/?tab=series&id=#{show_id}#fanart"
  end

  def episodes_list(show_id)
    return nil unless show_id

    list = []
    page = 1
    begin
      data, links = request("/series/#{show_id}/episodes?page=#{page}")
      break unless data
      list += data.map do |d|
        airdate = begin
          Date.strptime(d['firstAired'], '%Y-%m-%d')
        rescue ArgumentError
          nil
        end
        {
          :season => d['airedSeason'], :episode => d['airedEpisodeNumber'],
          :title => d['episodeName'],
          :airdate => airdate
        }
      end
      page = links['next']
    end until page.nil?
    list
  end

end


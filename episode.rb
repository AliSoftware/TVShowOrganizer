#!/usr/bin/env ruby

require File.expand_path('thetvdb', File.dirname(__FILE__))

class Episode
  REGEXP = /^(.*)\.S(\d{1,2})E(\d{2})(?:E(\d{2}))?\./i.freeze

  attr_reader :guessed_name
  attr_reader :show_id
  attr_reader :show_name
  attr_reader :season
  attr_reader :episodes

  def initialize(filename, show_lut)
    m = REGEXP.match(filename)
    return if m.nil?
    @guessed_name = m[1].gsub('.',' ')
    @season = m[2].to_i
    @episodes = m[3..4].compact.map(&:to_i)
    
    @show_id = find_show_id(show_lut, @guessed_name)
    @show_name = find_show_name(show_lut, @show_id)
  end

  def titles
    @titles ||= episodes.map { |ep| TheTVDB::title_for_episode(show_id, season, ep).strip }
  end

  def to_s
    "<#{show_name || '~' + guessed_name} - #{season}x#{episodes.join('+')}>"
  end

  private

  def find_show_id(lut, show_name)
    return nil if show_name.nil?
    show_key = lookup_key(show_name)
    match = lut.find do |(k,v)|
      lookup_key(k) == show_key
    end
    match.nil? ? nil : match[1] 
  end

  def find_show_name(lut, show_id)
    return nil if show_id.nil?
    match = lut.find do |(k,v)|
      v == show_id
    end
    match.nil? ? nil : match[0]
  end
  
  def lookup_key(string)
    string.downcase.gsub(/[^A-Za-z0-9]/,'')
  end
end
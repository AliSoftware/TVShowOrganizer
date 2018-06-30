#!/usr/bin/env ruby

require File.expand_path('thetvdb', File.dirname(__FILE__))

# This class represent a TVShow episode's meta-information
# Especially the TVShow ID (in thetvdb.com), name, season number and episode number
#
# It is also able to handle multi-part episodes, and fetch the title of a givn episode
# using the TheTVDB Module and thetvdb.com API
# 
class Episode
  REGEXP1 = /^(.*)\.S(\d{1,2})E(\d{2})(?:[-+]?E(\d{2}))?\./i.freeze
  REGEXP2 = /^(.*)\.(\d{1,2})x(\d{2})(?:[-+](\d{2}))?\./i.freeze

  attr_reader :guessed_name
  attr_reader :show_id
  attr_reader :show_name
  attr_reader :season
  attr_reader :episodes

  # Create an Episode instance extracting the meta-information of an episode
  # From a file name and the Show Lookup Table
  # 
  # @param [String] filepath
  #         The path to the file to construct the metainformation from
  # @param [Hash<String, Int>] show_lut
  #        Note: this LUT is generally read from the shows.yml YAML file
  #
  def initialize(filepath, show_lut)
    m = REGEXP1.match(File.basename(filepath))
    m = REGEXP1.match(File.dirname(filepath)) if m.nil?
    m = REGEXP2.match(File.basename(filepath)) if m.nil?
    m = REGEXP2.match(File.dirname(filepath)) if m.nil?
    return if m.nil?

    @guessed_name = m[1].gsub('.',' ')
    @season = m[2].to_i
    @episodes = m[3..4].compact.map(&:to_i)
    
    @show_id = find_show_id(show_lut, @guessed_name)
    @show_name = find_show_name(show_lut, @show_id)
  end

  def titles
    @titles ||= episodes.map { |ep| TheTVDB.instance.title_for_episode(show_id, season, ep).strip }
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

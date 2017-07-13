#!/usr/bin/env ruby

require 'pathname'
require 'fileutils'
require File.expand_path('episode', File.dirname(__FILE__))
  
class FileMover
  attr_accessor :minimum_file_size
  attr_accessor :dry_run
  attr_accessor :interactive
  alias :interactive? :interactive

  def initialize(source_dir, dest_dir, show_lut)
    @source_dir = Pathname.new(source_dir)
    @dest_dir = Pathname.new(dest_dir)
    @show_lut = show_lut
    @minimum_file_size = 10*1024*1024 # Files smaller than 10Mo are probably samples, not the real episode
    @dry_run = false
    @interactive = false
  end

  # @return [Pathname]
  #
  def target_path(ep, ext)
    show_dir = @dest_dir + ep.show_name
    season_dirname = "Season #{ep.season}"
    epNum = ep.episodes.map { |e| ep.season.to_s + 'x' + e.to_s.rjust(2,'0') }.join('+')
    epTitle = ep.titles.join(' + ')
    
    # Special case if the episode is in 2 parts and the two parts have the same title
    # Like "XXX (Part 1)" and "XXX (Part 2)", then be a bit more clever for the ep title
    if ep.titles.count == 2 && ep.titles[0].length == ep.titles[1].length
      (t1,t2) = ep.titles
      pos = (0..t1.length-1).find { |i| t1[i] != t2[i] } # Find first differing char
      if t1[pos].chr == '1' && t2[pos].chr == '2' && t1[pos+1..-1] == t2[pos+1..-1]
        # If only differing char is '1' vs '2' (and is the only difference)
        t1[pos] = '1+2' # then use the one of the two titles and replace with '1+2'
        epTitle = t1 # and use as the episode title instead.
      end
    end
    
    target_basename = "#{ep.show_name} - #{epNum} - #{epTitle.gsub(':', ' -')}"
    show_dir + season_dirname + (target_basename + ext)
  end

  # Move a single file to destination, based on the episode metainfo (show, season, episode, title)
  # Creating intermediate directories if necessary
  #
  # @param [String] filename
  #        The name of the file to move
  # @param [Episode] ep
  #        The Episode object containing the episode metainfo (show, season, episode(s), title(s), …)
  #
  def move_episode(filename, ep)
    if ep.titles && ep.titles.all? # No nil episode title
      target_path = target_path(ep, File.extname(filename))
      season_dir = target_path.parent
      show_dir = season_dir.parent
      unless show_dir.directory?
        Log::info("Creating directory for #{show_dir.basename}")
        show_dir.mkdir()
      end
      unless season_dir.directory?
        Log::info("Creating directory for #{season_dir.basename}")
        season_dir.mkdir()
      end
      if File.exist?(target_path)
        Log::error("File #{target_path.to_s} already exists.")
        false
      else
        Log::success("Moving to #{target_path.to_s}")
        FileUtils.mv(filename, target_path.to_s) unless @dry_run
        true
      end
    else
      Log::error("Unable to find title for #{filename}")
      false
    end
  end

  # Iterate over all movie files in the @source_dir and move them
  # in the appropriate Show/Season/Episode.ext destination
  #
  def move_finished_downloads
    Log::info('DRY MODE ON') if dry_run

    unless @source_dir.directory? && @dest_dir.directory?
      Log::error('Source and Destination must be existing directories')
      return 0
    end
      
    files_count = 0
    Dir.chdir(@source_dir.to_s) do
      movie_files = Dir.glob('**/*.{mp4,mkv,avi,m4v}')
      Log::info("#{movie_files.count} video file(s) found.")
      movie_files.each do |filename|
        Log::title(filename)
        if File.size(filename) < @minimum_file_size
          Log::info("Skipping (file too small, probably sample)")
          next
        end
        
        # Guess the episode info (TVShow, season, episode number, episode title) based on the file name
        ep = Episode.new(filename, @show_lut)

        # If episode not found but we are in interactive mode, prompt to add the show to the show_lut
        if ep.show_id.nil? && interactive?
          shows = TheTVDB::find_shows_for_name(ep.guessed_name) || []
          shows.each do |show|
            url = TheTVDB::url(show[:id])
            if Log::prompt("Map '#{ep.guessed_name}' to show '#{show[:name]}' with ID #{show[:id]}", url)
              # /!\ Add show with the guessed name, not its real name
              TVShowsOrganizer::add_show({:name => ep.guessed_name, :id => show[:id]})
              @show_lut[ep.guessed_name] = show[:id]
              # Refetch
              ep = Episode.new(filename, @show_lut)
              break
            end
          end
        end

        if ep.show_id.nil?
          Log::error("Unable to find show matching '#{ep.guessed_name}'")
        else
          Log::info("Detected: #{ep.to_s}")
          ok = move_episode(filename, ep)
          files_count += 1 if ok
        end

      end # next movie
    end # chdir
  
    files_count
  end
end

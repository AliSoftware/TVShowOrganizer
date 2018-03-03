#!/usr/bin/env ruby


require 'yaml'
require 'optparse'
require File.expand_path('log_module', File.dirname(__FILE__))
require File.expand_path('file_mover', File.dirname(__FILE__))
require File.expand_path('kodi', File.dirname(__FILE__))
require File.expand_path('thetvdb', File.dirname(__FILE__))

CONFIG_FILE = File.expand_path('shows.yml', File.dirname(__FILE__))

###############################################################################

module TVShowsOrganizer

  # Add a show to the `shows.yml` database
  #
  # @param [Hash<Symbol,String>] show
  #        Hash describing the show to be added.
  #        This hash must contain the following keys:
  #        :name : The show name (String)
  #        :id   : TheTVDB's ID to associate to that show (String)
  #
  def self.add_show(show)
    list = YAML.load_file(CONFIG_FILE)
    list[show[:name]] = show[:id]
    File.open(CONFIG_FILE, 'w') { |f| f.write(list.to_yaml) }
    Log::info("Show added: #{show[:name]} => #{show[:id]}")
  end

  # Run a TheTVDB query to find show that match a given name.
  #
  # @param [Hash<Symbol,String>] options
  #        The hash containing the parameters for the query.
  #        This hash may contain the following keys:
  #         :query        : The name of the show to find (mandatory)
  #         :interactive  : If true, prompt to add the show to `shows.yml`
  #
  def self.run_query(options)
    shows = TheTVDB::find_shows_for_name(options[:query])
    if shows.count > 0
      shows.each do |show|
        Log::success("#{show[:name]} ==> #{show[:id]}")
        if options[:interactive]
          if Log::prompt('Add to list', TheTVDB::url(show[:id]))
            add_show(show)
            break
          end
        end # interactive?
      end # next found show
    else
      Log::error('Show not found')
    end
  end

  # Move the video files from the source dir to the destination dir,
  # renaming them according the the shows name, season, episode and title.
  #
  # @param [String] source
  #        The source directory
  # @param [String] destination
  #        The destination directory
  # @param [Hash<Symbol,String>] options
  #        The hash containing the parameters for the query.
  #        This hash may contain the following keys:
  #         :kodi         : Hash with keys :credentials ('login:pass'), :host and :port, to use for Kodi's refresh request
  #         :interactive  : If true, prompt to add the show to `shows.yml`
  #         :dry_run      : If true, no file will actually be moved,
  #                         but logs will be printed so you can check which
  #                         actions would have been performed.
  #
  def self.move_files(source, destination, options)
    Log::info("Source:      #{source}")
    Log::info("Destination: #{destination}")
    
    shows_db = YAML.load_file(CONFIG_FILE)

    fm = FileMover.new(source, destination, shows_db)
    fm.dry_run = options[:dry_run]
    fm.interactive = options[:interactive]
  
    files_count = fm.move_finished_downloads()

    Log::title('Finished!')

    kodi_params = options[:kodi]
    Kodi::refresh(kodi_params[:credentials], kodi_params[:host], kodi_params[:port]) if files_count>0 && !kodi_params.nil?
  end
  
  # Return the local file corresponding to the last episode of the show for the given show path
  #
  # @param [Pathname] show_path
  #        The Pathname to the show's directory to search for the last season & episode
  # @return [Hash<Symbol, String>] 
  #         A tuple with keys :num and :title describing the last episode found locally for the show
  #         Or nil if none was found
  #
  def self.last_local_episode(show_path)
    # Return a season number from a Pathname to a Season dir
    get_season = lambda do |p|
      p.basename.to_s.sub(/^Season /,'').to_i
    end

    season_dirs = show_path.children.select { |p| p.directory? && p.basename.to_s.start_with?('Season ') }
    sorted_seasons = season_dirs.sort { |p1,p2| get_season.call(p1) <=> get_season.call(p2) }
    last_season = sorted_seasons.last
    return nil if last_season.nil?
    last_ep = last_season.children.select { |p| p.file? && !p.to_s.start_with?('.') }.sort.last
    basename = last_ep.basename(last_ep.extname).to_s
    match = basename.match(/^.+ - ([0-9x+-]+) - (.+)$/)
    return match.nil? ? nil : { :num => match[1], :title => match[2] }
  end

  def self.list_last_episodes(destination = nil, show_locals = false)
    shows_db = YAML.load_file(CONFIG_FILE)
    today = Date.today
    shows_db.each do |show_title,show_id|
      Log::title(show_title)

      if destination && show_locals
        local = last_local_episode(Pathname.new(destination) + show_title)
        Log::info("Last local: #{local[:num]} - #{local[:title]}") if local
      end

      # Fetch list of episodes for the show
      list = TheTVDB.episodes_list(show_id)
      if list.nil?
        Log::error("Can't retrieve list of episodes for this show")
        next
      end

      # Find the last aired and next aired
      last_aired, next_aired = [nil, nil]
      list.flatten.compact.each do |e|
        next if e[:airdate].nil?
        last_aired = e if (last_aired.nil? || last_aired[:airdate] <= e[:airdate]) && e[:airdate] <= today
        next_aired = e if (next_aired.nil? || next_aired[:airdate] >= e[:airdate]) && e[:airdate] > today
      end
      
      ep2str = lambda do |e|
        "#{e[:season]}x#{e[:episode]} - #{e[:title]} (#{e[:airdate]})"
      end
      unless last_aired.nil?
        log_text = "Last aired: #{ep2str.call(last_aired)}"
        if destination
          show_dir = Pathname.new(destination) + show_title + "Season #{last_aired[:season]}"
          ep_num = "#{last_aired[:season]}x#{last_aired[:episode].to_s.rjust(2,'0')}"
          filename = "#{show_title} - {?x??+,}#{ep_num}*"
          # puts "Testing: <#{show_dir + filename}>"
          if Dir.glob("#{show_dir + filename}.*", File::FNM_CASEFOLD).count > 0
            Log::success(log_text + " [OK]")
          elsif last_aired[:season] == 0
            Log::warning(log_text + " [Missing Special]")
          else
            Log::error(log_text + " [Missing]")
          end
        else
          Log::info(log_text)
        end
      end
      unless next_aired.nil?
        Log::info("Next aired: #{ep2str.call(next_aired)}")
      end
    end
  end
end



###############################################################################

if __FILE__ == $0
  options = {}
  OptionParser.new do |opts|
    opts.banner = "#{opts.program_name} [options] INPUT_DIR OUTPUT_DIR\n\n" \
    + <<-SUMMARY.gsub(/^ +/,'  ')
      Renames your TVShows video files by detecting the show name,
      season and episode from the file name, then fetching the
      episode title from thetvdb.org to generate a nicer file name.
      
      The list of known shows is configurable in shows.yml
    SUMMARY
    
    opts.separator ''
    opts.separator 'Options'

    opts.on('-n', '--dryrun', %q(Don't actually move any file)) do
      options[:dry_run] = true
    end
    opts.on('-qQUERY', '--query QUERY', %q(Search the ShowID of a given show name)) do |query|
      options[:query] = query
    end
    opts.on('-i', %q(Prompt to add a show to the config when queried or unknown)) do
      options[:interactive] = true
    end
    opts.on('-l', '--list', %q(List the last episode of each known series)) do
      options[:list] = true
    end
    opts.on('--local', %q(When used with --list, also log the last local episode)) do
      options[:local] = true
    end
    opts.on('--kodi login:pass@host:port', %q(The login/password and host/port to use to access the Kodi HTTP interface)) do |kodi_string|
      (login_pass, host_port, rest) = kodi_string.split('@')
      Log::error("Too many '@' in the Kodi parameters!") unless rest.nil?
      (host, port, rest) = host_port.split(':')
      Log::error("Too many ':' in the host:port part of Kodi parameters!") unless rest.nil?
      Log::error("Port should be numeric") unless port.to_i > 0
      options[:kodi] = { :credentials => login_pass, :host => host, :port => port.to_i }
    end

    opts.on('-h', '--help') { puts opts; exit 1 }
  end.parse!

  if options[:query]
    TVShowsOrganizer::run_query(options)
  elsif options[:list]
    dest = ARGV.count < 1 ? nil : ARGV[0]
    TVShowsOrganizer::list_last_episodes(dest, options[:local])
  else
    if ARGV.count < 2
      Log::error('You need to specify source and destination directories!')
    else
      TVShowsOrganizer::move_files(ARGV[0], ARGV[1], options)
    end
  end

end

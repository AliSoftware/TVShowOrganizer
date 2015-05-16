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
  #         :kodi_auth    : The 'login:pass' pair to use for Kodi's refresh request
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
    Kodi::refresh(options[:kodi_auth]) if files_count>0
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
    opts.on('--kodi login:pass', %q(The login and password to use to access the Kodi HTTP interface)) do |login_pass|
      options[:kodi_auth] = login_pass
    end

    opts.on('-h', '--help') { puts opts; exit 1 }
  end.parse!

  if options[:query]
    TVShowsOrganizer::run_query(options)
  else
    if ARGV.count < 2
      Log::error('You need to specify source and destination directories!')
    else
      TVShowsOrganizer::move_files(ARGV[0], ARGV[1], options)
    end
  end

end

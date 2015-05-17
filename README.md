# TV Show Organizer

This is a little ruby tool to automatically rename TV Show video files (according to my naming preference) and move them to the appropriate directory (appropriate for XBMC/Kodi).

## Features

This took takes an input folder and output folder, then it:

* looks for files with extension `mp4`,`m4v`,`avi` or `mkv` in the input folder (discarding filenames containing `Sample`)
* parses the file name to extract the TVShow name, season number and episode number.  
  _(To do that, it expects the file name to match `Show.Name.S01E02.Anything.ext`)_
* fetches the name of the episode using [TheTVDB](http://thetvdb.com) [API](http://thetvdb.com/wiki/index.php?title=Programmers_API)
* renames the file to `Show Name - 1x02 - Episode Title.ext` and moves it to the subfolder `Show Name/Season 1/` of the output folder.

Once every video files of the input folder have been moved and renamed appropriately, it finally uses [Kodi](http://kodi.tv/about/)'s [JSON-RPC API](http://kodi.wiki/view/JSON-RPC_API/v6) to refresh the Kodi database, so that those shows appear in your Kodi library.


## Usage

1. the `TheTVDB` API needs an API Key to use it. You need to get one and write it to a file named `thetvdb.apikey` saved next to the other files so that the script can use it.
2. Then use `tvshows_organizer.rb` as the entry point, invoked either from ruby code (using `TVShowsOrganizer` module) or from the command line

### Invoke from ruby

```ruby
require 'tvshows_organizer'
# Search the TheTVDB's show ID of a given show
TVShowsOrganizer::run_query(:query => 'Game of Thrones')
# Add a show to the shows.yml database
TVShowsOrganizer::add_show(:name => 'Game of Thrones', :id => '121361')
# Move video files to destination, renaming them appropriately.
TVShowsOrganizer::move_files(source_dir, dest_dir, :interactive => true, :kodi_auth => 'login:pass')
```

### Invoke from the command line

Use `tvshows_organizer.rb --help` to know how to use it and which options are available.

```sh
# Search the TheTVDB's show ID of a given show
$ ./tvshows_organizer.rb -q "House of Cards"
# Add a show to the shows.yml database: use query + interactive mode
$ ./tvshows_organizer.rb -qi "House of Cards"
# Move video files to destination, renaming them appropriately.
$ ./tvshows_organizer.rb -i source_dir dest_dir --kodi login:pass
```

# TV Show Organizer

This is a little ruby tool to automatically rename TV Show video files and move them to the appropriate directory, according to my personal conventions.

### Features

* It takes an input folder and output folder as parameters
* it looks for files with extension `mp4`,`m4v`,`avi` or `mkv` in the input folder (discarding filenames containing `Sample`)
* it parses the file name to extract the TVShow name, season number and episode number. To do that, it expects the file name to match `Show.Name.S01E02.Anything.ext`
* it fetches the name of the episode using [TheTVDB](http://thetvdb.com) [API](http://thetvdb.com/wiki/index.php?title=Programmers_API)
* it renames the file to `Show Name - 1x02 - Episode Title.ext` and moves it to the subfolder `Show Name/Season 1/` of the output folder.
* Once every video files of the input folder have been moved and renamed appropriately, it uses [Kodi](http://kodi.tv/about/)'s [JSON-RPC API](http://kodi.wiki/view/JSON-RPC_API/v6) to refresh my Kodi database so that those shows appear in my Kodi library.


### Usage

```
TVShowsOrganizer::move_files(source_dir, dest_dir, :interactive => true, :kodi_auth => 'Basic eGJtYzp4Ym1j')
```

* Using `:interactive => true`, the script will ask for unknown TV Show names (shows that are not listed in `shows.yml`) if the user want to add it. It will propose every matching show known to TheTVDB and propose to open the show web page on thetvdb.com to ensure that's the correct show we are talking about (as sometimes multiple shows with the same name exists).
* The `:kodi_auth` option allows you to specify the content of the `Authentication` header for the refresh request (JSON-RPC API) to Kodi. This typically is a Basic Auth, so should be `"Basic #{base64_encode(login+':'+password)}"` followed by the base64-encoded string `login:password`

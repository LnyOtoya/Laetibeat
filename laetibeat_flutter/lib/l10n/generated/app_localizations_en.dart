// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Laetibeat';

  @override
  String get homeTitle => 'Home';

  @override
  String get libraryTitle => 'Library';

  @override
  String get searchTitle => 'Search';

  @override
  String get navHome => 'Home';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSearch => 'Search';

  @override
  String get searchHint => 'Search songs, artists, albums';

  @override
  String get switchSearchSource => 'Switch search source';

  @override
  String get actionMusicSources => 'Music sources';

  @override
  String get actionStatistics => 'Statistics';

  @override
  String get actionSettings => 'Settings';

  @override
  String get librarySongs => 'Songs';

  @override
  String get libraryPlaylists => 'Playlists';

  @override
  String get libraryArtists => 'Artists';

  @override
  String get libraryAlbums => 'Albums';

  @override
  String get libraryPodcasts => 'Podcasts';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get displayGroup => 'Display';

  @override
  String get songSource => 'Song source';

  @override
  String get songSourceSupporting =>
      'Choose the default source shown in song lists';

  @override
  String get songSort => 'Song sorting';

  @override
  String get songSortSupporting => 'Choose the default song sorting method';

  @override
  String get language => 'Language';

  @override
  String get languageSupporting => 'Choose the app display language';

  @override
  String get languageDialogTitle => 'Language';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsSearchHint => 'Search settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSupporting => 'Theme and light/dark mode';

  @override
  String get settingsPlaybackAudio => 'Player & audio';

  @override
  String get settingsPlaybackAudioSupporting => 'Fade and battery optimization';

  @override
  String get settingsContent => 'Content';

  @override
  String get settingsContentSupporting => 'Library, lyrics and language';

  @override
  String get settingsStorage => 'Storage';

  @override
  String get settingsStorageSupporting => 'Cache management';

  @override
  String get settingsBackupRestore => 'Backup & restore';

  @override
  String get settingsBackupRestoreSupporting =>
      'Back up settings or import from another configuration';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutSupporting => 'Current version';

  @override
  String get lyricsGroup => 'Lyrics';

  @override
  String get lyricsSource => 'Lyrics source';

  @override
  String get lyricsSourceSupporting =>
      'Choose which lyrics sources are enabled';

  @override
  String get lyricsSourceTags => 'Lyrics tags';

  @override
  String get lyricsSourceTagsIncludingServer =>
      'Lyrics tags (including server default)';

  @override
  String get lyricsSourceLrclib => 'LRCLIB';

  @override
  String get closeLyricsPriority => 'Close lyrics source priority';

  @override
  String get lyricsPriorityHint => 'Long-press and drag to reorder';

  @override
  String get lyricsReorderHandle => 'Drag to reorder lyrics sources';

  @override
  String get lyricsPriority => 'Lyrics source priority';

  @override
  String get lyricsPrioritySupporting => 'Reorder lyrics sources by preference';

  @override
  String get lyricsReset => 'Reset imported lyrics';

  @override
  String get lyricsResetSupporting =>
      'Remove all imported lyrics from the database';

  @override
  String get syncScanGroup => 'Sync & scan';

  @override
  String get chooseLocalLibrary => 'Choose local library';

  @override
  String get chooseLocalLibrarySupporting =>
      'Choose the folder that contains your music';

  @override
  String get chooseLibrary => 'Choose library';

  @override
  String get syncDatabase => 'Sync database';

  @override
  String get musicSourcesTitle => 'Music sources';

  @override
  String get openSubsonicDescription =>
      'Connect to an OpenSubsonic-compatible server, such as Navidrome.';

  @override
  String get notAvailable => 'Not available yet';

  @override
  String get sourceJellyfin => 'Jellyfin';

  @override
  String get sourceEmbyMusic => 'Emby Music';

  @override
  String get sourceLxMusic => 'LX Music';

  @override
  String get statisticsTitle => 'Statistics';

  @override
  String get commonBack => 'Back';

  @override
  String get previousTrack => 'Previous track';

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Play';

  @override
  String get nextTrack => 'Next track';

  @override
  String get musicLibraryEmpty => 'Your library is empty';

  @override
  String get goToSettingsScan =>
      'Open settings to choose a music folder and start scanning';

  @override
  String get nothingPlaying => 'Nothing playing';

  @override
  String get chooseSongToPlay =>
      'Choose a song from your library to start playing';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get fullScreen => 'Full screen';

  @override
  String get exitFullScreen => 'Exit full screen';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get shufflePlayback => 'Shuffle';

  @override
  String get repeatPlayback => 'Repeat';

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String get queueButton => 'Queue';

  @override
  String get more => 'More';

  @override
  String get queueTitle => 'Play queue';

  @override
  String queueCount(int count) {
    return '$count songs';
  }

  @override
  String get closeQueue => 'Close queue';

  @override
  String get queueEmpty => 'Queue is empty';

  @override
  String get queueEmptySubtitle =>
      'Choose songs from your library to start playing';

  @override
  String get addToQueue => 'Add to queue';

  @override
  String get hideLyrics => 'Hide lyrics';

  @override
  String get showLyrics => 'Show lyrics';

  @override
  String get randomPlay => 'Shuffle';

  @override
  String get sortLabel => 'Sort';

  @override
  String get currentSource => 'Current source: ';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get exitSelection => 'Exit selection';

  @override
  String get playNow => 'Play now';

  @override
  String get playNext => 'Play next';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get sortBy => 'Sort by';

  @override
  String get closeSort => 'Close sorting';

  @override
  String get noSongs => 'No songs';

  @override
  String get configureSubsonicFirst => 'Configure a Subsonic source first';

  @override
  String get loadRemoteSongsFailed => 'Failed to load remote songs';

  @override
  String get noRemoteSongsScan =>
      'No remote songs yet. Scan your library in Content settings first.';

  @override
  String get sourceUnavailable => 'This source is not available yet';

  @override
  String get noPlaylists => 'No playlists yet';

  @override
  String get loadPlaylistsFailed => 'Failed to load playlists';

  @override
  String get noArtists => 'No artists yet';

  @override
  String get loadArtistsFailed => 'Failed to load artists';

  @override
  String get noAlbums => 'No albums yet';

  @override
  String get loadAlbumsFailed => 'Failed to load albums';

  @override
  String get switchToList => 'Switch to list layout';

  @override
  String get switchToGrid => 'Switch to grid layout';

  @override
  String get like => 'Like';

  @override
  String releaseDate(String year) {
    return 'Released: $year';
  }

  @override
  String get unknown => 'Unknown';

  @override
  String albumSummary(String count, String duration) {
    return '$count songs, $duration';
  }

  @override
  String get loadTracksFailed => 'Failed to load songs';

  @override
  String get noTracks => 'No songs yet';

  @override
  String discNumber(int number) {
    return 'Disc $number';
  }

  @override
  String get durationUnknown => 'Duration unknown';

  @override
  String totalAlbums(String count) {
    return '$count albums';
  }

  @override
  String get topSongs => 'Top songs';

  @override
  String get shufflePlay => 'Shuffle';

  @override
  String get publicData => 'Public data';

  @override
  String get noArtistBio => 'No artist biography yet';

  @override
  String get artistAlbums => 'Artist albums';

  @override
  String get yearUnknown => 'Year unknown';

  @override
  String approxMinutes(int minutes) {
    return 'About $minutes min';
  }

  @override
  String get lessThanMinute => 'Less than 1 min';

  @override
  String get serverUrlRequired => 'Enter the server URL';

  @override
  String get serverUrlInvalid => 'Enter a valid server URL';

  @override
  String get portInvalid => 'Enter a valid port';

  @override
  String get usernameRequired => 'Enter a username';

  @override
  String get passwordRequired => 'Enter a password';

  @override
  String get connectionSuccess => 'Connection successful: ';

  @override
  String get syncFetchingArtists => 'Fetching artists…';

  @override
  String syncAlbumsProgress(int count) {
    return 'Fetched $count albums';
  }

  @override
  String get syncFetchingAlbums => 'Fetching albums…';

  @override
  String syncTracksProgress(int completed, int total) {
    return 'Fetching tracks $completed/$total';
  }

  @override
  String syncTracksCount(int count) {
    return 'Fetching tracks: $count';
  }

  @override
  String get syncScanning => 'Scanning…';

  @override
  String syncFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get syncRetry => 'Try again later';

  @override
  String syncComplete(int count) {
    return 'Scan complete: $count songs';
  }

  @override
  String get serverUrlLabel => 'Server URL';

  @override
  String get serverUrlSupporting => 'Configured URL';

  @override
  String get portLabel => 'Port';

  @override
  String get portSupporting => 'Port number';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get testingButton => 'Testing…';

  @override
  String get testButton => 'Test';

  @override
  String get scanningButton => 'Scanning…';

  @override
  String get scanButton => 'Scan';

  @override
  String get scanningSemantics => 'Scanning';

  @override
  String get lyricsNotPlayingTitle => 'Nothing playing';

  @override
  String get lyricsNotPlayingSubtitle =>
      'Choose a song from your library to view lyrics';

  @override
  String get lyricsLoading => 'Loading lyrics';

  @override
  String get lyricsLoadFailed => 'Failed to load lyrics';

  @override
  String get lyricsEmptyTitle => 'No lyrics';

  @override
  String get lyricsEmptySubtitle => 'No lyrics are available for this track';

  @override
  String get notificationChannelName => 'Playback';

  @override
  String get notificationChannelDescription => 'Laetibeat playback controls';

  @override
  String get searchSource => 'Search source';

  @override
  String get searchSourceLocal => 'Local music';

  @override
  String get searchSourceSubsonic => 'Subsonic';

  @override
  String get searchPrompt => 'Search songs, artists, and albums';

  @override
  String get searchNoResults => 'No results found';

  @override
  String get searchConfigureSubsonic => 'Configure a Subsonic source first';

  @override
  String get searchLocalLoading => 'Loading local library…';

  @override
  String get searchRemoteLoading => 'Searching…';

  @override
  String get searchFailed => 'Search failed';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeGreetingQuestion => 'What would you like to listen to?';

  @override
  String homeGreetingWithName(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String get searchRecentTitle => 'Recent searches';

  @override
  String get searchRecentEmpty => 'No recent searches';

  @override
  String get searchRecentClear => 'Clear';

  @override
  String get searchRemoteNotSynced => 'Remote library is not synced yet';
}

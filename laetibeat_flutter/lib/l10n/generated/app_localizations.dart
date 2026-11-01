import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Laetibeat'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search songs, artists, albums'**
  String get searchHint;

  /// No description provided for @switchSearchSource.
  ///
  /// In en, this message translates to:
  /// **'Switch search source'**
  String get switchSearchSource;

  /// No description provided for @actionMusicSources.
  ///
  /// In en, this message translates to:
  /// **'Music sources'**
  String get actionMusicSources;

  /// No description provided for @actionStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get actionStatistics;

  /// No description provided for @actionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get actionSettings;

  /// No description provided for @librarySongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get librarySongs;

  /// No description provided for @libraryPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get libraryPlaylists;

  /// No description provided for @libraryArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get libraryArtists;

  /// No description provided for @libraryAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get libraryAlbums;

  /// No description provided for @libraryPodcasts.
  ///
  /// In en, this message translates to:
  /// **'Podcasts'**
  String get libraryPodcasts;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @displayGroup.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get displayGroup;

  /// No description provided for @songSource.
  ///
  /// In en, this message translates to:
  /// **'Song source'**
  String get songSource;

  /// No description provided for @songSourceSupporting.
  ///
  /// In en, this message translates to:
  /// **'Choose the default source shown in song lists'**
  String get songSourceSupporting;

  /// No description provided for @songSort.
  ///
  /// In en, this message translates to:
  /// **'Song sorting'**
  String get songSort;

  /// No description provided for @songSortSupporting.
  ///
  /// In en, this message translates to:
  /// **'Choose the default song sorting method'**
  String get songSortSupporting;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSupporting.
  ///
  /// In en, this message translates to:
  /// **'Choose the app display language'**
  String get languageSupporting;

  /// No description provided for @languageDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageDialogTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @settingsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsSearchHint;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSupporting.
  ///
  /// In en, this message translates to:
  /// **'Theme and light/dark mode'**
  String get settingsAppearanceSupporting;

  /// No description provided for @settingsPlaybackAudio.
  ///
  /// In en, this message translates to:
  /// **'Player & audio'**
  String get settingsPlaybackAudio;

  /// No description provided for @settingsPlaybackAudioSupporting.
  ///
  /// In en, this message translates to:
  /// **'Fade and battery optimization'**
  String get settingsPlaybackAudioSupporting;

  /// No description provided for @settingsContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get settingsContent;

  /// No description provided for @settingsContentSupporting.
  ///
  /// In en, this message translates to:
  /// **'Library, lyrics and language'**
  String get settingsContentSupporting;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorage;

  /// No description provided for @settingsStorageSupporting.
  ///
  /// In en, this message translates to:
  /// **'Cache management'**
  String get settingsStorageSupporting;

  /// No description provided for @settingsBackupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get settingsBackupRestore;

  /// No description provided for @settingsBackupRestoreSupporting.
  ///
  /// In en, this message translates to:
  /// **'Back up settings or import from another configuration'**
  String get settingsBackupRestoreSupporting;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutSupporting.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get settingsAboutSupporting;

  /// No description provided for @lyricsGroup.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyricsGroup;

  /// No description provided for @lyricsSource.
  ///
  /// In en, this message translates to:
  /// **'Lyrics source'**
  String get lyricsSource;

  /// No description provided for @lyricsSourceSupporting.
  ///
  /// In en, this message translates to:
  /// **'Choose which lyrics sources are enabled'**
  String get lyricsSourceSupporting;

  /// No description provided for @lyricsSourceTags.
  ///
  /// In en, this message translates to:
  /// **'Lyrics tags'**
  String get lyricsSourceTags;

  /// No description provided for @lyricsSourceTagsIncludingServer.
  ///
  /// In en, this message translates to:
  /// **'Lyrics tags (including server default)'**
  String get lyricsSourceTagsIncludingServer;

  /// No description provided for @lyricsSourceLrclib.
  ///
  /// In en, this message translates to:
  /// **'LRCLIB'**
  String get lyricsSourceLrclib;

  /// No description provided for @closeLyricsPriority.
  ///
  /// In en, this message translates to:
  /// **'Close lyrics source priority'**
  String get closeLyricsPriority;

  /// No description provided for @lyricsPriorityHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press and drag to reorder'**
  String get lyricsPriorityHint;

  /// No description provided for @lyricsReorderHandle.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder lyrics sources'**
  String get lyricsReorderHandle;

  /// No description provided for @lyricsPriority.
  ///
  /// In en, this message translates to:
  /// **'Lyrics source priority'**
  String get lyricsPriority;

  /// No description provided for @lyricsPrioritySupporting.
  ///
  /// In en, this message translates to:
  /// **'Reorder lyrics sources by preference'**
  String get lyricsPrioritySupporting;

  /// No description provided for @lyricsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset imported lyrics'**
  String get lyricsReset;

  /// No description provided for @lyricsResetSupporting.
  ///
  /// In en, this message translates to:
  /// **'Remove all imported lyrics from the database'**
  String get lyricsResetSupporting;

  /// No description provided for @syncScanGroup.
  ///
  /// In en, this message translates to:
  /// **'Sync & scan'**
  String get syncScanGroup;

  /// No description provided for @chooseLocalLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose local library'**
  String get chooseLocalLibrary;

  /// No description provided for @chooseLocalLibrarySupporting.
  ///
  /// In en, this message translates to:
  /// **'Choose the folder that contains your music'**
  String get chooseLocalLibrarySupporting;

  /// No description provided for @chooseLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose library'**
  String get chooseLibrary;

  /// No description provided for @syncDatabase.
  ///
  /// In en, this message translates to:
  /// **'Sync database'**
  String get syncDatabase;

  /// No description provided for @musicSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Music sources'**
  String get musicSourcesTitle;

  /// No description provided for @openSubsonicDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to an OpenSubsonic-compatible server, such as Navidrome.'**
  String get openSubsonicDescription;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get notAvailable;

  /// No description provided for @sourceJellyfin.
  ///
  /// In en, this message translates to:
  /// **'Jellyfin'**
  String get sourceJellyfin;

  /// No description provided for @sourceEmbyMusic.
  ///
  /// In en, this message translates to:
  /// **'Emby Music'**
  String get sourceEmbyMusic;

  /// No description provided for @sourceLxMusic.
  ///
  /// In en, this message translates to:
  /// **'LX Music'**
  String get sourceLxMusic;

  /// No description provided for @statisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statisticsTitle;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @previousTrack.
  ///
  /// In en, this message translates to:
  /// **'Previous track'**
  String get previousTrack;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @nextTrack.
  ///
  /// In en, this message translates to:
  /// **'Next track'**
  String get nextTrack;

  /// No description provided for @musicLibraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get musicLibraryEmpty;

  /// No description provided for @goToSettingsScan.
  ///
  /// In en, this message translates to:
  /// **'Open settings to choose a music folder and start scanning'**
  String get goToSettingsScan;

  /// No description provided for @nothingPlaying.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get nothingPlaying;

  /// No description provided for @chooseSongToPlay.
  ///
  /// In en, this message translates to:
  /// **'Choose a song from your library to start playing'**
  String get chooseSongToPlay;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlaying;

  /// No description provided for @fullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get fullScreen;

  /// No description provided for @exitFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get exitFullScreen;

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @shufflePlayback.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shufflePlayback;

  /// No description provided for @repeatPlayback.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeatPlayback;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylist;

  /// No description provided for @queueButton.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queueButton;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @queueTitle.
  ///
  /// In en, this message translates to:
  /// **'Play queue'**
  String get queueTitle;

  /// No description provided for @queueCount.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String queueCount(int count);

  /// No description provided for @closeQueue.
  ///
  /// In en, this message translates to:
  /// **'Close queue'**
  String get closeQueue;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queueEmpty;

  /// No description provided for @queueEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose songs from your library to start playing'**
  String get queueEmptySubtitle;

  /// No description provided for @addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get addToQueue;

  /// No description provided for @hideLyrics.
  ///
  /// In en, this message translates to:
  /// **'Hide lyrics'**
  String get hideLyrics;

  /// No description provided for @showLyrics.
  ///
  /// In en, this message translates to:
  /// **'Show lyrics'**
  String get showLyrics;

  /// No description provided for @randomPlay.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get randomPlay;

  /// No description provided for @sortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortLabel;

  /// No description provided for @currentSource.
  ///
  /// In en, this message translates to:
  /// **'Current source: '**
  String get currentSource;

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get notConfigured;

  /// No description provided for @exitSelection.
  ///
  /// In en, this message translates to:
  /// **'Exit selection'**
  String get exitSelection;

  /// No description provided for @playNow.
  ///
  /// In en, this message translates to:
  /// **'Play now'**
  String get playNow;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get playNext;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @closeSort.
  ///
  /// In en, this message translates to:
  /// **'Close sorting'**
  String get closeSort;

  /// No description provided for @noSongs.
  ///
  /// In en, this message translates to:
  /// **'No songs'**
  String get noSongs;

  /// No description provided for @configureSubsonicFirst.
  ///
  /// In en, this message translates to:
  /// **'Configure a Subsonic source first'**
  String get configureSubsonicFirst;

  /// No description provided for @loadRemoteSongsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load remote songs'**
  String get loadRemoteSongsFailed;

  /// No description provided for @noRemoteSongsScan.
  ///
  /// In en, this message translates to:
  /// **'No remote songs yet. Scan your library in Content settings first.'**
  String get noRemoteSongsScan;

  /// No description provided for @sourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This source is not available yet'**
  String get sourceUnavailable;

  /// No description provided for @noPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get noPlaylists;

  /// No description provided for @loadPlaylistsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load playlists'**
  String get loadPlaylistsFailed;

  /// No description provided for @noArtists.
  ///
  /// In en, this message translates to:
  /// **'No artists yet'**
  String get noArtists;

  /// No description provided for @loadArtistsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load artists'**
  String get loadArtistsFailed;

  /// No description provided for @noAlbums.
  ///
  /// In en, this message translates to:
  /// **'No albums yet'**
  String get noAlbums;

  /// No description provided for @loadAlbumsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load albums'**
  String get loadAlbumsFailed;

  /// No description provided for @switchToList.
  ///
  /// In en, this message translates to:
  /// **'Switch to list layout'**
  String get switchToList;

  /// No description provided for @switchToGrid.
  ///
  /// In en, this message translates to:
  /// **'Switch to grid layout'**
  String get switchToGrid;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @releaseDate.
  ///
  /// In en, this message translates to:
  /// **'Released: {year}'**
  String releaseDate(String year);

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @albumSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} songs, {duration}'**
  String albumSummary(String count, String duration);

  /// No description provided for @loadTracksFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load songs'**
  String get loadTracksFailed;

  /// No description provided for @noTracks.
  ///
  /// In en, this message translates to:
  /// **'No songs yet'**
  String get noTracks;

  /// No description provided for @discNumber.
  ///
  /// In en, this message translates to:
  /// **'Disc {number}'**
  String discNumber(int number);

  /// No description provided for @durationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Duration unknown'**
  String get durationUnknown;

  /// No description provided for @totalAlbums.
  ///
  /// In en, this message translates to:
  /// **'{count} albums'**
  String totalAlbums(String count);

  /// No description provided for @topSongs.
  ///
  /// In en, this message translates to:
  /// **'Top songs'**
  String get topSongs;

  /// No description provided for @shufflePlay.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shufflePlay;

  /// No description provided for @publicData.
  ///
  /// In en, this message translates to:
  /// **'Public data'**
  String get publicData;

  /// No description provided for @noArtistBio.
  ///
  /// In en, this message translates to:
  /// **'No artist biography yet'**
  String get noArtistBio;

  /// No description provided for @artistAlbums.
  ///
  /// In en, this message translates to:
  /// **'Artist albums'**
  String get artistAlbums;

  /// No description provided for @yearUnknown.
  ///
  /// In en, this message translates to:
  /// **'Year unknown'**
  String get yearUnknown;

  /// No description provided for @approxMinutes.
  ///
  /// In en, this message translates to:
  /// **'About {minutes} min'**
  String approxMinutes(int minutes);

  /// No description provided for @lessThanMinute.
  ///
  /// In en, this message translates to:
  /// **'Less than 1 min'**
  String get lessThanMinute;

  /// No description provided for @serverUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the server URL'**
  String get serverUrlRequired;

  /// No description provided for @serverUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid server URL'**
  String get serverUrlInvalid;

  /// No description provided for @portInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid port'**
  String get portInvalid;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a username'**
  String get usernameRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get passwordRequired;

  /// No description provided for @connectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful: '**
  String get connectionSuccess;

  /// No description provided for @syncFetchingArtists.
  ///
  /// In en, this message translates to:
  /// **'Fetching artists…'**
  String get syncFetchingArtists;

  /// No description provided for @syncAlbumsProgress.
  ///
  /// In en, this message translates to:
  /// **'Fetched {count} albums'**
  String syncAlbumsProgress(int count);

  /// No description provided for @syncFetchingAlbums.
  ///
  /// In en, this message translates to:
  /// **'Fetching albums…'**
  String get syncFetchingAlbums;

  /// No description provided for @syncTracksProgress.
  ///
  /// In en, this message translates to:
  /// **'Fetching tracks {completed}/{total}'**
  String syncTracksProgress(int completed, int total);

  /// No description provided for @syncTracksCount.
  ///
  /// In en, this message translates to:
  /// **'Fetching tracks: {count}'**
  String syncTracksCount(int count);

  /// No description provided for @syncScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get syncScanning;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String syncFailed(String error);

  /// No description provided for @syncRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again later'**
  String get syncRetry;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Scan complete: {count} songs'**
  String syncComplete(int count);

  /// No description provided for @serverUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrlLabel;

  /// No description provided for @serverUrlSupporting.
  ///
  /// In en, this message translates to:
  /// **'Configured URL'**
  String get serverUrlSupporting;

  /// No description provided for @portLabel.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get portLabel;

  /// No description provided for @portSupporting.
  ///
  /// In en, this message translates to:
  /// **'Port number'**
  String get portSupporting;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @testingButton.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get testingButton;

  /// No description provided for @testButton.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get testButton;

  /// No description provided for @scanningButton.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanningButton;

  /// No description provided for @scanButton.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanButton;

  /// No description provided for @scanningSemantics.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get scanningSemantics;

  /// No description provided for @lyricsNotPlayingTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get lyricsNotPlayingTitle;

  /// No description provided for @lyricsNotPlayingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a song from your library to view lyrics'**
  String get lyricsNotPlayingSubtitle;

  /// No description provided for @lyricsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading lyrics'**
  String get lyricsLoading;

  /// No description provided for @lyricsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load lyrics'**
  String get lyricsLoadFailed;

  /// No description provided for @lyricsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No lyrics'**
  String get lyricsEmptyTitle;

  /// No description provided for @lyricsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'No lyrics are available for this track'**
  String get lyricsEmptySubtitle;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Laetibeat playback controls'**
  String get notificationChannelDescription;

  /// No description provided for @searchSource.
  ///
  /// In en, this message translates to:
  /// **'Search source'**
  String get searchSource;

  /// No description provided for @searchSourceLocal.
  ///
  /// In en, this message translates to:
  /// **'Local music'**
  String get searchSourceLocal;

  /// No description provided for @searchSourceSubsonic.
  ///
  /// In en, this message translates to:
  /// **'Subsonic'**
  String get searchSourceSubsonic;

  /// No description provided for @searchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Search songs, artists, and albums'**
  String get searchPrompt;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// No description provided for @searchConfigureSubsonic.
  ///
  /// In en, this message translates to:
  /// **'Configure a Subsonic source first'**
  String get searchConfigureSubsonic;

  /// No description provided for @searchLocalLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading local library…'**
  String get searchLocalLoading;

  /// No description provided for @searchRemoteLoading.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get searchRemoteLoading;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchFailed;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// No description provided for @shuffleRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Shuffle recommendations'**
  String get shuffleRecommendations;

  /// No description provided for @refreshRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Refresh recommendations'**
  String get refreshRecommendations;

  /// No description provided for @recommendedQueueSource.
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get recommendedQueueSource;

  /// No description provided for @homeRecommendationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s recommendation for you'**
  String get homeRecommendationSubtitle;

  /// No description provided for @homeGreetingQuestion.
  ///
  /// In en, this message translates to:
  /// **'What would you like to listen to?'**
  String get homeGreetingQuestion;

  /// No description provided for @homeGreetingWithName.
  ///
  /// In en, this message translates to:
  /// **'{greeting}, {name}'**
  String homeGreetingWithName(String greeting, String name);

  /// No description provided for @searchRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecentTitle;

  /// No description provided for @searchRecentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recent searches'**
  String get searchRecentEmpty;

  /// No description provided for @searchRecentClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchRecentClear;

  /// No description provided for @searchRemoteNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Remote library is not synced yet'**
  String get searchRemoteNotSynced;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

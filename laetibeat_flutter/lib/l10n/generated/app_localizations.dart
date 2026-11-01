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

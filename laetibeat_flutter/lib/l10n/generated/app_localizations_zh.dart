// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Laetibeat';

  @override
  String get homeTitle => '首页';

  @override
  String get libraryTitle => '媒体库';

  @override
  String get searchTitle => '搜索';

  @override
  String get navHome => '首页';

  @override
  String get navLibrary => '媒体库';

  @override
  String get navSearch => '搜索';

  @override
  String get searchHint => '搜索歌曲、艺人、专辑';

  @override
  String get switchSearchSource => '切换搜索源';

  @override
  String get actionMusicSources => '音乐源配置';

  @override
  String get actionStatistics => '统计';

  @override
  String get actionSettings => '设置';

  @override
  String get librarySongs => '歌曲';

  @override
  String get libraryPlaylists => '歌单';

  @override
  String get libraryArtists => '艺术家';

  @override
  String get libraryAlbums => '专辑';

  @override
  String get libraryPodcasts => '播客';

  @override
  String get appearanceTitle => '外观';

  @override
  String get displayGroup => '显示';

  @override
  String get songSource => '歌曲来源';

  @override
  String get songSourceSupporting => '选择在歌曲列表默认显示的歌曲来源';

  @override
  String get songSort => '歌曲排序';

  @override
  String get songSortSupporting => '选择默认的歌曲排序方式';

  @override
  String get language => '语言';

  @override
  String get languageSupporting => '选择应用显示语言';

  @override
  String get languageDialogTitle => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsSearchHint => '搜索设置';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsAppearanceSupporting => '主题与明暗切换';

  @override
  String get settingsPlaybackAudio => '播放器与音频';

  @override
  String get settingsPlaybackAudioSupporting => '淡入淡出与电池优化';

  @override
  String get settingsContent => '内容';

  @override
  String get settingsContentSupporting => '音乐库、歌词与语言';

  @override
  String get settingsStorage => '储存';

  @override
  String get settingsStorageSupporting => '缓存管理';

  @override
  String get settingsBackupRestore => '备份与还原';

  @override
  String get settingsBackupRestoreSupporting => '备份设置或从另一份配置中导入设置';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsAboutSupporting => '当前版本';

  @override
  String get lyricsGroup => '歌词';

  @override
  String get lyricsSource => '歌词来源';

  @override
  String get lyricsSourceSupporting => '选择要启用的歌词来源';

  @override
  String get lyricsPriority => '歌词来源优先级';

  @override
  String get lyricsPrioritySupporting => '按照偏好重新排序歌词源优先级';

  @override
  String get lyricsReset => '重置已导入的歌词';

  @override
  String get lyricsResetSupporting => '从数据库中移除所有已经导入的歌词';

  @override
  String get syncScanGroup => '同步与扫描';

  @override
  String get chooseLocalLibrary => '选择本地媒体库';

  @override
  String get chooseLocalLibrarySupporting => '选择您的音乐文件夹所在的目录';

  @override
  String get chooseLibrary => '选择媒体库';

  @override
  String get syncDatabase => '同步数据库';

  @override
  String get musicSourcesTitle => '音乐源配置';

  @override
  String get openSubsonicDescription =>
      '连接到您的支持opensubsonic协议的服务器，例如navidrome。';

  @override
  String get notAvailable => '暂未提供';

  @override
  String get sourceJellyfin => 'Jellyfin';

  @override
  String get sourceEmbyMusic => 'Emby音乐';

  @override
  String get sourceLxMusic => '洛雪音源';

  @override
  String get sourceQqMusic => 'QQ音乐';

  @override
  String get sourceNetEaseMusic => '网易云音乐';

  @override
  String get statisticsTitle => '统计';

  @override
  String get commonBack => '返回';

  @override
  String get previousTrack => '上一曲';

  @override
  String get pause => '暂停';

  @override
  String get play => '播放';

  @override
  String get nextTrack => '下一曲';

  @override
  String get musicLibraryEmpty => '音乐库为空';

  @override
  String get goToSettingsScan => '前往设置选择音乐文件夹，开始扫描';

  @override
  String get nothingPlaying => '未在播放';

  @override
  String get chooseSongToPlay => '从音乐库选择一首歌曲开始播放';

  @override
  String get nowPlaying => '正在播放';

  @override
  String get fullScreen => '全屏';

  @override
  String get exitFullScreen => '退出全屏';

  @override
  String get lyrics => '歌词';

  @override
  String get shufflePlayback => '随机播放';

  @override
  String get repeatPlayback => '重复';

  @override
  String get addToPlaylist => '添加到歌单';

  @override
  String get queueButton => '队列';

  @override
  String get more => '更多';

  @override
  String get queueTitle => '播放队列';

  @override
  String queueCount(int count) {
    return '$count 首';
  }

  @override
  String get closeQueue => '关闭队列';

  @override
  String get queueEmpty => '队列为空';

  @override
  String get queueEmptySubtitle => '从音乐库选择歌曲开始播放';

  @override
  String get addToQueue => '添加到播放队列';

  @override
  String get hideLyrics => '收起歌词';

  @override
  String get showLyrics => '查看歌词';

  @override
  String get randomPlay => '随机播放';

  @override
  String get sortLabel => '排序';

  @override
  String get currentSource => '当前音源：';

  @override
  String get notConfigured => '未配置';

  @override
  String get exitSelection => '退出选择';

  @override
  String get playNow => '立即播放';

  @override
  String get playNext => '下一首播放';

  @override
  String get addToFavorites => '添加到喜欢';

  @override
  String get sortBy => '排序方式';

  @override
  String get closeSort => '关闭排序方式';

  @override
  String get noSongs => '暂无歌曲';

  @override
  String get configureSubsonicFirst => '请先配置 Subsonic 音源';

  @override
  String get loadRemoteSongsFailed => '读取远端歌曲失败';

  @override
  String get noRemoteSongsScan => '还没有远端歌曲，请先在内容设置中扫描';

  @override
  String get sourceUnavailable => '该音源暂未提供';

  @override
  String get noPlaylists => '还没有歌单';

  @override
  String get loadPlaylistsFailed => '读取歌单失败';

  @override
  String get noArtists => '还没有艺术家';

  @override
  String get loadArtistsFailed => '读取艺术家失败';

  @override
  String get noAlbums => '还没有专辑';

  @override
  String get loadAlbumsFailed => '读取专辑失败';

  @override
  String get switchToList => '切换为列表布局';

  @override
  String get switchToGrid => '切换为宫格布局';

  @override
  String get like => '喜欢';

  @override
  String releaseDate(String year) {
    return '发行日期: $year';
  }

  @override
  String get unknown => '未知';

  @override
  String albumSummary(String count, String duration) {
    return '$count首歌曲，$duration';
  }

  @override
  String get loadTracksFailed => '读取歌曲失败';

  @override
  String get noTracks => '暂无歌曲';

  @override
  String discNumber(int number) {
    return '碟片 $number';
  }

  @override
  String get durationUnknown => '时长未知';

  @override
  String totalAlbums(String count) {
    return '共 $count 张专辑';
  }

  @override
  String get topSongs => '热门歌曲';

  @override
  String get shufflePlay => '随机播放';

  @override
  String get publicData => '公开数据';

  @override
  String get noArtistBio => '暂无歌手详情';

  @override
  String get artistAlbums => '歌手专辑';

  @override
  String get yearUnknown => '年份未知';

  @override
  String approxMinutes(int minutes) {
    return '大约 $minutes 分钟';
  }

  @override
  String get lessThanMinute => '不到 1 分钟';

  @override
  String get serverUrlRequired => '请输入服务器 URL';

  @override
  String get serverUrlInvalid => '请输入有效的服务器 URL';

  @override
  String get portInvalid => '请输入有效的端口号';

  @override
  String get usernameRequired => '请输入用户名';

  @override
  String get passwordRequired => '请输入密码';

  @override
  String get connectionSuccess => '连接成功：';

  @override
  String get syncFetchingArtists => '正在获取艺术家…';

  @override
  String syncAlbumsProgress(int count) {
    return '已获取 $count 张专辑';
  }

  @override
  String get syncFetchingAlbums => '正在获取专辑…';

  @override
  String syncTracksProgress(int completed, int total) {
    return '正在获取曲目 $completed/$total';
  }

  @override
  String syncTracksCount(int count) {
    return '正在获取曲目 $count 首';
  }

  @override
  String get syncScanning => '正在扫描…';

  @override
  String syncFailed(String error) {
    return '扫描失败：$error';
  }

  @override
  String get syncRetry => '请稍后重试';

  @override
  String syncComplete(int count) {
    return '扫描完成，共 $count 首歌曲';
  }

  @override
  String get serverUrlLabel => '服务器 URL';

  @override
  String get serverUrlSupporting => '配置URL';

  @override
  String get portLabel => '端口';

  @override
  String get portSupporting => '端口号';

  @override
  String get usernameLabel => '用户名';

  @override
  String get passwordLabel => '密码';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get testingButton => '测试中…';

  @override
  String get testButton => '测试';

  @override
  String get scanningButton => '扫描中…';

  @override
  String get scanButton => '扫描';

  @override
  String get scanningSemantics => '正在扫描';

  @override
  String get lyricsNotPlayingTitle => '未在播放';

  @override
  String get lyricsNotPlayingSubtitle => '从音乐库选择一首歌曲后查看歌词';

  @override
  String get lyricsLoading => '歌词加载中';

  @override
  String get lyricsLoadFailed => '歌词加载失败';

  @override
  String get lyricsEmptyTitle => '暂无歌词';

  @override
  String get lyricsEmptySubtitle => '当前曲目没有可显示的歌词';

  @override
  String get notificationChannelName => '播放';

  @override
  String get notificationChannelDescription => 'Laetibeat 播放控制';
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistence.dart';

/// 歌曲来源名称。当前只有本地音乐和 Subsonic 有实际数据源。
abstract final class SongSources {
  static const String local = '本地音乐';
  static const String subsonic = 'Subsonic';
  static const String jellyfin = 'Jellyfin';
  static const String emby = 'Emby音乐';
  static const String lx = '洛雪音源';

  static const List<String> all = <String>[
    local,
    subsonic,
    jellyfin,
    emby,
    lx,
  ];
}

const String kDefaultSongSourceKey = 'mobile.defaultSongSource';

/// 歌曲列表默认来源。未设置时回退到本地音乐。
class DefaultSongSourceNotifier extends Notifier<String> {
  @override
  String build() {
    final saved = ref
        .read(sharedPreferencesProvider)
        .getString(kDefaultSongSourceKey);
    return SongSources.all.contains(saved) ? saved! : SongSources.local;
  }

  void setSource(String source) {
    if (!SongSources.all.contains(source) || source == state) return;
    state = source;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(kDefaultSongSourceKey, source),
    );
  }
}

final defaultSongSourceProvider =
    NotifierProvider<DefaultSongSourceNotifier, String>(
      DefaultSongSourceNotifier.new,
    );

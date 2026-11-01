import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/library.dart' as rust_library;
import 'package:laetibeat/src/rust/api/lyrics.dart' as rust_lyrics;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;

import '../settings/lyrics_settings.dart';
import 'player_provider.dart';

// ---------------------------------------------------------------------------
// 歌词来源抽象 + 实现
// ---------------------------------------------------------------------------
// 上层(歌词页)只依赖 LyricsRepository:
//   * 本地曲目: 内嵌标签(USLT/SYLT/©lyr/LYRICS) -> 同目录 .lrc/.txt -> 网络
//   * OpenSubsonic 曲目: 服务器歌词 -> 网络
//   * 其它远端音源: 由各自的“标签/服务器”Provider 返回自己的歌词 -> 网络
// 网络源当前为 LRCLIB; 解析全部交给 flutter_lyric, 本层只负责原始文本。

/// 一份歌词的原始文本。
class Lyrics {
  /// 原始歌词内容(可能带时间戳,也可能是纯文本)
  final String rawText;

  /// 可选的翻译文本。可以是逐行 LRC，也可以是纯文本。
  final String? translation;

  const Lyrics(this.rawText, {this.translation});
}

/// 歌词来源抽象:按曲目返回歌词;无歌词返回 null。
abstract class LyricProvider {
  /// 获取曲目歌词;缓存由实现方负责(Rust SQLite 或内存)。
  Future<Lyrics?> lyrics(rust.UiTrack track);
}

/// 本地歌词来源:内嵌标签 -> 同目录同名 .lrc/.txt。
/// 使用 library.db 中的指纹缓存;音频或外挂歌词变化后自动失效。
class FileLyricProvider implements LyricProvider {
  FileLyricProvider();

  @override
  Future<Lyrics?> lyrics(rust.UiTrack track) async {
    if (track.path.isEmpty) return null;
    final text = await rust_library.resolveLocalLyricsCached(path: track.path);
    return _toLyrics(text);
  }
}

/// 远端歌词来源:OpenSubsonic 返回结果 + SQLite 缓存/负缓存。
class RemoteLyricProvider implements LyricProvider {
  RemoteLyricProvider();

  @override
  Future<Lyrics?> lyrics(rust.UiTrack track) async {
    final text = await rust_subsonic.subsonicGetLyricsCached(
      sourceId: track.sourceId,
      trackId: track.id,
      artist: track.artist,
      title: track.title,
    );
    return _toLyrics(text);
  }
}

/// LiriQo 网络歌词来源。请求、正/负缓存都由 Rust 层负责。
class LiriqoLyricProvider implements LyricProvider {
  LiriqoLyricProvider();

  @override
  Future<Lyrics?> lyrics(rust.UiTrack track) async {
    if (track.title.trim().isEmpty || track.artist.trim().isEmpty) {
      return null;
    }
    final text = await rust_lyrics.liriqoGetLyrics(
      title: track.title,
      artist: track.artist,
      durationSeconds: track.durationSeconds.toInt(),
    );
    return _toLyrics(text);
  }
}

/// LRCLIB 网络歌词来源。请求、正/负缓存都由 Rust 层负责。
class LrclibLyricProvider implements LyricProvider {
  LrclibLyricProvider();

  @override
  Future<Lyrics?> lyrics(rust.UiTrack track) async {
    if (track.title.trim().isEmpty || track.artist.trim().isEmpty) {
      return null;
    }
    final text = await rust_lyrics.lrclibGetLyrics(
      title: track.title,
      artist: track.artist,
      album: track.album,
      durationSeconds: track.durationSeconds.toInt(),
    );
    return _toLyrics(text);
  }
}

Lyrics? _toLyrics(String? text, {String? translation}) {
  if (text == null) return null;
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final translated = translation?.trim();
  return Lyrics(
    trimmed,
    translation: translated == null || translated.isEmpty ? null : translated,
  );
}

/// 按当前设置，把“标签/服务器歌词”和 LRCLIB 串成一条回退链。
class LyricsRepository {
  LyricsRepository({
    required this.fileProvider,
    required this.remoteProvider,
    required this.lrclibProvider,
    required this.liriqoProvider,
    required this.settings,
  });

  final FileLyricProvider fileProvider;
  final RemoteLyricProvider remoteProvider;
  final LrclibLyricProvider lrclibProvider;
  final LiriqoLyricProvider liriqoProvider;
  final LyricsSettings settings;

  Future<Lyrics?> lyrics(rust.UiTrack track) async {
    for (final source in settings.order) {
      if (!settings.isEnabled(source)) continue;
      final lyrics = await switch (source) {
        LyricsSourceId.tags => _loadOwnLyrics(track),
        LyricsSourceId.lrclib => lrclibProvider.lyrics(track),
        LyricsSourceId.liriqo => liriqoProvider.lyrics(track),
      };
      if (lyrics != null) return lyrics;
    }
    return null;
  }

  /// “歌词标签”包含本地内嵌/外挂歌词，以及服务器默认返回的歌词。
  Future<Lyrics?> _loadOwnLyrics(rust.UiTrack track) async {
    if (track.source == 'opensubsonic' && track.sourceId.isNotEmpty) {
      return remoteProvider.lyrics(track);
    }
    if (track.path.isNotEmpty) {
      return fileProvider.lyrics(track);
    }
    // 未来 Jellyfin / Emby 等音源在这里接入各自的服务器歌词 Provider。
    return null;
  }
}

/// 用户在“搜索歌词”中手动选择的歌词覆盖。
class LyricsOverrideNotifier extends Notifier<Map<String, Lyrics>> {
  @override
  Map<String, Lyrics> build() => const <String, Lyrics>{};

  void apply(rust.UiTrack track, String rawText, {String? translation}) {
    final text = rawText.trim();
    if (text.isEmpty) return;
    final translated = translation?.trim();
    state = <String, Lyrics>{
      ...state,
      trackLyricsKey(track): Lyrics(
        text,
        translation: translated == null || translated.isEmpty
            ? null
            : translated,
      ),
    };
  }

  void clear(rust.UiTrack track) {
    if (!state.containsKey(trackLyricsKey(track))) return;
    final next = Map<String, Lyrics>.of(state)..remove(trackLyricsKey(track));
    state = next;
  }
}

final lyricsOverridesProvider =
    NotifierProvider<LyricsOverrideNotifier, Map<String, Lyrics>>(
      LyricsOverrideNotifier.new,
    );

String trackLyricsKey(rust.UiTrack track) {
  return '${track.source}|${track.sourceId}|${track.id}';
}

// ---------------------------------------------------------------------------
// Riverpod 接线
// ---------------------------------------------------------------------------

final fileLyricProvider = Provider<FileLyricProvider>((ref) {
  return FileLyricProvider();
});

final remoteLyricProvider = Provider<RemoteLyricProvider>((ref) {
  return RemoteLyricProvider();
});

final lrclibLyricProvider = Provider<LrclibLyricProvider>((ref) {
  return LrclibLyricProvider();
});

final liriqoLyricProvider = Provider<LiriqoLyricProvider>((ref) {
  return LiriqoLyricProvider();
});

final lyricsRepositoryProvider = Provider<LyricsRepository>((ref) {
  return LyricsRepository(
    fileProvider: ref.watch(fileLyricProvider),
    remoteProvider: ref.watch(remoteLyricProvider),
    lrclibProvider: ref.watch(lrclibLyricProvider),
    liriqoProvider: ref.watch(liriqoLyricProvider),
    settings: ref.watch(lyricsSettingsProvider),
  );
});

/// 当前播放曲目的歌词。随当前曲目或歌词设置变化而刷新;无歌词返回 null。
/// 只订阅 current(而非整个 state),避免播放进度 position 每 tick 更新
/// state 时触发本 FutureProvider 反复重跑而闪 loading。
final lyricsProvider = FutureProvider<Lyrics?>((ref) async {
  final track = ref.watch(playerProvider.select((s) => s.current));
  if (track == null) return null;

  final override = ref.watch(
    lyricsOverridesProvider.select(
      (overrides) => overrides[trackLyricsKey(track)],
    ),
  );
  if (override != null) return override;

  return ref.watch(lyricsRepositoryProvider).lyrics(track);
});

/// 按曲目取歌词(供列表等并行展示)。
final trackLyricsProvider = FutureProvider.family<Lyrics?, rust.UiTrack>((
  ref,
  track,
) async {
  final override = ref.watch(
    lyricsOverridesProvider.select(
      (overrides) => overrides[trackLyricsKey(track)],
    ),
  );
  if (override != null) return override;

  return ref.watch(lyricsRepositoryProvider).lyrics(track);
});

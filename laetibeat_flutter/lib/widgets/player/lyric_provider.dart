import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

import 'player_provider.dart';

// ---------------------------------------------------------------------------
// 歌词来源抽象 + 本地实现
// ---------------------------------------------------------------------------
// 上层(歌词页)只依赖 LyricProvider 这个拼口:
//   * 来源优先级: 内嵌标签(USLT/SYLT/©lyr/LYRICS) -> 同目录 .lrc/.txt -> 网络
//   * 网络源(Navidrome / opensubsonic) -> 以后实现同接口,按 getLyrics URL 拉取
// 与 CoverProvider 同构:新增音源只需新增一个实现,不动上层。
//
// 本层只负责"取到原始歌词文本";LRC/QRC/YRC 的解析全部交给 flutter_lyric,
// 解析结果为空时上层按纯文本展示。

/// 一份歌词的原始文本。
class Lyrics {
  /// 原始歌词内容(可能带时间戳,也可能是纯文本)
  final String rawText;

  const Lyrics(this.rawText);
}

/// 歌词来源抽象:按曲目返回歌词;无歌词返回 null。
abstract class LyricProvider {
  /// 获取曲目歌词;实现方应按 track.id 缓存,避免重复读盘/拉取。
  Future<Lyrics?> lyrics(rust.UiTrack track);
}

/// 本地歌词来源:先读音频内嵌标签,再回退读同目录同名 .lrc/.txt,按曲目 id 缓存。
/// 网络源接入时新增一个实现即可,接口不变。
class FileLyricProvider implements LyricProvider {
  FileLyricProvider();

  /// 接口级缓存:按曲目 id 缓存原始文本,切回/重复展示不再重读文件
  final Map<String, Lyrics> _cache = {};

  @override
  Future<Lyrics?> lyrics(rust.UiTrack track) async {
    final cached = _cache[track.id];
    if (cached != null) return cached;
    if (track.path.isEmpty) return null; // 未来网络源:url 分支

    final parsed = await _readLyrics(track.path);
    if (parsed != null) {
      _cache[track.id] = parsed;
    }
    return parsed;
  }
}

/// 按优先级取歌词:内嵌标签 -> sidecar .lrc/.txt。
/// 放到独立 isolate 里跑,避免解析大文件时阻塞 UI 线程。
Future<Lyrics?> _readLyrics(String audioPath) {
  return Isolate.run(() {
    try {
      final audio = File(audioPath);
      if (!audio.existsSync()) return null;

      // 1. 内嵌歌词优先(与封面共用 audio_metadata_reader,零新增依赖)
      final embedded = _readEmbeddedLyrics(audio);
      if (embedded != null) return Lyrics(embedded);

      // 2. sidecar .lrc / .txt 回退
      final sidecar = _readSidecarLyrics(audio);
      if (sidecar != null) return Lyrics(sidecar);
      return null;
    } catch (_) {
      return null; // 读盘/解析失败按无歌词处理
    }
  });
}

/// 读音频内嵌歌词标签(ID3 USLT / MP4 ©lyr / APE / FLAC LYRICS)。
/// 内容可能是纯文本,也可能是一段 LRC 文本,统一交给上层判定。
String? _readEmbeddedLyrics(File audio) {
  try {
    final meta = readMetadata(audio, getImage: false);
    final text = meta.lyrics?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  } catch (_) {
    return null; // 无内嵌或解析失败,继续尝试 sidecar
  }
}

/// 读音频同目录的同名 .lrc / .txt sidecar 歌词。
String? _readSidecarLyrics(File audio) {
  final base = audio.path.substring(0, audio.path.length - _extLen(audio.path));
  for (final ext in const ['.lrc', '.txt']) {
    final f = File('$base$ext');
    if (!f.existsSync()) continue;
    final content = f.readAsStringSync().trim();
    if (content.isEmpty) continue;
    return content;
  }
  return null;
}

/// 取路径扩展名长度(含点),用于替换成 .lrc/.txt
int _extLen(String path) {
  final i = path.lastIndexOf('.');
  if (i < 0) return 0;
  return path.length - i;
}

// ---------------------------------------------------------------------------
// Riverpod 接线
// ---------------------------------------------------------------------------

/// 全局歌词来源(本地文件实现)。
final lyricProvider = Provider<LyricProvider>((ref) {
  return FileLyricProvider();
});

/// 当前播放曲目的歌词。随当前曲目切换而刷新;无歌词返回 null。
/// 只订阅 current(而非整个 state),避免播放进度 position 每 tick 更新
/// state 时触发本 FutureProvider 反复重跑而闪 loading。
final lyricsProvider = FutureProvider<Lyrics?>((ref) async {
  final track = ref.watch(playerProvider.select((s) => s.current));
  if (track == null) return null;
  return ref.read(lyricProvider).lyrics(track);
});

/// 按曲目取歌词(供列表等并行展示)。以 track 对象作 family key,
/// FileLyricProvider 内部再按 id 缓存。
final trackLyricsProvider =
    FutureProvider.family<Lyrics?, rust.UiTrack>((ref, track) async {
  if (track.path.isEmpty) return null;
  return ref.read(lyricProvider).lyrics(track);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/metadata.dart' as rust_meta;
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

/// 本地歌词来源:内嵌标签 -> 同目录同名 .lrc/.txt,按曲目 id 缓存。
/// 解析在 Rust 侧完成(与扫描共用 lofty),网络源接入时新增实现即可。
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

/// 读取歌词:内嵌标签 -> sidecar .lrc/.txt。
/// 解析在 Rust 侧完成,FRB 调用在后台线程执行,不阻塞 UI。
Future<Lyrics?> _readLyrics(String audioPath) async {
  final text = await rust_meta.readLyrics(path: audioPath);
  if (text == null) return null;
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : Lyrics(trimmed);
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

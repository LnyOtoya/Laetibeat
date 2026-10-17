import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/metadata.dart' as rust_meta;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

import 'player_provider.dart';

/// 主色取色所需的 Color 类型(dart:ui 命名空间)
typedef Color = ui.Color;

// ---------------------------------------------------------------------------
// 封面来源抽象 + 本地实现 + 封面主色取色
// ---------------------------------------------------------------------------
// 上层(播放面板/音乐库列表)只依赖 CoverProvider 这个拼口:
//   * 本地 -> 从音频文件元数据读内嵌封面(MP3 ID3 / FLAC / M4A),按曲目缓存
//   * 网络源(Navidrome) -> 以后实现同接口,按 getCoverArt URL 拉取即可
// 注意:media_kit 的 player.screenshot() 截的是视频输出帧,纯音频文件取不到内嵌
// 封面,且只能取"正在播放"的那首——故封面一律改从文件路径直接读。

/// 某曲目的封面字节(JPEG/PNG)。无封面返回 null。
abstract class CoverProvider {
  /// 获取曲目封面原始字节;实现方应按 track.id 缓存,避免重复读取。
  Future<Uint8List?> cover(rust.UiTrack track);
}

/// 衍生信息:封面字节 + 封面主色(用于派生播放页 ColorScheme)。
class PlaybackCover {
  /// 原始封面字节,用于 Image.memory 缩放显示
  final Uint8List bytes;

  /// 封面主色(采样量化出的主导色),作为本页取色的 seed
  final Color coverColor;

  const PlaybackCover(this.bytes, this.coverColor);
}

/// 本地封面来源:从 track.path 的音频文件读内嵌封面,按曲目 id 做 LRU 缓存。
/// 封面解析在 Rust 侧完成(与扫描共用 lofty),网络源接入时新增实现即可。
class FileCoverProvider implements CoverProvider {
  FileCoverProvider();

  /// 封面缓存上限(字节)。原图通常几百 KB,限制总量避免整库浏览后内存膨胀。
  static const int _maxCacheBytes = 64 * 1024 * 1024;

  /// Dart Map 保持插入顺序:命中时删掉再插回末尾即为"最近使用",
  /// 超限时从头部淘汰最久未使用的条目。
  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  int _cachedBytes = 0;

  @override
  Future<Uint8List?> cover(rust.UiTrack track) async {
    final cached = _cache.remove(track.id);
    if (cached != null) {
      _cache[track.id] = cached; // 刷新为最近使用
      return cached;
    }
    if (track.path.isEmpty) return null; // 未来网络源:url 分支

    final bytes = await _readEmbeddedArt(track.path);
    if (bytes == null || bytes.isEmpty) return null;

    _cache[track.id] = bytes;
    _cachedBytes += bytes.length;
    while (_cachedBytes > _maxCacheBytes && _cache.isNotEmpty) {
      final oldestKey = _cache.keys.first;
      final removed = _cache.remove(oldestKey);
      _cachedBytes -= removed?.length ?? 0;
    }
    return bytes;
  }
}

/// 从本地文件读内嵌封面字节。
/// 解析在 Rust 侧完成,FRB 调用在后台线程执行,不阻塞 UI。
Future<Uint8List?> _readEmbeddedArt(String path) =>
    rust_meta.readCover(path: path);

// ---------------------------------------------------------------------------
// Riverpod 接线
// ---------------------------------------------------------------------------

/// 全局封面来源(本地文件实现)。
final coverProvider = Provider<CoverProvider>((ref) {
  return FileCoverProvider();
});

/// 当前播放曲目的封面信息(字节 + 主色)。随当前曲目切换而刷新。
/// 只订阅 current,避免 position 每 tick 更新 state 时反复重跑。
/// 无封面 / 取色失败时返回 null,UI 回退占位图标并保留应用默认配色。
final playbackCoverProvider = FutureProvider<PlaybackCover?>((ref) async {
  final track = ref.watch(playerProvider.select((s) => s.current));
  if (track == null) return null;

  final cover = ref.read(coverProvider);
  final bytes = await cover.cover(track);
  if (bytes == null || bytes.isEmpty) return null;

  return PlaybackCover(bytes, await _dominantColor(bytes));
});

/// 按曲目取封面字节(供音乐库列表等并行展示)。以 track 对象作 family key,
/// 缓存按 UiTrack 值相等(id/path 等)命中;FileCoverProvider 内部再按 id 缓存。
final trackCoverProvider =
    FutureProvider.family<Uint8List?, rust.UiTrack>((ref, track) async {
  if (track.path.isEmpty) return null;
  return ref.read(coverProvider).cover(track);
});

// ---------------------------------------------------------------------------
// 主色取色:把封面缩放后按低饱和桶量化,取采样最多的桶的平均色当 seed。
// ColorScheme.fromSeed 会把该色映射到协调的 M3 色板,安全用于覆盖播放页配色。
// ---------------------------------------------------------------------------

/// 从封面字节提取一个代表性主色(采样数最多的量化桶的平均色)。
Future<Color> _dominantColor(Uint8List bytes) async {
  const int grid = 24;
  // 只解码到 64px 宽:取色只需要缩略采样,避免在 UI 线程解码整张大图
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: 64,
    allowUpscaling: false,
  );
  final frame = await codec.getNextFrame();
  final ui.Image img = frame.image;
  final w = img.width;
  final h = img.height;
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  codec.dispose();
  if (data == null || w <= 0 || h <= 0) {
    return const Color(0xFF6750A4);
  }
  final px = data.buffer.asUint8List();

  final Map<int, _Bucket> buckets = {};
  for (var gy = 0; gy < grid; gy++) {
    for (var gx = 0; gx < grid; gx++) {
      final x = math.max(0, math.min(w - 1, gx * w ~/ grid));
      final y = math.max(0, math.min(h - 1, gy * h ~/ grid));
      final i = (y * w + x) * 4;
      final r = px[i];
      final g = px[i + 1];
      final b = px[i + 2];
      // 每通道量化到 /8(32 级),近似合并相近色进同一桶
      final key = ((r ~/ 8) << 10) | ((g ~/ 8) << 5) | (b ~/ 8);
      final bucket = buckets.putIfAbsent(key, _Bucket.new);
      bucket.r += r;
      bucket.g += g;
      bucket.b += b;
      bucket.count++;
    }
  }

  _Bucket? best;
  for (final bucket in buckets.values) {
    if (best == null || bucket.count > best.count) best = bucket;
  }
  if (best == null) return const Color(0xFF6750A4);
  return Color.fromARGB(
    255,
    best.r ~/ best.count,
    best.g ~/ best.count,
    best.b ~/ best.count,
  );
}

/// 单色彩量化桶:累加 RGB 与采样次数,最终取平均色
class _Bucket {
  int r = 0;
  int g = 0;
  int b = 0;
  int count = 0;
}
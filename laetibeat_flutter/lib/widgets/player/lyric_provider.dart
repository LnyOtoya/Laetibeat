import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

import 'player_provider.dart';

// ---------------------------------------------------------------------------
// 歌词来源抽象 + 本地实现 + 解析
// ---------------------------------------------------------------------------
// 上层(歌词页)只依赖 LyricProvider 这个拼口:
//   * 来源优先级: 内嵌标签(USLT/SYLT/©lyr/LYRICS) -> 同目录 .lrc/.txt -> 网络
//   * 网络源(Navidrome / opensubsonic) -> 以后实现同接口,按 getLyrics URL 拉取
// 与 CoverProvider 同构:新增音源只需新增一个实现,不动上层。

/// 歌词同步粒度
enum LyricSync {
  /// 纯文本,无时间信息,整屏静态展示
  none,

  /// 行级同步(普通 LRC):整行高亮
  line,

  /// 逐字/逐词同步(Enhanced LRC / 网络逐字):词内高亮 + 进度
  word,
}

/// 逐字/逐词单元:一个词的起止时间与文本。
class LyricSegment {
  final Duration start;
  final Duration end;
  final String text;
  const LyricSegment({required this.start, required this.end, required this.text});
}

/// 一行歌词:time 为该行同步起点;segments 非空表示该行可逐字渲染。
class LyricLine {
  final Duration? time;
  final String text;

  /// 逐字同步段;为 null 时按整行渲染。
  final List<LyricSegment>? segments;
  const LyricLine({this.time, required this.text, this.segments});
}

/// 一份完整歌词
class Lyrics {
  /// 同步行(按时间升序)
  final List<LyricLine> lines;

  /// 无时间戳的纯文本(多行拼合),sync == none 时非空
  final String plainText;

  /// 同步粒度
  final LyricSync sync;

  const Lyrics({required this.lines, required this.plainText, required this.sync});

  /// 是否为可跟随播放进度高亮的同步歌词
  bool get isSynced => sync != LyricSync.none;
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

  /// 接口级缓存:按曲目 id 缓存解析结果,切回/重复展示不再重读文件
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
      if (embedded != null) return embedded;

      // 2. sidecar .lrc / .txt 回退
      return _readSidecarLyrics(audio);
    } catch (_) {
      return null; // 读盘/解析失败按无歌词处理
    }
  });
}

/// 读音频内嵌歌词标签(ID3 USLT / MP4 ©lyr / APE / FLAC LYRICS)。
/// 内容可能是纯文本,也可能是一段 LRC 文本,统一交给 _parseLyricText 判定。
Lyrics? _readEmbeddedLyrics(File audio) {
  try {
    final meta = readMetadata(audio, getImage: false);
    final text = meta.lyrics?.trim();
    if (text == null || text.isEmpty) return null;
    return _parseLyricText(text);
  } catch (_) {
    return null; // 无内嵌或解析失败,继续尝试 sidecar
  }
}

/// 读音频同目录的同名 .lrc / .txt sidecar 歌词。
Lyrics? _readSidecarLyrics(File audio) {
  final base = audio.path.substring(0, audio.path.length - _extLen(audio.path));
  for (final ext in const ['.lrc', '.txt']) {
    final f = File('$base$ext');
    if (!f.existsSync()) continue;
    final content = f.readAsStringSync();
    if (content.trim().isEmpty) continue;
    final parsed = _parseLyricText(content);
    if (parsed != null) return parsed;
  }
  return null;
}

/// 取路径扩展名长度(含点),用于替换成 .lrc/.txt
int _extLen(String path) {
  final i = path.lastIndexOf('.');
  if (i < 0) return 0;
  return path.length - i;
}

/// 统一歌词解析:自动判定同步粒度。
///  - 行首存在 [mm:ss] 且行内无 <mm:ss> 内嵌标签 -> line
///  - 行内存在 <mm:ss>(Enhanced LRC) -> word(逐字段解析见 TODO)
///  - 既无行级也无内嵌 -> none(纯文本)
/// 支持一行多个时间戳,忽略元数据标签(如 [ti:xxx]/[ar:xxx]/[offset:xxx])。
Lyrics? _parseLyricText(String content) {
  final lines = <LyricLine>[];
  final plain = <String>[];
  final tsRe = RegExp(r'^\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  final inlineRe = RegExp(r'<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>');
  var hasInline = false;

  for (final raw in content.split('\n')) {
    final line = raw.trimRight();
    if (line.isEmpty) continue;

    // 判断该行是否含逐字内嵌标签 <mm:ss>
    if (!hasInline && inlineRe.hasMatch(line)) hasInline = true;

    var rest = line;
    final times = <Duration>[];
    while (true) {
      final m = tsRe.firstMatch(rest);
      if (m == null) break;
      times.add(_parseStamp(m));
      rest = rest.substring(m.end);
    }

    if (times.isNotEmpty) {
      final text = rest.trim();
      if (text.isEmpty) continue;
      // TODO(逐字): 当 hasInline 为 true 时,把 text 按 <mm:ss> 内嵌标签
      // 切成 List<LyricSegment>{start,end,text} 填入 segments。
      // 当前缺逐字歌词实测源,先按下标保留 text 原样占位(segments 保持 null),
      // 渲染层回落为整行高亮;后续接入逐字源后再填充即可。
      for (final t in times) {
        lines.add(LyricLine(time: t, text: text, segments: null));
      }
    } else {
      // 无时间戳:元数据标签(整行 [xxx])忽略,其余当纯文本
      if (line.startsWith('[') && line.endsWith(']')) continue;
      plain.add(line);
    }
  }

  if (lines.isNotEmpty) {
    return Lyrics(
      lines: lines,
      plainText: '',
      sync: hasInline ? LyricSync.word : LyricSync.line,
    );
  }
  if (plain.isNotEmpty) {
    return Lyrics(lines: [], plainText: plain.join('\n'), sync: LyricSync.none);
  }
  return null;
}

/// 解析 [mm:ss.xx] 时间戳:百分秒(两位 xx)/千分秒(三位 xxx)统一换算为毫秒。
Duration _parseStamp(RegExpMatch m) {
  final min = int.parse(m.group(1)!);
  final sec = int.parse(m.group(2)!);
  final frac = m.group(3);
  var ms = 0;
  if (frac != null && frac.isNotEmpty) {
    if (frac.length >= 3) {
      ms = int.tryParse(frac.substring(0, 3)) ?? 0; // 千分秒
    } else {
      final s = frac.length == 1 ? '${frac}0' : frac.substring(0, 2);
      ms = (int.tryParse(s) ?? 0) * 10; // 百分秒
    }
  }
  return Duration(minutes: min, seconds: sec, milliseconds: ms);
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

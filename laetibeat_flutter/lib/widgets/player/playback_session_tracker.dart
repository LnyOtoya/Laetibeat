import 'dart:convert';
import 'dart:math' as math;

import 'package:laetibeat/src/rust/api/simple.dart' as rust;

/// 已通过记录阈值的播放会话
class PlaySessionEvent {
  const PlaySessionEvent({
    required this.source,
    required this.sourceId,
    required this.trackId,
    required this.startedAt,
    required this.listenedMs,
    required this.durationMs,
    required this.completed,
    required this.skipped,
    required this.queueSource,
    required this.metadataJson,
  });

  final String source;
  final String sourceId;
  final String trackId;

  /// Unix 毫秒
  final int startedAt;
  final int listenedMs;
  final int durationMs;
  final bool completed;
  final bool skipped;
  final String? queueSource;
  final String? metadataJson;
}

/// 把播放器的状态变化整理成"播放会话",达到阈值后产出一条事件。
///
/// 只负责会话生命周期和阈值判断,不直接访问 Riverpod/DB;
/// 具体写库由上层通过 [onEvent] 完成。
class PlaybackSessionTracker {
  PlaybackSessionTracker({
    required this.sourceId,
    required this.queueSource,
    required this.onEvent,
  });

  /// 会话开始时读取当前音乐库来源标识
  final String Function() sourceId;

  /// 会话开始时读取队列来源(如"搜索"/专辑名)
  final String Function() queueSource;

  final void Function(PlaySessionEvent event) onEvent;

  _Session? _session;

  /// 切歌/开始播放新曲目:结算上一段(记为跳过),再开启新会话
  void onTrackChanged(rust.UiTrack? track) {
    _finalize(completed: false);
    if (track == null) return;
    _session = _Session(
      track: track,
      sourceId: sourceId(),
      queueSource: queueSource(),
      startedAt: DateTime.now().millisecondsSinceEpoch,
      durationMs: track.durationSeconds.toInt() * 1000,
    );
  }

  void onPlaying(bool playing) {
    final session = _session;
    if (session == null) return;
    session.playing = playing;
    if (playing) session.sawPlay = true;
  }

  /// 正常播放推进才累计;seek/回退产生的跳变不计入收听时长
  void onPosition(Duration position) {
    final session = _session;
    if (session == null) return;
    final ms = position.inMilliseconds;
    if (session.playing && session.sawPlay) {
      final delta = ms - session.lastPositionMs;
      if (delta > 0 && delta < 3000) {
        session.listenedMs += delta;
      }
    }
    session.lastPositionMs = ms;
  }

  void onSeek(Duration position) {
    _session?.lastPositionMs = position.inMilliseconds;
  }

  /// 曲目自然播完
  void onCompleted() {
    _finalize(completed: true);
  }

  void _finalize({required bool completed}) {
    final session = _session;
    _session = null;
    if (session == null || !session.sawPlay) return;

    // 30 秒或半首(短歌),与主流 scrobble 阈值一致
    final threshold = session.durationMs > 0
        ? math.min(30000, (session.durationMs * 0.5).round())
        : 30000;
    if (session.listenedMs < threshold) return;

    final track = session.track;
    onEvent(
      PlaySessionEvent(
        source: 'local',
        sourceId: session.sourceId,
        trackId: track.relativePath ?? track.id,
        startedAt: session.startedAt,
        listenedMs: session.listenedMs,
        durationMs: session.durationMs,
        completed: completed,
        skipped: !completed,
        queueSource: session.queueSource,
        metadataJson: jsonEncode(<String, Object?>{
          'title': track.title,
          'artist': track.artist,
          'album': track.album,
          'albumId': track.albumId,
          'artistId': track.artistId,
          'genre': track.genre,
        }),
      ),
    );
  }
}

class _Session {
  _Session({
    required this.track,
    required this.sourceId,
    required this.queueSource,
    required this.startedAt,
    required this.durationMs,
  });

  final rust.UiTrack track;
  final String sourceId;
  final String queueSource;
  final int startedAt;
  final int durationMs;

  int listenedMs = 0;
  int lastPositionMs = 0;
  bool playing = false;
  bool sawPlay = false;
}

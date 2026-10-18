import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/stats.dart' as rust_stats;

import 'playback_session_tracker.dart';

/// 播放统计服务:把 Dart 侧的播放会话写入 Rust 统计库
final playbackStatsServiceProvider = Provider<PlaybackStatsService>(
  (ref) => PlaybackStatsService(),
);

class PlaybackStatsService {
  Future<void> record(PlaySessionEvent event) async {
    await rust_stats.recordPlayEvent(
      event: rust_stats.UiPlayEvent(
        source: event.source,
        sourceId: event.sourceId,
        trackId: event.trackId,
        startedAt: event.startedAt,
        listenedMs: event.listenedMs,
        trackDurationMs:
            event.durationMs > 0 ? event.durationMs : null,
        completed: event.completed,
        skipped: event.skipped,
        queueSource: event.queueSource,
        metadataJson: event.metadataJson,
      ),
    );
  }
}

/// 统计版本号:每写入一条播放事件 +1,用于刷新统计查询
final statsRevisionProvider = NotifierProvider<StatsRevisionNotifier, int>(
  StatsRevisionNotifier.new,
);

class StatsRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

/// 跨音源的曲目统计 key(本地与远端 track_id 可能重复,必须带 source/sourceId)
String trackStatKey(String source, String sourceId, String trackId) =>
    '$source\u0000$sourceId\u0000$trackId';

/// 所有音源的曲目统计,按 source + sourceId + trackId 索引
final allTrackStatsProvider =
    FutureProvider<Map<String, rust_stats.UiTrackStat>>((ref) async {
  ref.watch(statsRevisionProvider);
  try {
    final stats = await rust_stats.queryAllTrackStats();
    return <String, rust_stats.UiTrackStat>{
      for (final stat in stats)
        trackStatKey(stat.source, stat.sourceId, stat.trackId): stat,
    };
  } catch (e) {
    debugPrint('读取全部播放统计失败: $e');
    return const <String, rust_stats.UiTrackStat>{};
  }
});

/// 首页播放记录的时间范围
enum HistoryPeriod { today, week, month }

/// 某时间段内的播放汇总
class HistorySummary {
  const HistorySummary({
    required this.playCount,
    required this.trackCount,
    required this.listenedMs,
    required this.topArtist,
    required this.topArtistPlays,
    required this.topAlbum,
    required this.topAlbumArtist,
    required this.topAlbumPlays,
  });

  const HistorySummary.zero()
      : playCount = 0,
        trackCount = 0,
        listenedMs = 0,
        topArtist = null,
        topArtistPlays = 0,
        topAlbum = null,
        topAlbumArtist = null,
        topAlbumPlays = 0;

  final int playCount;
  final int trackCount;
  final int listenedMs;
  final String? topArtist;
  final int topArtistPlays;
  final String? topAlbum;
  final String? topAlbumArtist;
  final int topAlbumPlays;
}

/// 首页"播放记录"摘要(本地 + 远端一起统计)
final historySummaryProvider =
    FutureProvider.family<HistorySummary, HistoryPeriod>((ref, period) async {
  ref.watch(statsRevisionProvider);

  final now = DateTime.now();
  final start = switch (period) {
    HistoryPeriod.today => DateTime(now.year, now.month, now.day),
    HistoryPeriod.week =>
      DateTime(now.year, now.month, now.day - (now.weekday - 1)),
    HistoryPeriod.month => DateTime(now.year, now.month, 1),
  };
  // +1 秒确保刚写入的事件也能被包含
  final end = now.add(const Duration(seconds: 1));

  try {
    final summary = await rust_stats.queryHistorySummaryAll(
      startMs: start.millisecondsSinceEpoch,
      endMs: end.millisecondsSinceEpoch,
    );
    return HistorySummary(
      playCount: summary.playCount.toInt(),
      trackCount: summary.trackCount.toInt(),
      listenedMs: summary.listenedMs.toInt(),
      topArtist: summary.topArtist,
      topArtistPlays: summary.topArtistPlays.toInt(),
      topAlbum: summary.topAlbum,
      topAlbumArtist: summary.topAlbumArtist,
      topAlbumPlays: summary.topAlbumPlays.toInt(),
    );
  } catch (e) {
    debugPrint('读取播放记录汇总失败: $e');
    return const HistorySummary.zero();
  }
});

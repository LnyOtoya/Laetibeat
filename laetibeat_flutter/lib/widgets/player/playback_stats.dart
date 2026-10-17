import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/stats.dart' as rust_stats;

import '../settings/music_library_provider.dart';
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

  Future<List<rust_stats.UiTrackStat>> trackStats({
    required String sourceId,
  }) {
    return rust_stats.queryTrackStats(source: 'local', sourceId: sourceId);
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

/// 当前本地库的曲目统计,按 track_id 索引
final trackStatsProvider =
    FutureProvider<Map<String, rust_stats.UiTrackStat>>((ref) async {
  ref.watch(statsRevisionProvider);
  final directory =
      ref.watch(musicLibraryProvider.select((s) => s.value?.directory));
  if (directory == null) return const <String, rust_stats.UiTrackStat>{};

  try {
    final stats = await ref
        .read(playbackStatsServiceProvider)
        .trackStats(sourceId: directory);
    return <String, rust_stats.UiTrackStat>{
      for (final stat in stats) stat.trackId: stat,
    };
  } catch (e) {
    debugPrint('读取播放统计失败: $e');
    return const <String, rust_stats.UiTrackStat>{};
  }
});

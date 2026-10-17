import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/stats.dart' as rust_stats;

import 'player/playback_stats.dart';
import 'settings/music_library_provider.dart';

/// 首页"为你推荐"的三种模式
enum RecommendMode { neverPlayed, longTimeNoSee, mostPlayed }

const int _fourteenDaysMs = 14 * 24 * 60 * 60 * 1000;

/// 专辑级推荐:把曲目统计聚合到专辑,再按模式排序。
/// 统计加载中/无历史时回退到最近添加,保证首页不空。
final albumRecommendationsProvider =
    Provider.family<List<rust.UiAlbum>, RecommendMode>((ref, mode) {
  final library = ref.watch(musicLibraryProvider).value;
  if (library == null || library.albums.isEmpty) {
    return const <rust.UiAlbum>[];
  }

  final stats = ref.watch(trackStatsProvider).value ??
      const <String, rust_stats.UiTrackStat>{};
  final byId = {for (final t in library.tracks) t.id: t};
  final nowMs = DateTime.now().millisecondsSinceEpoch;

  final scored = <_AlbumScore>[];
  for (final album in library.albums) {
    var plays = 0;
    var skips = 0;
    var completedWeighted = 0.0;
    var lastPlayedAt = 0;
    var latestMtime = 0;

    for (final id in album.trackIds) {
      final track = byId[id];
      if (track == null) continue;

      final mtime = track.modifiedMs?.toInt() ?? 0;
      if (mtime > latestMtime) latestMtime = mtime;

      final stat = stats[track.relativePath ?? track.id];
      if (stat == null) continue;

      final playCount = stat.playCount.toInt();
      plays += playCount;
      skips += stat.skipCount.toInt();
      completedWeighted += stat.completionRate * playCount;

      final last = stat.lastPlayedAt.toInt();
      if (last > lastPlayedAt) lastPlayedAt = last;
    }

    scored.add(
      _AlbumScore(
        album: album,
        plays: plays,
        skips: skips,
        completion: plays > 0 ? completedWeighted / plays : 0.0,
        lastPlayedAt: lastPlayedAt,
        latestMtime: latestMtime,
      ),
    );
  }

  List<_AlbumScore> candidates;
  switch (mode) {
    case RecommendMode.neverPlayed:
      candidates = scored.where((s) => s.plays == 0).toList()
        ..sort((a, b) => b.latestMtime.compareTo(a.latestMtime));
      // 同一天保持稳定,但在最近添加的前 12 张里做轮换
      if (candidates.length > 1) {
        final window = candidates.take(12).toList()
          ..shuffle(Random(_dailySeed() + 1));
        candidates = [...window, ...candidates.skip(12)];
      }
      break;
    case RecommendMode.longTimeNoSee:
      candidates = scored
          .where(
            (s) =>
                s.plays > 0 &&
                s.lastPlayedAt > 0 &&
                nowMs - s.lastPlayedAt >= _fourteenDaysMs,
          )
          .toList()
        ..sort(
          (a, b) => b.longTimeScore(nowMs).compareTo(a.longTimeScore(nowMs)),
        );
      break;
    case RecommendMode.mostPlayed:
      candidates = scored.where((s) => s.plays > 0).toList()
        ..sort((a, b) => b.frequentScore.compareTo(a.frequentScore));
      break;
  }

  // 冷启动或数据不足:回退到最近添加
  if (candidates.isEmpty) {
    candidates = [...scored]
      ..sort((a, b) => b.latestMtime.compareTo(a.latestMtime));
  }

  return _pickWithArtistDiversity(candidates, 4)
      .map((entry) => entry.album)
      .toList();
});

int _dailySeed() {
  final now = DateTime.now();
  return now.year * 10000 + now.month * 100 + now.day;
}

/// 先保证艺术家多样性:第一轮每个艺术家最多 1 张,数量不足再放宽到 2 张。
List<_AlbumScore> _pickWithArtistDiversity(
  List<_AlbumScore> candidates,
  int count,
) {
  final picked = <_AlbumScore>[];
  final artistCounts = <String, int>{};

  for (final candidate in candidates) {
    if (picked.length >= count) break;
    final used = artistCounts[candidate.album.artist] ?? 0;
    if (used >= 1) continue;
    picked.add(candidate);
    artistCounts[candidate.album.artist] = used + 1;
  }

  if (picked.length < count) {
    for (final candidate in candidates) {
      if (picked.length >= count) break;
      if (picked.contains(candidate)) continue;
      final used = artistCounts[candidate.album.artist] ?? 0;
      if (used >= 2) continue;
      picked.add(candidate);
      artistCounts[candidate.album.artist] = used + 1;
    }
  }

  return picked;
}

class _AlbumScore {
  const _AlbumScore({
    required this.album,
    required this.plays,
    required this.skips,
    required this.completion,
    required this.lastPlayedAt,
    required this.latestMtime,
  });

  final rust.UiAlbum album;
  final int plays;
  final int skips;
  final double completion;
  final int lastPlayedAt;
  final int latestMtime;

  /// 常听:播放次数 × 完成度,跳过作为负反馈
  double get frequentScore => plays * (0.5 + 0.5 * completion) - 0.5 * skips;

  /// 很久没听:历史亲和度 × 距上次播放天数权重
  double longTimeScore(int nowMs) {
    final days = (nowMs - lastPlayedAt) / const Duration(days: 1).inMilliseconds;
    return plays * (0.5 + 0.5 * completion) * (1 + days / 30);
  }
}

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/stats.dart' as rust_stats;

import 'player/playback_stats.dart';
import 'remote_browser_provider.dart';
import 'settings/music_library_provider.dart';
import 'settings/subsonic_provider.dart';

/// 首页"为你推荐"的三种模式
enum RecommendMode { neverPlayed, longTimeNoSee, mostPlayed }

const int _fourteenDaysMs = 14 * 24 * 60 * 60 * 1000;

/// 推荐卡片使用的统一专辑模型,本地与远端共用。
class RecommendedAlbum {
  const RecommendedAlbum({
    required this.title,
    required this.artist,
    required this.tracks,
    this.coverTrack,
    this.remoteSourceId,
    this.remoteCoverId,
  });

  final String title;
  final String artist;

  /// 可直接播放的曲目(远端曲目已转换为 UiTrack)
  final List<rust.UiTrack> tracks;

  /// 本地封面代表曲目
  final rust.UiTrack? coverTrack;

  /// 远端封面来源(与 coverTrack 二选一)
  final String? remoteSourceId;
  final String? remoteCoverId;

  bool get isRemote => remoteSourceId != null;
}

/// 专辑级推荐:把本地与远端曲目统计聚合到专辑,再按模式排序。
/// 统计加载中/无历史时回退到最近添加,保证首页不空。
final albumRecommendationsProvider =
    FutureProvider.family<List<RecommendedAlbum>, RecommendMode>((
      ref,
      mode,
    ) async {
      final library = ref.watch(musicLibraryProvider).value;
      final stats =
          ref.watch(allTrackStatsProvider).value ??
          const <String, rust_stats.UiTrackStat>{};
      final servers =
          ref.watch(subsonicServersProvider).value ??
          const <SubsonicServerConfig>[];
      final config = servers.isEmpty ? null : servers.first;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final scored = <_AlbumScore>[];

      // 本地专辑
      if (library != null) {
        final byId = {for (final track in library.tracks) track.id: track};
        final localSourceId = library.directory ?? '';
        for (final album in library.albums) {
          final tracks = <rust.UiTrack>[
            for (final id in album.trackIds)
              if (byId[id] != null) byId[id]!,
          ];
          if (tracks.isEmpty) continue;

          var latestMtime = 0;
          for (final track in tracks) {
            final mtime = track.modifiedMs?.toInt() ?? 0;
            if (mtime > latestMtime) latestMtime = mtime;
          }

          final score = _scoreTracks(
            tracks: tracks,
            stats: stats,
            statKeyFor: (track) => trackStatKey(
              'local',
              localSourceId,
              track.relativePath ?? track.id,
            ),
          );
          scored.add(
            _AlbumScore(
              album: RecommendedAlbum(
                title: album.title,
                artist: album.artist,
                tracks: tracks,
                coverTrack: byId[album.coverTrackId],
              ),
              plays: score.plays,
              skips: score.skips,
              completion: score.completion,
              lastPlayedAt: score.lastPlayedAt,
              latestMtime: latestMtime,
            ),
          );
        }
      }

      // 远端专辑:读已同步的 SQLite 快照
      if (config != null) {
        try {
          final remoteAlbums = await ref.watch(
            remoteAllAlbumsProvider(config.id).future,
          );
          final remoteTracks = await ref.watch(
            remoteAllTracksProvider(config.id).future,
          );
          if (remoteAlbums.isNotEmpty && remoteTracks.isNotEmpty) {
            final tracksByAlbum = <String, List<rust.UiTrack>>{};
            for (final track in remoteTracks) {
              final albumId = track.albumId;
              if (albumId == null || albumId.isEmpty) continue;
              (tracksByAlbum[albumId] ??= <rust.UiTrack>[]).add(
                remoteTrackToUiTrack(track, config.id),
              );
            }

            for (final album in remoteAlbums) {
              final tracks = tracksByAlbum[album.id];
              if (tracks == null || tracks.isEmpty) continue;

              final score = _scoreTracks(
                tracks: tracks,
                stats: stats,
                statKeyFor: (track) =>
                    trackStatKey('opensubsonic', config.id, track.id),
              );
              scored.add(
                _AlbumScore(
                  album: RecommendedAlbum(
                    title: album.title,
                    artist: album.artist,
                    tracks: tracks,
                    remoteSourceId: config.id,
                    remoteCoverId: album.coverId ?? _firstCoverId(tracks),
                  ),
                  plays: score.plays,
                  skips: score.skips,
                  completion: score.completion,
                  lastPlayedAt: score.lastPlayedAt,
                  latestMtime: 0,
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('加载远端推荐数据失败: $e');
        }
      }

      if (scored.isEmpty) return const <RecommendedAlbum>[];

      final candidates = _candidatesFor(mode, scored, nowMs);
      return _pickWithArtistDiversity(
        candidates,
        10,
      ).map((entry) => entry.album).toList();
    });

List<_AlbumScore> _candidatesFor(
  RecommendMode mode,
  List<_AlbumScore> scored,
  int nowMs,
) {
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
      candidates =
          scored
              .where(
                (s) =>
                    s.plays > 0 &&
                    s.lastPlayedAt > 0 &&
                    nowMs - s.lastPlayedAt >= _fourteenDaysMs,
              )
              .toList()
            ..sort(
              (a, b) =>
                  b.longTimeScore(nowMs).compareTo(a.longTimeScore(nowMs)),
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
  return candidates;
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
    final used = artistCounts[candidate.artist] ?? 0;
    if (used >= 1) continue;
    picked.add(candidate);
    artistCounts[candidate.artist] = used + 1;
  }

  if (picked.length < count) {
    for (final candidate in candidates) {
      if (picked.length >= count) break;
      if (picked.contains(candidate)) continue;
      final used = artistCounts[candidate.artist] ?? 0;
      if (used >= 2) continue;
      picked.add(candidate);
      artistCounts[candidate.artist] = used + 1;
    }
  }

  // 数量不够时不再限制同一艺术家，保证能填满首页更多卡位。
  if (picked.length < count) {
    for (final candidate in candidates) {
      if (picked.length >= count) break;
      if (picked.contains(candidate)) continue;
      picked.add(candidate);
    }
  }

  return picked;
}

_TrackScore _scoreTracks({
  required List<rust.UiTrack> tracks,
  required Map<String, rust_stats.UiTrackStat> stats,
  required String Function(rust.UiTrack track) statKeyFor,
}) {
  var plays = 0;
  var skips = 0;
  var completedWeighted = 0.0;
  var lastPlayedAt = 0;

  for (final track in tracks) {
    final stat = stats[statKeyFor(track)];
    if (stat == null) continue;

    final playCount = stat.playCount.toInt();
    plays += playCount;
    skips += stat.skipCount.toInt();
    completedWeighted += stat.completionRate * playCount;

    final last = stat.lastPlayedAt.toInt();
    if (last > lastPlayedAt) lastPlayedAt = last;
  }

  return _TrackScore(
    plays: plays,
    skips: skips,
    completion: plays > 0 ? completedWeighted / plays : 0.0,
    lastPlayedAt: lastPlayedAt,
  );
}

String? _firstCoverId(List<rust.UiTrack> tracks) {
  for (final track in tracks) {
    final coverId = track.coverId;
    if (coverId != null && coverId.isNotEmpty) return coverId;
  }
  return null;
}

int _dailySeed() {
  final now = DateTime.now();
  return now.year * 10000 + now.month * 100 + now.day;
}

class _TrackScore {
  const _TrackScore({
    required this.plays,
    required this.skips,
    required this.completion,
    required this.lastPlayedAt,
  });

  final int plays;
  final int skips;
  final double completion;
  final int lastPlayedAt;
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

  final RecommendedAlbum album;
  final int plays;
  final int skips;
  final double completion;
  final int lastPlayedAt;
  final int latestMtime;

  String get artist => album.artist;

  /// 常听:播放次数 × 完成度,跳过作为负反馈
  double get frequentScore => plays * (0.5 + 0.5 * completion) - 0.5 * skips;

  /// 很久没听:历史亲和度 × 距上次播放天数权重
  double longTimeScore(int nowMs) {
    final days =
        (nowMs - lastPlayedAt) / const Duration(days: 1).inMilliseconds;
    return plays * (0.5 + 0.5 * completion) * (1 + days / 30);
  }
}

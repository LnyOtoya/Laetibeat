import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../widgets/mobile_large_subpage_app_bar.dart';

/// 专辑详情页。先展示顶部返回栏和全宽专辑封面。
class AlbumDetailPage extends ConsumerWidget {
  const AlbumDetailPage({
    super.key,
    required this.sourceId,
    required this.album,
  });

  final String sourceId;
  final rust_subsonic.UiRemoteAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final remoteTracks = ref.watch(
      remoteTracksProvider((sourceId: sourceId, albumId: album.id)),
    );
    final tracks = (remoteTracks.value ?? const [])
        .map((track) => remoteTrackToUiTrack(track, sourceId))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      extendBodyBehindAppBar: true,
      appBar: mobileLargeSubpageAppBar(
        context,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: _AlbumBanner(sourceId: sourceId, coverId: album.coverId),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typeScale.headlineSmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typeScale.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        M3EChip(
                          label: '立即播放',
                          leading: const Icon(M3EIcons.play_arrow),
                          elevated: true,
                          onPressed: tracks.isEmpty
                              ? null
                              : () => ref
                                    .read(playerProvider.notifier)
                                    .load(tracks, 0, source: album.title),
                        ),
                        const SizedBox(width: 8),
                        M3EChip(
                          label: '随机播放',
                          leading: const Icon(M3EIcons.shuffle),
                          elevated: true,
                          onPressed: tracks.isEmpty
                              ? null
                              : () => ref
                                    .read(playerProvider.notifier)
                                    .playShuffled(tracks, source: album.title),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  '发行日期: ${album.year?.toString() ?? '未知'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.typeScale.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatSongCount(album.songCount?.toInt())}首歌曲，'
                  '${_formatAlbumDuration(album.durationSeconds?.toInt())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.typeScale.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildTrackSections(theme, ref, remoteTracks),
          SizedBox(height: 24 + bottomInset),
        ],
      ),
    );
  }

  Widget _buildTrackSections(
    M3EThemeData theme,
    WidgetRef ref,
    AsyncValue<List<rust_subsonic.UiRemoteTrack>> tracksAsync,
  ) {
    return tracksAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: M3ELoadingIndicator(
            color: theme.colorScheme.primary,
            containerColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      error: (Object error, StackTrace stackTrace) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          '读取歌曲失败\n$error',
          textAlign: TextAlign.center,
          style: theme.typeScale.bodyMedium.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('暂无歌曲')),
          );
        }

        final allTracks = list
            .map((track) => remoteTrackToUiTrack(track, sourceId))
            .toList(growable: false);
        final groups = <int, List<rust_subsonic.UiRemoteTrack>>{};
        for (final track in list) {
          final disc = track.discNumber ?? 1;
          groups.putIfAbsent(disc, () => []).add(track);
        }
        final discs = groups.keys.toList()..sort();
        final multiDisc = discs.length > 1;

        final children = <Widget>[];
        int globalIndex = 0;
        for (final disc in discs) {
          final discTracks = groups[disc]!;
          final startIndex = globalIndex;
          if (multiDisc) {
            children.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 24,
                      child: _DiscCover(
                        sourceId: sourceId,
                        coverId: album.coverId,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '碟片 $disc',
                      style: theme.typeScale.titleSmall.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: M3EList(
                color: theme.colorScheme.surface,
                variant: M3ECardVariant.filled,
                itemCount: discTracks.length,
                onTap: (int index) {
                  ref
                      .read(playerProvider.notifier)
                      .load(allTracks, startIndex + index, source: album.title);
                },
                itemBuilder: (BuildContext context, int index) {
                  final track = discTracks[index];
                  final number = track.trackNumber ?? index + 1;
                  return M3EListItem(
                    leading: SizedBox.square(
                      dimension: 40,
                      child: Center(
                        child: Text(
                          '$number',
                          style: theme.typeScale.titleMedium.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    headline: track.title,
                    supportingText: track.artist,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatAlbumDuration(track.durationSeconds.toInt()),
                          style: theme.typeScale.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        M3EIconButton(
                          size: M3EIconButtonSize.xs,
                          variant: M3EIconButtonVariant.standard,
                          icon: const Icon(M3EIcons.favorite_border),
                          tooltip: '喜欢',
                          onPressed: () {},
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
          globalIndex += discTracks.length;
          if (multiDisc) children.add(const SizedBox(height: 16));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

String _formatSongCount(int? count) {
  if (count == null || count < 0) return '-- ';
  return '$count ';
}

String _formatAlbumDuration(int? seconds) {
  if (seconds == null || seconds < 0) return '时长未知';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$rest';
  }
  return '$minutes:$rest';
}

class _DiscCover extends ConsumerWidget {
  const _DiscCover({required this.sourceId, required this.coverId});

  final String sourceId;
  final String? coverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final id = coverId;
    final bytes = id == null || id.isEmpty
        ? null
        : ref
              .watch(remoteCoverProvider((sourceId: sourceId, coverId: id)))
              .value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: hasArt
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            )
          : ColoredBox(
              color: theme.colorScheme.secondaryContainer,
              child: Icon(
                M3EIcons.album,
                size: 14,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
    );
  }
}

class _AlbumBanner extends ConsumerWidget {
  const _AlbumBanner({required this.sourceId, required this.coverId});

  final String sourceId;
  final String? coverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final id = coverId;
    final bytes = id == null || id.isEmpty
        ? null
        : ref
              .watch(remoteCoverProvider((sourceId: sourceId, coverId: id)))
              .value;
    final hasArt = bytes != null && bytes.isNotEmpty;
    final shade = theme.colorScheme.primary;

    final Widget cover = hasArt
        ? Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          )
        : ColoredBox(
            color: theme.colorScheme.secondaryContainer,
            child: Center(
              child: Icon(
                M3EIcons.album,
                size: 56,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        cover,
        Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            widthFactor: 1,
            heightFactor: 0.38,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [shade.withValues(alpha: 0.35), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            widthFactor: 1,
            heightFactor: 0.55,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, shade.withValues(alpha: 0.5)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

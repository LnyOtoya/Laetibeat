import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../../widgets/player/cover_provider.dart';
import '../../../../widgets/player/player_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../widgets/recommendation_provider.dart';

//为你推荐区块:本地 + 远端播放统计的专辑级推荐
class MobileDailySection extends ConsumerStatefulWidget {
  const MobileDailySection({super.key});

  @override
  ConsumerState<MobileDailySection> createState() => _MobileDailySectionState();
}

class _MobileDailySectionState extends ConsumerState<MobileDailySection> {
  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final asyncRecommendations = ref.watch(
      albumRecommendationsProvider(RecommendMode.neverPlayed),
    );
    final recommendations =
        asyncRecommendations.value ?? const <RecommendedAlbum>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (asyncRecommendations.isLoading && recommendations.isEmpty)
          _loading(theme)
        else if (recommendations.isEmpty)
          _emptyHint(theme)
        else
          _RadialShapeGrid(
            albums: recommendations,
            onTap: (RecommendedAlbum album) => _playAlbum(
              album,
              recommendations,
              AppLocalizations.of(context).recommendedQueueSource,
            ),
          ),
      ],
    );
  }

  void _playAlbum(
    RecommendedAlbum album,
    List<RecommendedAlbum> albums,
    String source,
  ) {
    final queue = albums.expand((item) => item.tracks).toList(growable: false);
    if (queue.isEmpty) return;

    var startIndex = 0;
    for (final item in albums) {
      if (identical(item, album)) break;
      startIndex += item.tracks.length;
    }
    final safeIndex = startIndex.clamp(0, queue.length - 1);

    ref.read(playerProvider.notifier).load(queue, safeIndex, source: source);
  }

  Widget _loading(M3EThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
      child: Center(
        child: M3ELoadingIndicator(
          color: theme.colorScheme.primary,
          containerColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }

  Widget _emptyHint(M3EThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
      child: Text(
        '播放一些歌曲后，这里会根据收听记录生成推荐',
        style: theme.typeScale.bodyMedium.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 中间一个大 shape、周围一圈小 shape 的封面布局。
class _RadialShapeGrid extends StatelessWidget {
  const _RadialShapeGrid({required this.albums, required this.onTap});

  final List<RecommendedAlbum> albums;
  final ValueChanged<RecommendedAlbum> onTap;

  static const int _maxRingItems = 10;
  static const int _maxItems = 1 + _maxRingItems;

  static const List<M3EShapeKind> _ringShapes = <M3EShapeKind>[
    M3EShapeKind.cookie4Sided,
    M3EShapeKind.clover4Leaf,
    M3EShapeKind.arch,
    M3EShapeKind.gem,
    M3EShapeKind.cookie6Sided,
    M3EShapeKind.diamond,
  ];

  @override
  Widget build(BuildContext context) {
    final items = albums.take(_maxItems).toList(growable: false);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        final center = Offset(width / 2, width / 2);
        final centerSize = width * 0.38;
        final ringSize = width * 0.19;
        final ringRadius = width * 0.34;
        final ringItems = items.skip(1).toList(growable: false);

        return SizedBox(
          width: width,
          height: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (items.isNotEmpty)
                Positioned(
                  left: center.dx - centerSize / 2,
                  top: center.dy - centerSize / 2,
                  width: centerSize,
                  height: centerSize,
                  child: _buildCard(
                    items.first,
                    0,
                    shape: M3EShapeKind.cookie12Sided,
                    rotation: 0,
                  ),
                ),
              for (var i = 0; i < ringItems.length; i++)
                Positioned(
                  left:
                      center.dx +
                      math.cos(
                            -math.pi / 2 + 2 * math.pi * i / ringItems.length,
                          ) *
                          ringRadius -
                      ringSize / 2,
                  top:
                      center.dy +
                      math.sin(
                            -math.pi / 2 + 2 * math.pi * i / ringItems.length,
                          ) *
                          ringRadius -
                      ringSize / 2,
                  width: ringSize,
                  height: ringSize,
                  child: _buildCard(
                    ringItems[i],
                    i + 1,
                    shape: _ringShapes[i % _ringShapes.length],
                    rotation: i.isEven ? -0.055 : 0.055,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(
    RecommendedAlbum album,
    int index, {
    required M3EShapeKind shape,
    required double rotation,
  }) {
    return Semantics(
      button: true,
      label: '${album.title}, ${album.artist}',
      child: Transform.rotate(
        angle: rotation,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(album),
          child: M3EShapeContainer(
            kind: shape,
            child: _RecommendationCover(album: album),
          ),
        ),
      ),
    );
  }
}

//推荐卡片封面:本地读内嵌封面,远端读封面缓存,都没有则占位
class _RecommendationCover extends ConsumerWidget {
  const _RecommendationCover({required this.album});

  final RecommendedAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final bytes = _coverBytes(ref);
    final hasArt = bytes != null && bytes.isNotEmpty;

    if (hasArt) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    }

    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(
        M3EIcons.music_note,
        size: theme.spacing.xxl,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  Uint8List? _coverBytes(WidgetRef ref) {
    final track = album.coverTrack;
    if (track != null) {
      return ref.watch(trackCoverProvider(track)).value;
    }

    final sourceId = album.remoteSourceId;
    final coverId = album.remoteCoverId;
    if (sourceId != null && coverId != null && coverId.isNotEmpty) {
      return ref
          .watch(remoteCoverProvider((sourceId: sourceId, coverId: coverId)))
          .value;
    }
    return null;
  }
}

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
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xl),
            child: _SplitShapeCompositions(
              albums: recommendations,
              onTap: (RecommendedAlbum album) => _playAlbum(
                album,
                recommendations,
                AppLocalizations.of(context).recommendedQueueSource,
              ),
              onRandom: () {
                final tracks = recommendations
                    .expand((item) => item.tracks)
                    .toList(growable: false);
                ref
                    .read(playerProvider.notifier)
                    .playShuffled(
                      tracks,
                      source: AppLocalizations.of(
                        context,
                      ).recommendedQueueSource,
                    );
              },
              onRefresh: () {
                ref.read(recommendationRefreshProvider.notifier).refresh();
                ref.invalidate(
                  albumRecommendationsProvider(RecommendMode.neverPlayed),
                );
              },
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

/// 左右两组半边构图：左边露出右半边，右边露出左半边，中间留出空隙。
class _SplitShapeCompositions extends StatefulWidget {
  const _SplitShapeCompositions({
    required this.albums,
    required this.onTap,
    required this.onRandom,
    required this.onRefresh,
  });

  final List<RecommendedAlbum> albums;
  final ValueChanged<RecommendedAlbum> onTap;
  final VoidCallback onRandom;
  final VoidCallback onRefresh;

  @override
  State<_SplitShapeCompositions> createState() =>
      _SplitShapeCompositionsState();
}

class _SplitShapeCompositionsState extends State<_SplitShapeCompositions>
    with SingleTickerProviderStateMixin {
  static const int _maxPerSide = 11;

  late final AnimationController _rotationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );
  late final Animation<double> _turns = CurvedAnimation(
    parent: _rotationController,
    curve: Curves.easeInOutCubic,
  );

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _handleRefresh() {
    _rotationController.forward(from: 0);
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final leftCount = widget.albums.length <= 1
        ? widget.albums.length
        : (widget.albums.length / 2).ceil().clamp(1, _maxPerSide);
    final leftAlbums = widget.albums.take(leftCount).toList(growable: false);
    final rightAlbums = widget.albums
        .skip(leftCount)
        .take(_maxPerSide)
        .toList(growable: false);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        final side = width * 0.84;
        final buttonSize = width * 0.24;
        final scheme = M3ETheme.of(context).colorScheme;

        return SizedBox(
          width: width,
          height: side,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (leftAlbums.isNotEmpty)
                  Positioned(
                    left: -side / 2,
                    top: 0,
                    width: side,
                    height: side,
                    child: _RadialComposition(
                      albums: leftAlbums,
                      size: side,
                      turns: _turns,
                      onTap: widget.onTap,
                    ),
                  ),
                if (rightAlbums.isNotEmpty)
                  Positioned(
                    left: width - side / 2,
                    top: 0,
                    width: side,
                    height: side,
                    child: _RadialComposition(
                      albums: rightAlbums,
                      size: side,
                      turns: _turns,
                      onTap: widget.onTap,
                    ),
                  ),
                Positioned(
                  left: (width - buttonSize) / 2,
                  top: side * 0.06,
                  width: buttonSize,
                  height: buttonSize,
                  child: _CenterShapeButton(
                    shape: M3EShapeKind.cookie12Sided,
                    icon: M3EIcons.shuffle,
                    label: AppLocalizations.of(context).shuffleRecommendations,
                    background: scheme.secondaryContainer,
                    foreground: scheme.onSecondaryContainer,
                    onTap: widget.onRandom,
                  ),
                ),
                Positioned(
                  left: (width - buttonSize) / 2,
                  bottom: side * 0.06,
                  width: buttonSize,
                  height: buttonSize,
                  child: _CenterShapeButton(
                    shape: M3EShapeKind.burst,
                    icon: M3EIcons.refresh,
                    label: AppLocalizations.of(context).refreshRecommendations,
                    background: scheme.tertiaryContainer,
                    foreground: scheme.onTertiaryContainer,
                    onTap: _handleRefresh,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 中缝里的圆形/异形操作按钮。点击时自转一圈。
class _CenterShapeButton extends StatefulWidget {
  const _CenterShapeButton({
    required this.shape,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final M3EShapeKind shape;
  final IconData icon;
  final String label;
  final Color? background;
  final Color? foreground;
  final VoidCallback onTap;

  @override
  State<_CenterShapeButton> createState() => _CenterShapeButtonState();
}

class _CenterShapeButtonState extends State<_CenterShapeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final Animation<double> _turns = CurvedAnimation(
    parent: _spinController,
    curve: Curves.easeInOutCubic,
  );

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _spinController.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final filled = widget.background != null && widget.foreground != null;

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: RotationTransition(
          turns: _turns,
          child: M3EShapeContainer(
            kind: widget.shape,
            color: filled
                ? widget.background
                : theme.colorScheme.primaryContainer,
            child: Center(
              child: Icon(
                widget.icon,
                size: theme.spacing.xl,
                color: filled
                    ? widget.foreground
                    : theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 中间一个大 shape、周围一圈小 shape 的完整构图。
class _RadialComposition extends StatelessWidget {
  const _RadialComposition({
    required this.albums,
    required this.size,
    required this.turns,
    required this.onTap,
  });

  final List<RecommendedAlbum> albums;
  final double size;
  final Animation<double> turns;
  final ValueChanged<RecommendedAlbum> onTap;

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
    final center = Offset(size / 2, size / 2);
    final centerSize = size * 0.44;
    final ringSize = size * 0.22;
    final ringRadius = size * 0.36;
    final ringItems = albums.skip(1).toList(growable: false);

    return AnimatedBuilder(
      animation: turns,
      builder: (BuildContext context, Widget? child) {
        final orbit = turns.value * 2 * math.pi;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (albums.isNotEmpty)
                Positioned(
                  left: center.dx - centerSize / 2,
                  top: center.dy - centerSize / 2,
                  width: centerSize,
                  height: centerSize,
                  child: _buildCard(
                    albums.first,
                    0,
                    shape: M3EShapeKind.cookie12Sided,
                    rotation: orbit,
                  ),
                ),
              for (var i = 0; i < ringItems.length; i++)
                Positioned(
                  left:
                      center.dx +
                      math.cos(
                            -math.pi / 2 +
                                2 * math.pi * i / ringItems.length +
                                orbit,
                          ) *
                          ringRadius -
                      ringSize / 2,
                  top:
                      center.dy +
                      math.sin(
                            -math.pi / 2 +
                                2 * math.pi * i / ringItems.length +
                                orbit,
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

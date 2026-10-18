import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../animations.dart';
import 'album_card.dart';
import 'player/cover_provider.dart';
import 'player/player_provider.dart';
import 'recommendation_provider.dart';

//为你推荐区块:本地 + 远端播放统计的专辑级推荐
class DailySection extends ConsumerStatefulWidget {
  const DailySection({super.key});

  @override
  ConsumerState<DailySection> createState() => _DailySectionState();
}

class _DailySectionState extends ConsumerState<DailySection> {
  //当前选中的筛选标签
  int _selectedIndex = 0;

  //筛选选项
  static const List<String> _filters = <String>['未曾听过', '很久没听', '常听专辑'];

  RecommendMode get _mode => switch (_selectedIndex) {
        0 => RecommendMode.neverPlayed,
        1 => RecommendMode.longTimeNoSee,
        _ => RecommendMode.mostPlayed,
      };

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final asyncRecommendations = ref.watch(albumRecommendationsProvider(_mode));
    final recommendations =
        asyncRecommendations.value ?? const <RecommendedAlbum>[];

    return AnimatedContainer(
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
      padding: EdgeInsets.all(theme.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //上部分:标题 + 筛选按钮组
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '为你推荐',
                style: theme.typeScale.titleLarge,
              ),
              M3EButtonGroup(
                type: M3EButtonGroupType.connected,
                actions: _filters
                    .map(
                      (filter) => M3EButtonGroupAction(label: Text(filter)),
                    )
                    .toList(),
                selectedIndex: _selectedIndex,
                onSelectedIndexChanged: (index) {
                  setState(() => _selectedIndex = index ?? 0);
                },
              ),
            ],
          ),
          SizedBox(height: theme.spacing.lg),
          if (asyncRecommendations.isLoading && recommendations.isEmpty)
            _loading(theme)
          else if (recommendations.isEmpty)
            _emptyHint(theme)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final spacing = theme.spacing.md;
                // 固定按 4 列槽位计算卡片宽度:推荐数量不足时不会把卡片拉大
                final available =
                    constraints.maxWidth.isFinite ? constraints.maxWidth : 800.0;
                final cardWidth = (available - spacing * 3) / 4;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < recommendations.length; i++) ...[
                      if (i > 0) SizedBox(width: spacing),
                      SizedBox(
                        width: cardWidth,
                        child: AlbumCard(
                          title: recommendations[i].title,
                          subtitle: recommendations[i].artist,
                          cover: _RecommendationCover(
                            album: recommendations[i],
                          ),
                          onTap: () => _playAlbum(recommendations[i]),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  void _playAlbum(RecommendedAlbum album) {
    if (album.tracks.isEmpty) return;
    ref.read(playerProvider.notifier).load(
          album.tracks,
          0,
          source: album.title,
        );
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

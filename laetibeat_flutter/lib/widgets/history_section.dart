import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../animations.dart';
import 'player/playback_stats.dart';

//首页播放记录摘要:今天/本周/本月的累计播放与收听时长
class HistorySection extends ConsumerStatefulWidget {
  const HistorySection({super.key});

  @override
  ConsumerState<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends ConsumerState<HistorySection> {
  static const List<String> _filters = <String>['今天', '本周', '本月'];

  HistoryPeriod _period = HistoryPeriod.today;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final summary = ref.watch(historySummaryProvider(_period)).value;
    final topArtistPlays = summary?.topArtistPlays ?? 0;
    final topAlbumArtist = summary?.topAlbumArtist;

    return AnimatedContainer(
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
      padding: EdgeInsets.all(theme.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          //标题行:播放记录 + 时间范围
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('播放记录', style: theme.typeScale.titleLarge),
              M3EButtonGroup(
                type: M3EButtonGroupType.connected,
                actions: _filters
                    .map(
                      (filter) => M3EButtonGroupAction(label: Text(filter)),
                    )
                    .toList(),
                selectedIndex: _period.index,
                onSelectedIndexChanged: (index) {
                  setState(() {
                    _period = HistoryPeriod.values[index ?? 0];
                  });
                },
              ),
            ],
          ),
          SizedBox(height: theme.spacing.lg),
          //两块统计卡片:累计播放曲目数 / 收听总时长
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: '累计播放',
                  value: summary == null ? '—' : '${summary.trackCount} 首',
                ),
              ),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: _MetricCard(
                  label: '收听时长',
                  value: summary == null
                      ? '—'
                      : _formatListened(summary.listenedMs),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          //第二行:播放最多的歌手 / 专辑
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Top 歌手',
                    value: summary?.topArtist ?? '—',
                    supporting:
                        topArtistPlays > 0 ? '$topArtistPlays 次播放' : null,
                    nameValue: true,
                  ),
                ),
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: _MetricCard(
                    label: 'Top 专辑',
                    value: summary?.topAlbum ?? '—',
                    supporting: topAlbumArtist,
                    nameValue: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.supporting,
    this.nameValue = false,
  });

  final String label;
  final String value;
  final String? supporting;

  /// 歌手/专辑名使用稍小字号并允许两行
  final bool nameValue;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    return M3ECard(
      variant: M3ECardVariant.filled,
      color: scheme.surfaceContainerHigh,
      borderRadius: M3EDimensions.borderRadiusMedium,
      padding: EdgeInsets.all(theme.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.typeScale.labelLarge.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          Text(
            value,
            style: nameValue
                ? theme.typeScale.titleLarge
                : theme.typeScale.headlineMedium,
            maxLines: nameValue ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (supporting != null) ...[
            SizedBox(height: theme.spacing.xs),
            Text(
              supporting!,
              style: theme.typeScale.labelMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

String _formatListened(int ms) {
  final totalMinutes = ms ~/ 60000;
  if (totalMinutes < 1) {
    final seconds = ms ~/ 1000;
    return seconds <= 0 ? '0 分钟' : '$seconds 秒';
  }
  if (totalMinutes < 60) return '$totalMinutes 分钟';

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return minutes == 0 ? '$hours 小时' : '$hours 小时 $minutes 分';
}

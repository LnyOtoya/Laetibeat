import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import '../../animations.dart';
import 'player_provider.dart';

/// 默认展示的行数(含当前正在播放的一行)
const int _visibleRows = 3;

/// 播放队列 —— 挂在右侧内容区底部、播放面板之下。
///
/// 从当前正在播放的曲目开始,往下展示后续曲目(不含已播过的);默认只显示
/// [_visibleRows] 行,右上角"查看全部"用弹层展开完整队列。点某行可跳播。
/// 顺带消费掉播放面板多出的高度,减少封面周围的留空。
class PlaybackQueue extends ConsumerWidget {
  const PlaybackQueue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final queue = player.queue;
    if (queue.isEmpty) {
      // 没有可播曲目时整块隐藏,不给空占位
      return const SizedBox.shrink();
    }

    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final start = player.currentIndex.clamp(0, queue.length - 1);
    final rows = queue.skip(start).take(_visibleRows).toList();
    final hasMore = queue.length - start > _visibleRows;

    // 外层包透明 Material,让内部 InkWell 有 Material 祖先可画墨水波纹
    // (右侧内容区本身是 AnimatedContainer/DecoratedBox,非 Material)
    return Material(
      type: MaterialType.transparency,
      child: AnimatedContainer(
        duration: kSectionAnimDuration,
        curve: kSectionAnimCurve,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(theme.spacing.md),
        ),
        padding: EdgeInsets.fromLTRB(
          theme.spacing.lg,
          theme.spacing.sm,
          theme.spacing.lg,
          theme.spacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶栏:队列标题 + 右上角"查看全部" / 数量
            Row(
              children: [
                Expanded(
                  child: Text(
                    '队列',
                    style: theme.typeScale.titleSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (hasMore)
                  InkWell(
                    onTap: () => _showAll(context, ref, queue, start, theme),
                    borderRadius: BorderRadius.circular(theme.spacing.sm),
                    child: Padding(
                      padding: EdgeInsets.all(theme.spacing.xs),
                      child: Text(
                        '查看全部',
                        style: theme.typeScale.labelMedium.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    '${queue.length - start} 首',
                    style: theme.typeScale.labelSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.xs),
            // i == 0 即当前正在播放的一行,全局索引为 start + i
            for (var i = 0; i < rows.length; i++)
              _row(theme, scheme, rows[i], start + i, i == 0, () {
                ref.read(playerProvider.notifier).play(start + i);
              }),
          ],
        ),
      ),
    );
  }

  Widget _row(
    M3EThemeData theme,
    M3EColorScheme scheme,
    rust.UiTrack track,
    int index,
    bool isCurrent,
    VoidCallback onPlay,
  ) {
    return InkWell(
      onTap: onPlay,
      borderRadius: BorderRadius.circular(theme.spacing.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
        child: Row(
          children: [
            M3EShapeContainer.square(
              width: theme.spacing.xxl,
              height: theme.spacing.xxl,
              color: isCurrent
                  ? scheme.primaryContainer
                  : scheme.secondaryContainer,
              child: Icon(
                isCurrent ? Icons.play_arrow : Icons.music_note,
                size: 20,
                color: isCurrent ? scheme.onPrimaryContainer : null,
              ),
            ),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: theme.typeScale.bodyMedium.copyWith(
                      color: isCurrent ? scheme.primary : null,
                      fontWeight: isCurrent ? FontWeight.w600 : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${track.artist} · ${track.album}',
                    style: theme.typeScale.labelSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 弹出完整队列
  void _showAll(
    BuildContext context,
    WidgetRef ref,
    List<rust.UiTrack> queue,
    int start,
    M3EThemeData theme,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surfaceContainer,
      showDragHandle: true,
      builder: (sheetContext) {
        final upcoming = queue.skip(start).toList();
        return SafeArea(
          child: ListView.builder(
            itemCount: upcoming.length,
            itemBuilder: (sheetContext, i) {
              final isCurrent = i == 0;
              return ListTile(
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(playerProvider.notifier).play(start + i);
                },
                leading: Icon(
                  isCurrent ? Icons.play_arrow : Icons.music_note,
                  color: isCurrent ? theme.colorScheme.primary : null,
                ),
                title: Text(
                  upcoming[i].title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isCurrent
                      ? TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        )
                      : null,
                ),
                subtitle: Text(
                  '${upcoming[i].artist} · ${upcoming[i].album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
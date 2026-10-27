import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'cover_provider.dart';
import 'player_provider.dart';

// 移动端全局迷你播放器：M3E floating toolbar + 封面 + 标题/艺术家 + 三个控制按钮
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(playerProvider.select((s) => s.current));
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final cover = ref.watch(playbackCoverProvider).value;
    final notifier = ref.read(playerProvider.notifier);
    final hasTrack = track != null;

    return M3EToolbar.floating(
      colorStyle: M3EToolbarColorStyle.standard,
      axis: Axis.horizontal,
      leading: _MiniCover(cover: cover),
      titleText: track?.title ?? '暂无曲目',
      subtitleText: track?.artist ?? '暂无艺术家',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          M3EIconButton(
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(M3EIcons.skip_previous),
            tooltip: '上一曲',
            onPressed: hasTrack ? notifier.prev : null,
          ),
          M3EIconButton(
            variant: M3EIconButtonVariant.filled,
            icon: Icon(isPlaying ? M3EIcons.pause : M3EIcons.play_arrow),
            tooltip: isPlaying ? '暂停' : '播放',
            onPressed: hasTrack ? notifier.toggle : null,
          ),
          M3EIconButton(
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(M3EIcons.skip_next),
            tooltip: '下一曲',
            onPressed: hasTrack ? notifier.next : null,
          ),
        ],
      ),
    );
  }
}

// 圆形迷你封面；无曲目/无封面时回退为音乐图标
class _MiniCover extends StatelessWidget {
  const _MiniCover({this.cover});

  final PlaybackCover? cover;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final size = theme.spacing.xxl * 1.25;
    final bytes = cover?.bytes;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasArt
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  size: size * 0.5,
                  color: scheme.onSecondaryContainer,
                ),
              ),
      ),
    );
  }
}

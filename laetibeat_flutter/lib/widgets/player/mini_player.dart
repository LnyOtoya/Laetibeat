import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'cover_provider.dart';
import 'playback_panel.dart';
import 'player_provider.dart';

// 移动端全局迷你播放器：M3E floating toolbar + 封面 + 标题/艺术家 + 三个控制按钮
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 与播放页共用同一套封面取色作用域，封面变化时一起换色
    return PlaybackCoverScope(
      child: Builder(
        builder: (context) {
          final theme = M3ETheme.of(context);
          final track = ref.watch(playerProvider.select((s) => s.current));
          final isPlaying =
              ref.watch(playerProvider.select((s) => s.isPlaying));
          final cover = ref.watch(playbackCoverProvider).value;
          final notifier = ref.read(playerProvider.notifier);
          final hasTrack = track != null;
          final background = playbackPanelBackground(theme, cover);
          final foreground = cover == null
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSecondaryContainer;

          return M3EToolbar.floating(
            colorStyle: M3EToolbarColorStyle.standard,
            axis: Axis.horizontal,
            backgroundColor: background,
            foregroundColor: foreground,
            leading: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openPlayer(context),
              child: _MiniCover(cover: cover),
            ),
            title: _tappableTitle(
              context,
              track?.title ?? '暂无曲目',
            ),
            subtitle: _tappableTitle(
              context,
              track?.artist ?? '暂无艺术家',
            ),
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
        },
      ),
    );
  }

  // 标题/艺术家区域整行可点，点击上滑进入全屏播放页
  Widget _tappableTitle(BuildContext context, String text) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPlayer(context),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    Navigator.of(context).push(_playerRoute());
  }

  Route<void> _playerRoute() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PlaybackFullscreenPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
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

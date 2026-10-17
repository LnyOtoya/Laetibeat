import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../animations.dart';
import 'lyric_provider.dart';
import 'player_provider.dart';

/// 歌词渲染视图(可复用):供播放面板内联展示使用。
/// 加载态 / 无歌词 / 同步歌词(跟随进度高亮滚动) / 纯文本 四态。
/// 只负责"画歌词",不负责容器外壳与配色(由调用方提供)。
class LyricsView extends ConsumerWidget {
  const LyricsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final track = ref.watch(playerProvider.select((s) => s.current));
    if (track == null) {
      return _empty(theme, '未在播放', '从音乐库选择一首歌曲后查看歌词');
    }

    final lyricsAsync = ref.watch(lyricsProvider);
    return lyricsAsync.when(
      loading: () => const Center(
        child: M3EProgressIndicator.circular(semanticsLabel: '歌词加载中'),
      ),
      error: (e, _) => _empty(theme, '歌词加载失败', e.toString()),
      data: (lyrics) {
        final hasText = lyrics != null &&
            (lyrics.lines.isNotEmpty || lyrics.plainText.isNotEmpty);
        if (!hasText) {
          return _empty(theme, '暂无歌词', '当前曲目没有可显示的歌词');
        }
        if (!lyrics.isSynced) {
          return _plainLyrics(theme, lyrics.plainText);
        }
        return _SyncedLyrics(lines: lyrics.lines);
      },
    );
  }

  // 占位提示(居中,沿用全局配色)
  Widget _empty(M3EThemeData theme, String title, String subtitle) {
    final scheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lyrics_outlined,
            size: 64,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          SizedBox(height: theme.spacing.lg),
          Text(title, style: theme.typeScale.titleMedium),
          SizedBox(height: theme.spacing.xs),
          Text(
            subtitle,
            style: theme.typeScale.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 纯文本歌词:整段展示,可滚动
  Widget _plainLyrics(M3EThemeData theme, String text) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.xl,
        vertical: theme.spacing.lg,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.typeScale.bodyLarge.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.8,
        ),
      ),
    );
  }
}

/// 同步歌词:按播放进度高亮当前行,并自动居中滚动到可视区。
/// 持有 ScrollController,当前行变化时平滑滚动,不打断用户手动拖动。
class _SyncedLyrics extends ConsumerStatefulWidget {
  const _SyncedLyrics({required this.lines});

  final List<LyricLine> lines;

  @override
  ConsumerState<_SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends ConsumerState<_SyncedLyrics> {
  final ScrollController _controller = ScrollController();

  /// 只标记"当前高亮行"的 key:每帧把它挂到 active 行上,
  /// 帧后按该行真实渲染位置精确居中,避免固定行高估算累积误差导致漂移。
  final GlobalKey _activeKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final position = ref.watch(playerProvider.select((s) => s.position));

    // 当前行:最后一处带时间戳且 time <= position 的行
    var active = 0;
    for (var i = 0; i < widget.lines.length; i++) {
      final t = widget.lines[i].time;
      if (t != null && t <= position) active = i;
    }

    // 当前行变化时,平滑滚动让高亮行处于视口中部(用户已手动拖动则不打扰)
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealActive());

    return ListView.builder(
      controller: _controller,
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.xl,
        vertical: theme.spacing.xl,
      ),
      itemCount: widget.lines.length,
      itemBuilder: (context, i) {
        final line = widget.lines[i];
        final isActive = i == active;
        return AnimatedDefaultTextStyle(
          key: isActive ? _activeKey : null,
          duration: kSectionAnimDuration,
          style: (isActive
                  ? theme.typeScale.headlineSmall
                  : theme.typeScale.titleMedium)
              .copyWith(
                color: isActive ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
            child: Text(
              line.text,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  /// 把当前高亮行滚动到视口正中。用 viewport 的真实布局位置计算目标偏移,
  /// 而非以固定行高估算,避免长歌词逐行累积误差把当前行顶出屏幕。
  void _revealActive() {
    if (!_controller.hasClients) return;
    // 拖拽/滚动中不强制跳动,避免抢夺用户输入
    if (_controller.position.isScrollingNotifier.value) return;

    final ctx = _activeKey.currentContext;
    if (ctx == null) return; // 该行尚未布局(如大跨度 seek 未构建)
    final ro = ctx.findRenderObject();
    if (ro == null) return;

    final viewport = RenderAbstractViewport.of(ro);
    // alignment 0.5 = 目标对象居于视口正中
    final target = viewport.getOffsetToReveal(ro, 0.5).offset;
    _controller.jumpTo(
      target.clamp(0.0, _controller.position.maxScrollExtent),
    );
  }
}

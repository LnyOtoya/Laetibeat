import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import '../../animations.dart';
import '../settings/music_library_provider.dart';
import 'player_provider.dart';
import 'squish_button_row.dart';

//共享播放面板:三个区域(来源区/播放显示区/控制区)
//主页/搜索/音乐库右侧默认显示;全屏页复用同一面板
class PlaybackPanel extends ConsumerWidget {
  const PlaybackPanel({super.key, this.fullscreen = false});

  //是否处于全屏布局
  final bool fullscreen;

  /// 宽度低于该值进入紧凑布局(收拢次要控件,适配 Android 竖屏等窄屏)
  static const double _compactBreakpoint = 480.0;

  /// 竖直空间低于该值时(如矮窗口被下方播放队列压缩)退化为可滚动布局,
  /// 避免固定内容超出可用高度导致 RenderFlex 溢出
  static const double _tightHeight = 460.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final player = ref.watch(playerProvider);
    final track = player.current;

    //空态:未播放任何曲目时,按音乐库是否有曲目分两种占位提示
    if (track == null) return _emptyState(ref, theme, scheme);

    // 流式自适应:不再对整棵子树做 Transform.scale 光栅缩放(那是文字/圆角
    // 出现锯齿的根因)。窗口变化只靠 Flex 重新排版:封面用 Expanded+AspectRatio(1)
    // 永远保持正方形,高度余量被 Expanded 吸收;文字/图标/圆角始终原生像素渲染。
    return LayoutBuilder(
      builder: (context, c) {
        // 窄屏(如未来 Android 竖屏)进入紧凑模式:收拢次要控件
        final compact = c.maxWidth < _compactBreakpoint;
        final hPad = theme.spacing.xl;
        final vPad = theme.spacing.lg;

        // 竖直空间极小(矮窗口被下方队列压缩):退化为可滚动布局,保证不溢出
        if (c.maxHeight < _tightHeight) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sourceRegion(theme, scheme, player),
                SizedBox(height: theme.spacing.lg),
                // 封面保持正方形,但限制高度,避免滚动过长
                Center(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxHeight: c.maxHeight * 0.45),
                    child: AspectRatio(aspectRatio: 1, child: _cover(theme)),
                  ),
                ),
                SizedBox(height: theme.spacing.xxl),
                _infoRow(context, theme, track, compact: compact),
                SizedBox(height: theme.spacing.xxl),
                _controlRegion(theme, scheme, player, ref, compact: compact),
              ],
            ),
          );
        }

        // 常规流式填充布局:封面 Expanded 吸收所有高度余量,
        // AspectRatio(1) 保证正方形、不拉伸,文字/图标始终原生像素渲染
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sourceRegion(theme, scheme, player),
              // 来源距离封面: 间距稍小
              SizedBox(height: theme.spacing.lg),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _cover(theme),
                  ),
                ),
              ),
              // 信息行距离控制区: 间距稍大
              SizedBox(height: theme.spacing.xxl),
              _infoRow(context, theme, track, compact: compact),
              SizedBox(height: theme.spacing.xxl),
              _controlRegion(theme, scheme, player, ref, compact: compact),
            ],
          ),
        );
      },
    );
  }

  //空态占位:音乐库为空 => 引导扫描;有曲目未播放 => '未在播放'提示
  Widget _emptyState(
    WidgetRef ref,
    M3EThemeData theme,
    M3EColorScheme scheme,
  ) {
    final lib = ref.watch(musicLibraryProvider).value;
    final empty = lib == null || lib.tracks.isEmpty;
    final icon = empty ? Icons.music_off : Icons.play_circle_outline;
    final title = empty ? '音乐库为空' : '未在播放';
    final subtitle =
        empty ? '前往设置选择音乐文件夹,开始扫描' : '从音乐库选择一首歌曲开始播放';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 96, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
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

  //区域1:来源区 - 居中显示'正在播放' + 来源名
  Widget _sourceRegion(
    M3EThemeData theme,
    M3EColorScheme scheme,
    PlayerState player,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: Text(
            '正在播放',
            style: theme.typeScale.labelMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Align(
          alignment: Alignment.center,
          child: Text(player.source, style: theme.typeScale.titleSmall),
        ),
      ],
    );
  }

  //区域2:信息行 - 左(歌名/歌手)右(全屏/歌词),排在封面下方
  //紧凑模式下收起歌词入口,留出更多横向空间
  Widget _infoRow(
    BuildContext context,
    M3EThemeData theme,
    rust.UiTrack? track, {
    bool compact = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track?.title ?? '未在播放',
                style: theme.typeScale.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                track == null ? '' : '${track.artist} · ${track.album}',
                style: theme.typeScale.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        M3EIconButton(
          size: M3EIconButtonSize.md,
          icon: const Icon(Icons.fullscreen),
          tooltip: '全屏',
          onPressed: () => _openFullscreen(context),
        ),
        if (!compact)
          M3EIconButton(
            size: M3EIconButtonSize.md,
            icon: const Icon(Icons.lyrics),
            tooltip: '歌词',
            onPressed: () {}, //歌词逻辑未接入
          ),
      ],
    );
  }

  //封面:自控圆角(比M3EShapeContainer.square默认radius更小),图标按边长比例
  Widget _cover(M3EThemeData theme) {
    final scheme = theme.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.spacing.md),
      child: ColoredBox(
        color: scheme.secondaryContainer,
        child: LayoutBuilder(
          builder: (context, c) => Center(
            child: Icon(M3EIcons.music_note, size: c.maxWidth * 0.4),
          ),
        ),
      ),
    );
  }

  //区域3:控制区 - 进度条+时长 / 上一首播放暂停下一首 / 底部按钮组+菜单
  //紧凑模式下隐藏底部次要按钮行(播放列表/随机/顺序),收进三点菜单
  Widget _controlRegion(
    M3EThemeData theme,
    M3EColorScheme scheme,
    PlayerState player,
    WidgetRef ref, {
    bool compact = false,
  }) {
    final total = player.duration.inMilliseconds;
    final value = total > 0
        ? (player.position.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;
    final notifier = ref.read(playerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        //拖拽进度条:播放时wavy曲线,暂停/未播放时为直线continuous
        if (player.isPlaying)
          M3ESlider.wavy(
            value: value,
            trackThickness: 10,
            onChanged: (v) =>
                notifier.seek(Duration(milliseconds: (v * total).round())),
          )
        else
          M3ESlider(
            value: value,
            trackThickness: 10,
            onChanged: (v) =>
                notifier.seek(Duration(milliseconds: (v * total).round())),
          ),
        //时长
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(player.position), style: theme.typeScale.labelSmall),
            Text(_fmt(player.duration), style: theme.typeScale.labelSmall),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        //上一首 / 播放暂停 / 下一首 - 横向内边距已由全页统一 Padding 提供
        //复刻 neighbor-squish 效果;内部用 FittedBox 兜底窄屏不横向溢出
        SquishButtonRow(
          isPlaying: player.isPlaying,
          previousEnabled: player.queue.isNotEmpty,
          toggleEnabled: player.current != null,
          nextEnabled: player.queue.isNotEmpty,
          onPrevious: notifier.prev,
          onToggle: notifier.toggle,
          onNext: notifier.next,
        ),
        SizedBox(height: theme.spacing.md),
        //底部:左侧按钮组(播放列表/随机/顺序) + 右侧三点菜单
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!compact)
              Row(
                children: [
                  M3EIconButton(
                    size: M3EIconButtonSize.sm,
                    icon: const Icon(Icons.playlist_play),
                    tooltip: '播放列表',
                    onPressed: () {},
                  ),
                  M3EIconButton(
                    size: M3EIconButtonSize.sm,
                    icon: const Icon(Icons.shuffle),
                    tooltip: '随机播放',
                    onPressed: () {},
                  ),
                  M3EIconButton(
                    size: M3EIconButtonSize.sm,
                    icon: const Icon(Icons.repeat),
                    tooltip: '顺序播放',
                    onPressed: () {},
                  ),
                ],
              )
            else
              const SizedBox.shrink(),
            _moreMenu(),
          ],
        ),
      ],
    );
  }

  //竖向三点菜单
  Widget _moreMenu() {
    return M3EMenu.entries(
      position: M3EMenuAnchorPosition.bottomEnd,
      entries: const [
        M3EMenuEntry(label: '添加到播放队列'),
        M3EMenuEntry(label: '查看歌词'),
      ],
      anchorBuilder: (context, open) => M3EIconButton(
        size: M3EIconButtonSize.sm,
        icon: const Icon(Icons.more_vert),
        tooltip: '更多',
        onPressed: open,
      ),
    );
  }

  //打开全屏播放页(全局路由,关闭回到进入前视图)
  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlaybackFullscreenPage()),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

//全屏播放页:复用PlaybackPanel,整体覆盖当前页
class PlaybackFullscreenPage extends StatelessWidget {
  const PlaybackFullscreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.xxl),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: M3EIconButton(
                  size: M3EIconButtonSize.md,
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: AnimatedSwitcher(
                      duration: kSectionAnimDuration,
                      switchInCurve: kSectionAnimCurve,
                      switchOutCurve: kSectionAnimCurve,
                      child: const PlaybackPanel(fullscreen: true),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
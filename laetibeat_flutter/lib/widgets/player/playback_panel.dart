import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import '../../animations.dart';
import '../settings/music_library_provider.dart';
import 'player_provider.dart';

//共享播放面板:三个区域(来源区/播放显示区/控制区)
//主页/搜索/音乐库右侧默认显示;全屏页复用同一面板
class PlaybackPanel extends ConsumerWidget {
  const PlaybackPanel({super.key, this.fullscreen = false});

  //是否处于全屏布局
  final bool fullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final player = ref.watch(playerProvider);
    final track = player.current;

    //空态:未播放任何曲目时,按音乐库是否有曲目分两种占位提示
    if (track == null) return _emptyState(ref, theme, scheme);

    //整体等比缩放:高度方向随窗口自适应,宽度抵消scale后始终占满窗口
    //所有控件(文字/按钮/间距/封面)都随窗口高度一起变大变小
    const baseH = 720.0;
    return LayoutBuilder(
      builder: (context, c) {
        final scale = c.maxHeight / baseH;
        return ClipRect(
          child: Align(
            alignment: Alignment.center,
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: c.maxWidth / scale,
                height: baseH,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sourceRegion(theme, scheme, player),
                    SizedBox(height: theme.spacing.lg),
                    Expanded(child: _displayRegion(context, theme, track)),
                    SizedBox(height: theme.spacing.lg),
                    _controlRegion(theme, scheme, player, ref),
                  ],
                ),
              ),
            ),
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

  //区域2:播放显示区 - 封面铺满宽度 + 左(歌名/歌手)右(全屏/歌词)
  Widget _displayRegion(
    BuildContext context,
    M3EThemeData theme,
    rust.UiTrack? track,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        //封面按内容区宽度铺满(正方形,高度不足时整体缩放),贴住下方信息行
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Align(
              alignment: Alignment.bottomCenter,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: c.maxWidth,
                  height: c.maxWidth,
                  child: _cover(theme),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        Row(
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
            M3EIconButton(
              size: M3EIconButtonSize.md,
              icon: const Icon(Icons.lyrics),
              tooltip: '歌词',
              onPressed: () {}, //歌词逻辑未接入
            ),
          ],
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
  Widget _controlRegion(
    M3EThemeData theme,
    M3EColorScheme scheme,
    PlayerState player,
    WidgetRef ref,
  ) {
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
        //上一首 / 播放暂停 / 下一首 - 按钮组左右留白,整体缩窄居中
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.xl),
          child: LayoutBuilder(
          builder: (context, c) {
            final spacing = theme.spacing.xs;
            final btnW = (c.maxWidth - spacing * 2) / 3;
            return M3EButtonGroup(
              type: M3EButtonGroupType.standard,
              shape: M3EButtonShape.round,
              size: M3EButtonSize.md,
              style: M3EButtonStyle.filled,
              neighborSquish: true,
              spacing: spacing,
              selectedIndex: player.isPlaying ? 1 : null,
              onSelectedIndexChanged: (i) {
                //按钮组点已选项是取消选中,回调null;播放中只有中间选中,视为点暂停
                if (i == null) {
                  notifier.toggle();
                  return;
                }
                switch (i) {
                  case 0:
                    notifier.prev();
                    break;
                  case 1:
                    notifier.toggle();
                    break;
                  case 2:
                    notifier.next();
                    break;
                }
              },
              actions: [
                M3EButtonGroupAction(
                  icon: const Icon(Icons.skip_previous),
                  tooltip: '上一首',
                  enabled: player.queue.isNotEmpty,
                  width: btnW,
                ),
                M3EButtonGroupAction(
                  icon: const Icon(Icons.play_arrow),
                  selectedIcon: const Icon(Icons.pause),
                  tooltip: player.isPlaying ? '暂停' : '播放',
                  enabled: player.current != null,
                  width: btnW,
                ),
                M3EButtonGroupAction(
                  icon: const Icon(Icons.skip_next),
                  tooltip: '下一首',
                  enabled: player.queue.isNotEmpty,
                  width: btnW,
                ),
              ],
            );
          },
          ),
        ),
        SizedBox(height: theme.spacing.md),
        //底部:左侧按钮组(播放列表/随机/顺序) + 右侧三点菜单
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
            ),
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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import '../../animations.dart';
import '../settings/music_library_provider.dart';
import 'cover_provider.dart';
import 'player_provider.dart';
import 'squish_button_row.dart';
import 'lyrics_view.dart';

//共享播放面板:三个区域(来源区/播放显示区/控制区)
//主页/搜索/音乐库右侧默认显示;全屏页复用同一面板
class PlaybackPanel extends ConsumerStatefulWidget {
  const PlaybackPanel({super.key, this.fullscreen = false});

  //是否处于全屏布局
  final bool fullscreen;

  @override
  ConsumerState<PlaybackPanel> createState() => _PlaybackPanelState();
}

class _PlaybackPanelState extends ConsumerState<PlaybackPanel> {
  /// 宽度低于该值进入紧凑布局(收拢次要控件,适配 Android 竖屏等窄屏)
  static const double _compactBreakpoint = 480.0;

  /// 竖直空间低于该值时(如矮窗口被下方播放队列压缩)退化为可滚动布局,
  /// 避免固定内容超出可用高度导致 RenderFlex 溢出
  static const double _tightHeight = 460.0;

  /// 是否在面板内切换显示歌词。默认 false = 显示封面(播放页);
  /// 按歌词按钮切换为歌词区,再按切回封面。不进入全屏,全屏方案另做。
  bool _showLyrics = false;

  /// 歌词沉浸模式:仅歌词页生效。隐藏底部控制区(上一曲/播放/下一曲、
  /// 循环顺序栏、底部按钮),把释放的高度让给歌词。与全屏播放页状态无关。
  bool _lyricsImmersive = false;

  /// 是否显示播放队列浮层。浮层只覆盖播放面板自身,不弹到窗口底部。
  bool _showQueue = false;

  /// 拖动进度条时的临时值(0..1)。拖动期间只更新本地显示,
  /// 松手后才向引擎 seek,避免远端流被连续 seek 打断。
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final baseTheme = M3ETheme.of(context);
    final player = ref.watch(playerProvider);
    final track = player.current;

    // 切歌时丢弃尚未结束的拖动状态,避免新曲目沿用旧进度
    ref.listen(playerProvider.select((s) => s.current?.id), (prev, next) {
      if (prev != next) _dragValue = null;
    });

    //空态:未播放任何曲目时,按音乐库是否有曲目分两种占位提示(保持全局配色)
    if (track == null) return _emptyState(ref, baseTheme, baseTheme.colorScheme);

    // 播放页封面取色:仅本页用封面主色派生 ColorScheme 覆盖全局配色,
    // 其余页面保持原有壁纸/主题取色不变。无封面时保持默认配色。
    final coverInfo = ref.watch(playbackCoverProvider).value;
    final scopedTheme = coverInfo == null
        ? baseTheme
        : baseTheme.withColorScheme(
            M3EColorScheme.fromSeed(
              coverInfo.coverColor,
              brightness: baseTheme.colorScheme.brightness,
            ),
          );

    // 用 M3ETheme 本地覆盖 ColorScheme,使子树里所有 M3E 组件都吃到封面配色;
    // 在 Builder 内重读 theme,让文字/图标/组件统一走封面派生配色。
    return M3ETheme(
      data: scopedTheme,
      child: Builder(
        builder: (inner) {
          final theme = M3ETheme.of(inner);
          final scheme = theme.colorScheme;
          final bytes = coverInfo?.bytes;

          // 流式自适应:不再对整棵子树做 Transform.scale 光栅缩放(那是文字/圆角
          // 出现锯齿的根因)。窗口变化只靠 Flex 重新排版:封面用 Expanded+AspectRatio(1)
          // 永远保持正方形,高度余量被 Expanded 吸收;文字/图标/圆角始终原生像素渲染。
          return LayoutBuilder(
            builder: (context, c) {
              // 窄屏(如 Android 竖屏)进入紧凑模式:收紧留白,把空间让给封面
              final compact = c.maxWidth < _compactBreakpoint;
              final hPad = compact ? theme.spacing.lg : theme.spacing.xl;
              final vPad = compact ? theme.spacing.md : theme.spacing.lg;

              // 面板主体:矮窗口退化为可滚动,否则用 Expanded 流式填充
              Widget body() {
                // 竖直空间极小(矮窗口被下方队列压缩):退化为可滚动布局,保证不溢出
                if (c.maxHeight < _tightHeight) {
                  return SingleChildScrollView(
                    padding:
                        EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sourceArea(
                          theme,
                          scheme,
                          player,
                          bottomGap:
                              compact ? theme.spacing.sm : theme.spacing.lg,
                        ),
                        // 封面/歌词区:封面向上滑出淡出,歌词平滑进入(反向亦然)。
                        // 歌词态同时放大可用高度,把来源区收起释放的空间让给歌词;
                        // 沉浸模式下底部控件再收起,歌词进一步扩展。
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0.45,
                            end: _lyricsImmersive
                                ? 0.82
                                : (_showLyrics ? 0.65 : 0.45),
                          ),
                          duration: kSectionAnimDuration,
                          curve: kSectionAnimCurve,
                          builder: (context, factor, child) => ConstrainedBox(
                            constraints:
                                BoxConstraints(maxHeight: c.maxHeight * factor),
                            child: child,
                          ),
                          child: _mainArea(theme, bytes),
                        ),
                        SizedBox(
                          height: compact
                              ? theme.spacing.lg
                              : theme.spacing.xxl,
                        ),
                        _infoRow(context, theme, track, bytes),
                        SizedBox(
                          height: compact
                              ? theme.spacing.lg
                              : theme.spacing.xxl,
                        ),
                        _controlRegion(context, theme, scheme, player, ref,
                            compact: compact),
                      ],
                    ),
                  );
                }

                // 常规流式填充布局:封面 Expanded 吸收所有高度余量,
                // AspectRatio(1) 保证正方形、不拉伸,文字/图标始终原生像素渲染
                return Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 来源区顶部留缝;窄屏收紧,让来源文字上移、封面获得更多空间
                      _sourceArea(
                        theme,
                        scheme,
                        player,
                        topGap: compact
                            ? theme.spacing.sm
                            : theme.spacing.xl,
                        bottomGap: compact
                            ? theme.spacing.sm
                            : theme.spacing.lg,
                      ),
                      Expanded(child: _mainArea(theme, bytes)),
                      // 信息行距离控制区: 间距稍大
                      SizedBox(
                        height:
                            compact ? theme.spacing.lg : theme.spacing.xxl,
                      ),
                      _infoRow(context, theme, track, bytes),
                      SizedBox(
                        height:
                            compact ? theme.spacing.lg : theme.spacing.xxl,
                      ),
                      _controlRegion(context, theme, scheme, player, ref,
                          compact: compact),
                    ],
                  ),
                );
              }

              final content = body();

              // 队列浮层只覆盖播放面板自身(右侧播放区或全屏面板),
              // 不弹到整个窗口底部。
              return Stack(
                fit: StackFit.expand,
                children: [
                  content,
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: M3EDimensions.borderRadiusMedium,
                      child: AnimatedSwitcher(
                        duration: kSectionAnimDuration,
                        switchInCurve: kSectionAnimCurve,
                        switchOutCurve: kSectionAnimCurve,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.06),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _showQueue
                            ? _queueOverlay(theme, scheme, player)
                            : const SizedBox.shrink(
                                key: ValueKey('queue-closed'),
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
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

  // 来源区外壳:歌词态整体收起(高度+透明度同步收缩),把纵向空间让给歌词。
  // 默认态显示"正在播放"与来源名;收起用 Align.heightFactor + ClipRect,
  // 固定尺寸内容不会被压缩变形。
  Widget _sourceArea(
    M3EThemeData theme,
    M3EColorScheme scheme,
    PlayerState player, {
    double topGap = 0,
    double? bottomGap,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: _showLyrics ? 0 : 1),
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      builder: (context, t, child) {
        if (t == 0) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: Opacity(opacity: t, child: child),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topGap > 0) SizedBox(height: topGap),
          _sourceRegion(theme, scheme, player),
          SizedBox(height: bottomGap ?? theme.spacing.lg),
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
            style: theme.typeScale.labelLarge.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Align(
          alignment: Alignment.center,
          child: Text(player.source, style: theme.typeScale.titleLarge),
        ),
      ],
    );
  }

  // 主内容区:大封面与歌词共用同一块区域,切换时封面向上滑出淡出、
  // 歌词淡入;反向切换时动画自动倒放。两者用同一时长/曲线保持节奏一致。
  Widget _mainArea(M3EThemeData theme, Uint8List? bytes) {
    final duration = kSectionAnimDuration;
    final curve = kSectionAnimCurve;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      transitionBuilder: (child, animation) {
        final isLyrics = child.key == const ValueKey('lyrics');
        // 歌词:从下方轻微上移并淡入;封面:上滑并淡出。
        // AnimatedSwitcher 对退出方使用倒放动画,所以封面 tween 写成
        // begin=上移、end=原位,退出时正好从原位滑向上方。
        final begin = isLyrics ? const Offset(0, 0.05) : const Offset(0, -0.18);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        );
      },
      child: _showLyrics
          ? const LyricsView(key: ValueKey('lyrics'))
          : Center(
              key: const ValueKey('cover'),
              child: AspectRatio(
                aspectRatio: 1,
                child: _cover(theme, bytes: bytes),
              ),
            ),
    );
  }

  //区域2:信息行 - 左(歌名/歌手)右(全屏/歌词),排在封面下方
  Widget _infoRow(
    BuildContext context,
    M3EThemeData theme,
    rust.UiTrack? track,
    Uint8List? bytes,
  ) {
    final showCover = _showLyrics;
    const double coverSize = 44;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              // 歌词态小封面:宽度从 0 平滑展开,图片随后淡入并轻微放大。
              // 用 ClipRect 揭示固定尺寸的图片,避免宽度动画把封面横向压扁。
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: showCover ? 1 : 0),
                duration: kSectionAnimDuration,
                curve: kSectionAnimCurve,
                builder: (context, t, _) {
                  if (t == 0) return const SizedBox.shrink();
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: t,
                      child: SizedBox(
                        width: coverSize + theme.spacing.md,
                        height: coverSize,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Opacity(
                            opacity: t,
                            child: Transform.scale(
                              scale: 0.88 + 0.12 * t,
                              child: SizedBox(
                                width: coverSize,
                                height: coverSize,
                                child: _cover(
                                  theme,
                                  bytes: bytes,
                                  radius: theme.spacing.sm,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track?.title ?? '未在播放',
                      style: theme.typeScale.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      track == null ? '' : '${track.artist} · ${track.album}',
                      style: theme.typeScale.bodyLarge.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
        M3EButtonGroup(
          type: M3EButtonGroupType.connected,
          direction: Axis.horizontal,
          shape: M3EButtonShape.round,
          size: M3EButtonSize.md,
          style: M3EButtonStyle.filled,
          neighborSquish: true,
          expandedRatio: 0.15,
          // 不更新 selectedIndex: 每个格保持未选中渲染,
          // 仅用点击回调做瞬时命令(全屏/歌词),不会恒亮
          onSelectedIndexChanged: (idx) {
            if (idx == 0) {
              if (_showLyrics) {
                // 歌词页:全屏按钮 = 歌词沉浸模式开关(不进入全屏页)
                setState(() => _lyricsImmersive = !_lyricsImmersive);
              } else if (widget.fullscreen) {
                // 已经处于全屏播放页:直接退出,避免重复 push
                Navigator.of(context).maybePop();
              } else {
                // 播放页(封面):进入全屏播放页
                _openFullscreen(context);
              }
            }
            if (idx == 1) {
              // 歌词按钮:在面板内切换封面/歌词,不进入全屏
              setState(() {
                _showLyrics = !_showLyrics;
                // 返回普通播放页时退出沉浸模式,避免隐藏状态残留
                if (!_showLyrics) _lyricsImmersive = false;
              });
            }
          },
          actions: [
            M3EButtonGroupAction(
              icon: Icon(
                widget.fullscreen && !_showLyrics
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
              ),
              semanticLabel: widget.fullscreen && !_showLyrics ? '退出全屏' : '全屏',
              tooltip: widget.fullscreen && !_showLyrics ? '退出全屏' : '全屏',
            ),
            const M3EButtonGroupAction(
              icon: Icon(Icons.lyrics),
              semanticLabel: '歌词',
              tooltip: '歌词',
            ),
          ],
        ),
      ],
    );
  }

  //封面:自控圆角(比M3EShapeContainer.square默认radius更小)。
  //有封面字节则铺满显示 Image.memory,无封面回退占位音符图标(按边长比例)
  Widget _cover(M3EThemeData theme, {Uint8List? bytes, double? radius}) {
    final scheme = theme.colorScheme;
    final hasArt = bytes != null && bytes.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? theme.spacing.md),
      child: ColoredBox(
        color: scheme.secondaryContainer,
        child: hasArt
            ? Image.memory(
                bytes,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
              )
            : LayoutBuilder(
                builder: (context, c) => Center(
                  child: Icon(
                    M3EIcons.music_note,
                    size: c.maxWidth * 0.4,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
      ),
    );
  }

  //区域3:控制区 - 进度条+时长 / 上一首播放暂停下一首 / 底部按钮组+菜单
  //紧凑模式下隐藏底部次要按钮行(播放列表/随机/顺序),收进三点菜单
  Widget _controlRegion(
    BuildContext context,
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
    // 拖动中优先展示拖动位置,松手后再回到引擎真实进度
    final sliderValue = _dragValue ?? value;
    final displayPosition = _dragValue == null
        ? player.position
        : Duration(milliseconds: (_dragValue! * total).round());
    final notifier = ref.read(playerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        //拖拽进度条:播放时wavy曲线,暂停/未播放时为直线continuous
        if (player.isPlaying)
          M3ESlider.wavy(
            value: sliderValue,
            trackThickness: 12,
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) => _commitSeek(notifier, v, total),
          )
        else
          M3ESlider(
            value: sliderValue,
            trackThickness: 12,
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) => _commitSeek(notifier, v, total),
          ),
        //时长
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(displayPosition), style: theme.typeScale.labelMedium),
            Text(_fmt(player.duration), style: theme.typeScale.labelMedium),
          ],
        ),
        // 沉浸模式下,以下三块(切歌 / 循环顺序 / 底部按钮)整体向下滑出
        // 并收起布局高度,释放的空间交给上方歌词区。
        _collapsibleControls(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              //第一行:随机 / 重复(单曲-列表循环切换) / 添加到歌单(仅图标,逻辑未接入)
              //受控 multiSelect 表达: selectedIndices 含 0=随机开, 含 1=循环开;
              //中间按钮 icon 依 repeatMode 动态切换(repeat_one=单曲, repeat=列表)
              Center(
                // ConstrainedBox 让 connected 组不铺满表面,而收缩到固定宽度
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Container(
                    padding: EdgeInsets.all(theme.spacing.sm),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      // 超大圆角值:左右两侧呈完美半圆(胶囊形)
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: M3EButtonGroup(
                      type: M3EButtonGroupType.connected,
                      direction: Axis.horizontal,
                      shape: M3EButtonShape.round,
                      size: M3EButtonSize.md,
                      style: M3EButtonStyle.tonal,
                      density: M3EButtonGroupDensity.regular,
                      neighborSquish: false,
                      overflow: M3EButtonGroupOverflow.scroll,
                      // overflow: M3EButtonGroupOverflow.experimentalPaging,
                      haptic: M3EHapticFeedback.light,
                      selectionRequired: false,
                      multiSelect: true,
                      selectedIndices: {
                        if (player.shuffle) 0,
                        if (player.repeatMode != PlaybackRepeatMode.off) 1,
                      },
                      onSelectedIndicesChanged: (indices) {
                        //动作1: 随机开关
                        if (indices.contains(0) != player.shuffle) {
                          notifier.toggleShuffle();
                        }
                        //动作2: 重复模式轮换(每次点击都轮换,不管是否已在选中)
                        if (indices.contains(1) !=
                            (player.repeatMode != PlaybackRepeatMode.off)) {
                          notifier.cycleRepeat();
                        }
                        //动作3: 添加到歌单 - 仅图标,暂无逻辑
                      },
                      actions: [
                        M3EButtonGroupAction(
                          icon: const Icon(Icons.shuffle),
                          selectedIcon: const Icon(Icons.shuffle),
                          // label 缺省即纯 icon
                          semanticLabel: '随机播放',
                          tooltip: '随机播放',
                        ),
                        M3EButtonGroupAction(
                          icon: Icon(
                            player.repeatMode == PlaybackRepeatMode.single
                                ? Icons.repeat_one
                                : Icons.repeat,
                          ),
                          selectedIcon: Icon(
                            player.repeatMode == PlaybackRepeatMode.single
                                ? Icons.repeat_one
                                : Icons.repeat,
                          ),
                          // label 缺省即纯 icon
                          semanticLabel: '重复',
                          tooltip: '重复',
                        ),
                        const M3EButtonGroupAction(
                          icon: Icon(Icons.playlist_add),
                          // label 缺省即纯 icon
                          semanticLabel: '添加到歌单',
                          tooltip: '添加到歌单',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: theme.spacing.md),
              //第二行:左侧播放队列 + 右侧三点菜单(均文字+图标, sm 方形规格)
              //队列按钮不做 compact 隐藏,小窗口也始终保留(入口固定可见)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  M3EButton(
                    size: M3EButtonSize.sm,
                    icon: const Icon(Icons.playlist_play),
                    label: const Text('队列'),
                    style: M3EButtonStyle.filled,
                    shape: M3EButtonShape.square,
                    onPressed: () => setState(() => _showQueue = !_showQueue),
                  ),
                  _moreMenu(context),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 歌词沉浸模式:把底部三块控件整体向下滑出并收起布局高度。
  /// 用 Align.heightFactor 收缩高度(随 Column 重排向下移动),
  /// ClipRect 剪裁溢出,因此既能下滑又真正释放空间
  /// (不是仅用 Transform 把控件绘到屏幕外、仍占着原来的空白)。
  Widget _collapsibleControls(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: _lyricsImmersive ? 0 : 1),
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      builder: (context, t, child) {
        if (t == 0) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // -------------------------------------------------------------------------
  // 播放队列浮层
  // -------------------------------------------------------------------------

  /// 面板内遮罩 + 底部队列卡片。覆盖范围就是当前播放面板,
  /// 不会像 showModalBottomSheet 那样弹到整个窗口底部。
  Widget _queueOverlay(
    M3EThemeData theme,
    M3EColorScheme scheme,
    PlayerState player,
  ) {
    return GestureDetector(
      key: const ValueKey('queue-open'),
      behavior: HitTestBehavior.opaque,
      onTap: _closeQueue,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 面板内遮罩
          ColoredBox(color: scheme.scrim.withValues(alpha: 0.22)),
          // 底部浮层:高度约占面板 2/3,四周留出与面板一致的内边距
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // 点卡片空白处不冒泡到遮罩,避免误关闭
              onTap: () {},
              child: FractionallySizedBox(
                heightFactor: 0.68,
                widthFactor: 1,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    theme.spacing.md,
                    0,
                    theme.spacing.md,
                    theme.spacing.md,
                  ),
                  child: _queueSheet(theme, scheme, player),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _queueSheet(
    M3EThemeData theme,
    M3EColorScheme scheme,
    PlayerState player,
  ) {
    final queue = player.queue;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(theme.spacing.lg),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          theme.spacing.lg,
          theme.spacing.md,
          theme.spacing.md,
          theme.spacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题行:标题 + 数量 + 关闭
            Row(
              children: [
                Expanded(
                  child: Text('播放队列', style: theme.typeScale.titleLarge),
                ),
                Text(
                  '${queue.length} 首',
                  style: theme.typeScale.labelMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                M3EIconButton(
                  size: M3EIconButtonSize.xs,
                  icon: const Icon(Icons.close),
                  tooltip: '关闭队列',
                  onPressed: _closeQueue,
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.queue_music,
                            size: 40,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          SizedBox(height: theme.spacing.sm),
                          Text('队列为空', style: theme.typeScale.titleMedium),
                          SizedBox(height: theme.spacing.xs),
                          Text(
                            '从音乐库选择歌曲开始播放',
                            style: theme.typeScale.bodyMedium.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : M3EList.scrollable(
                      itemCount: queue.length,
                      onTap: (i) {
                        ref.read(playerProvider.notifier).play(i);
                        _closeQueue();
                      },
                      itemBuilder: (context, i) {
                        final track = queue[i];
                        final selected = i == player.currentIndex;
                        return M3EListItem(
                          selected: selected,
                          leading: Icon(
                            selected
                                ? (player.isPlaying
                                    ? Icons.graphic_eq
                                    : Icons.pause_circle_outline)
                                : Icons.music_note,
                            size: 20,
                            color: selected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          headline: track.title,
                          supportingText: track.artist,
                          trailingText: track.duration,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _closeQueue() {
    if (_showQueue) {
      setState(() => _showQueue = false);
    }
  }

  //竖向三点菜单
  Widget _moreMenu(BuildContext context) {
    return M3EMenu.entries(
      position: M3EMenuAnchorPosition.bottomEnd,
      entries: [
        const M3EMenuEntry(label: '添加到播放队列'),
        M3EMenuEntry(
          label: _showLyrics ? '收起歌词' : '查看歌词',
          onPressed: () => setState(() {
            _showLyrics = !_showLyrics;
            // 收起歌词即返回普通播放页,同步退出沉浸模式
            if (!_showLyrics) _lyricsImmersive = false;
          }),
        ),
      ],
      anchorBuilder: (context, open) => M3EButton(
        size: M3EButtonSize.sm,
        icon: const Icon(Icons.more_vert),
        label: const Text('更多'),
        style: M3EButtonStyle.filled,
        shape: M3EButtonShape.square,
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

  /// 松手后才真正 seek;拖动过程中只改本地显示值
  void _commitSeek(PlayerNotifier notifier, double value, int totalMs) {
    // 以本地拖动值为准,避免拖拽最后一帧的回调值尚未同步
    final target = _dragValue ?? value;
    setState(() => _dragValue = null);
    notifier.seek(Duration(milliseconds: (target * totalMs).round()));
  }

  static String _fmt(Duration d) {
    final totalMinutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (totalMinutes < 60) {
      return '${totalMinutes.toString().padLeft(2, '0')}:$seconds';
    }
    final hours = totalMinutes ~/ 60;
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

//全屏播放页:复用PlaybackPanel,整体覆盖当前页
class PlaybackFullscreenPage extends ConsumerWidget {
  const PlaybackFullscreenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    //封面取色作用域包住整页:Scaffold 底色也随封面带色(secondaryContainer)
    return PlaybackCoverScope(
      child: Builder(
        builder: (inner) {
          final theme = M3ETheme.of(inner);
          final coverInfo = ref.watch(playbackCoverProvider).value;
          final background = playbackPanelBackground(theme, coverInfo);

          // 移动端:不显示左上角退出按钮,播放面板直接占满安全区
          if (isMobile) {
            return Scaffold(
              backgroundColor: background,
              body: SafeArea(
                child: PlaybackPanel(fullscreen: true),
              ),
            );
          }

          // 桌面端保持原有居中布局和关闭按钮
          return Scaffold(
            backgroundColor: background,
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
        },
      ),
    );
  }
}

//播放页封面取色作用域:把封面主色派生的 ColorScheme 注入子树,让"外层容器
//(侧栏播放区外壳/全屏页 Scaffold)与播放面板"共用同一套封面配色。
//内部用 M3ETheme 本地覆盖,子树里的 M3E 组件统一走封面配色。
//无封面(未播放/无内嵌图)时保持全局配色,背景回退 surface。
class PlaybackCoverScope extends ConsumerWidget {
  const PlaybackCoverScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseTheme = M3ETheme.of(context);
    final coverInfo = ref.watch(playbackCoverProvider).value;
    final scopedTheme = coverInfo == null
        ? baseTheme
        : baseTheme.withColorScheme(
            M3EColorScheme.fromSeed(
              coverInfo.coverColor,
              brightness: baseTheme.colorScheme.brightness,
            ),
          );
    return M3ETheme(data: scopedTheme, child: child);
  }
}

/// 播放页"反其道"带色背景:有封面时用 secondaryContainer(柔和明显的封面色相),
/// 无封面回退 surface。供外层容器读取。
Color playbackPanelBackground(M3EThemeData theme, PlaybackCover? coverInfo) {
  return coverInfo == null
      ? theme.colorScheme.surface
      : theme.colorScheme.secondaryContainer;
}
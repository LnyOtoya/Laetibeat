import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../../../animations.dart';
import '../../../widgets/player/cover_provider.dart';
import '../../../widgets/player/playback_panel.dart';
import 'desktop_playback_page.dart';
import 'device_panel.dart';

//右侧内容区复用外壳:默认播放面板,点击左侧进入本页详情
//状态(播放页/详情)由此组件内部管理,页面用GlobalKey<PlayerRightPaneState>触发
//三个首页各自持有一个实例,互不影响;都读同一playerProvider故播放内容互通
class PlayerRightPane extends ConsumerStatefulWidget {
  const PlayerRightPane({super.key});

  @override
  PlayerRightPaneState createState() => PlayerRightPaneState();
}

class PlayerRightPaneState extends ConsumerState<PlayerRightPane> {
  Widget? _detail;

  //是否正在显示详情(而非默认播放面板)
  bool get showingDetail => _detail != null;

  //左侧点击某内容时,切入对应的详情组件
  void openDetail(Widget detail) => setState(() => _detail = detail);

  //状态按钮:切回播放面板
  void showPlayer() => setState(() => _detail = null);

  @override
  Widget build(BuildContext context) {
    //右侧内容区仿左侧“多层 section 叠放”:拆成两块独立表面容器
    //上=播放面板(或某内容详情),下=播放队列,中间留缝,互不共用一个外壳
    //封面取色作用域包住上容器,让外壳与播放面板共用封面配色(带色背景)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        //上容器: 播放面板 / 详情
        Expanded(
          child: PlaybackCoverScope(
            child: Builder(
              builder: (context) {
                final innerTheme = M3ETheme.of(context);
                final coverInfo =
                    ref.watch(playbackCoverProvider).value;
                return AnimatedContainer(
                  duration: kSectionAnimDuration,
                  curve: kSectionAnimCurve,
                  decoration: BoxDecoration(
                    // 反其道:播放中带封面时,底色用 secondaryContainer 带封面色相
                    color: playbackPanelBackground(innerTheme, coverInfo),
                    borderRadius: M3EDimensions.borderRadiusMedium,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(innerTheme.spacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        //详情态顶部状态按钮:一段时点按回到播放面板
                        if (_detail != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: M3EIconButton(
                              size: M3EIconButtonSize.sm,
                              icon: const Icon(Icons.fullscreen_exit),
                              tooltip: '返回播放页',
                              onPressed: showPlayer,
                            ),
                          ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: kSectionAnimDuration,
                            switchInCurve: kSectionAnimCurve,
                            switchOutCurve: kSectionAnimCurve,
                            child: KeyedSubtree(
                              key: ValueKey(_detail != null),
                              child: _detail ??
                                  PlaybackPanel(
                                    onOpenFullscreen: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const DesktopPlaybackPage(),
                                        ),
                                      );
                                    },
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: M3ETheme.of(context).spacing.md),
        //下容器: 设备/输出面板,自带表面
        const DevicePanel(),
      ],
    );
  }
}
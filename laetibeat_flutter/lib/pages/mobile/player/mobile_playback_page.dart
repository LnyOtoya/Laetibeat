import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../widgets/player/cover_provider.dart';
import '../../../widgets/player/playback_panel.dart';

/// 移动端全屏播放页。只负责页面外壳，播放面板本身是共享展示核心。
class MobilePlaybackPage extends ConsumerWidget {
  const MobilePlaybackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaybackCoverScope(
      child: Builder(
        builder: (inner) {
          final theme = M3ETheme.of(inner);
          final coverInfo = ref.watch(playbackCoverProvider).value;
          return Scaffold(
            backgroundColor: playbackPanelBackground(theme, coverInfo),
            body: SafeArea(child: PlaybackPanel(fullscreen: true)),
          );
        },
      ),
    );
  }
}

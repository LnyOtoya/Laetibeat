import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../widgets/player/cover_provider.dart';
import '../../../widgets/player/playback_panel.dart';

/// 桌面端全屏播放页：居中限宽 + 左上角关闭按钮。
class DesktopPlaybackPage extends ConsumerWidget {
  const DesktopPlaybackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaybackCoverScope(
      child: Builder(
        builder: (inner) {
          final theme = M3ETheme.of(inner);
          final coverInfo = ref.watch(playbackCoverProvider).value;
          return Scaffold(
            backgroundColor: playbackPanelBackground(theme, coverInfo),
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
                          child: const PlaybackPanel(fullscreen: true),
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

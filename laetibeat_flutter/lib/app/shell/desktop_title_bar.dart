import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/services/window_service.dart';

/// 桌面端自定义标题栏。移动端不会引用该文件。
class DesktopTitleBar extends ConsumerWidget {
  const DesktopTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final window = ref.read(windowServiceProvider);

    return DragToMoveArea(
      child: Container(
        color: theme.colorScheme.surfaceContainer,
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
        child: Row(
          children: [
            const Expanded(child: SizedBox()),
            M3EIconButton(
              size: M3EIconButtonSize.xs,
              icon: const Icon(M3EIcons.minimize),
              tooltip: '最小化',
              onPressed: window.minimize,
            ),
            M3EIconButton(
              size: M3EIconButtonSize.xs,
              icon: const Icon(M3EIcons.crop_square),
              tooltip: '最大化',
              onPressed: window.toggleMaximize,
            ),
            M3EIconButton(
              size: M3EIconButtonSize.xs,
              icon: const Icon(M3EIcons.close),
              tooltip: '关闭',
              onPressed: window.close,
            ),
          ],
        ),
      ),
    );
  }
}

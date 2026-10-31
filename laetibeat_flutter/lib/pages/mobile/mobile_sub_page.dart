import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../shared/layout/app_bottom_inset.dart';
import 'mini_player.dart';

/// 移动端二级页面统一外壳：返回栏 + 内容 + 浮动 mini player。
///
/// 通过 Navigator.push 打开，系统返回键天然生效，不再依赖 Shell 内索引切换。
class MobileSubPage extends StatelessWidget {
  const MobileSubPage({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      body: AppBottomInsetScope(
        bottomInset: kMiniPlayerReservedHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  M3EAppBar.top(
                    titleText: title,
                    variant: M3EAppBarVariant.small,
                    hideMode: M3EAppBarHideMode.none,
                    shapeFamily: M3EAppBarShapeFamily.square,
                    safeArea: true,
                    backgroundColor: theme.colorScheme.surfaceContainer,
                    leading: M3EIconButton(
                      size: M3EIconButtonSize.sm,
                      icon: const Icon(M3EIcons.arrow_back),
                      tooltip: '返回',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Expanded(
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: MiniPlayer(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

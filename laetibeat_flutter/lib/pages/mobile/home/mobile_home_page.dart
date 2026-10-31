import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../routes.dart';

/// 移动端首页。
///
/// 独立页面：后续通过 Navigator 承载，才能正确支持 Android 预测性返回手势。
class MobileHomePage extends StatelessWidget {
  const MobileHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: M3EAppBar.top(
        backgroundColor: theme.colorScheme.surfaceContainer,
        variant: M3EAppBarVariant.small,
        hideMode: M3EAppBarHideMode.entire,
        density: M3EAppBarDensity.compact,
        shapeFamily: M3EAppBarShapeFamily.square,
        safeArea: true,
        actions: [
          M3EIconButton(
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(M3EIcons.bar_chart),
            tooltip: '统计',
            onPressed: () => Navigator.of(context).pushNamed(MobileRoutes.stats),
          ),
          M3EIconButton(
            variant: M3EIconButtonVariant.tonal,
            shape: M3EIconButtonShapeVariant.round,
            icon: const Icon(M3EIcons.settings),
            tooltip: '设置',
            onPressed: () =>
                Navigator.of(context).pushNamed(MobileRoutes.settings),
          ),
        ],
      ),
      body: const SizedBox.expand(),
    );
  }
}

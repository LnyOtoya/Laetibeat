import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

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
        variant: M3EAppBarVariant.small,
        hideMode: M3EAppBarHideMode.entire,
        density: M3EAppBarDensity.compact,
        shapeFamily: M3EAppBarShapeFamily.square,
        safeArea: true,
      ),
      body: const SizedBox.expand(),
    );
  }
}

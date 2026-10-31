import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// 移动端统计页面。
///
/// 当前只建立独立页面与导航入口，内容后续实现。
class MobileStatsPage extends StatelessWidget {
  const MobileStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: M3EAppBar.top(
        titleText: '统计',
        leading: M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(M3EIcons.arrow_back),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        variant: M3EAppBarVariant.small,
        density: M3EAppBarDensity.compact,
        shapeFamily: M3EAppBarShapeFamily.square,
        safeArea: true,
      ),
      body: const SizedBox.expand(),
    );
  }
}

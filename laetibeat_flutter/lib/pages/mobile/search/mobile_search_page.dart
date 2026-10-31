import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// 移动端搜索页面。
///
/// 当前为独立占位页，后续按页面单独实现。
class MobileSearchPage extends StatelessWidget {
  const MobileSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      body: SafeArea(
        child: Center(
          child: Text(
            '搜索',
            style: theme.typeScale.headlineSmall,
          ),
        ),
      ),
    );
  }
}

import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/mobile_app_bar.dart';

/// 移动端音乐库页面。
///
/// 当前为独立占位页，后续按页面单独实现。
class MobileLibraryPage extends StatelessWidget {
  const MobileLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileTopAppBar(
        context,
        actions: mobileHomeAppBarActions(context),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: Text(
            '音乐库',
            style: theme.typeScale.headlineSmall,
          ),
        ),
      ),
    );
  }
}

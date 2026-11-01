import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'widgets/mobile_history_section.dart';

/// 移动端统计页面。
///
/// 当前只建立独立页面与导航入口，内容后续实现。
class MobileStatsPage extends StatelessWidget {
  const MobileStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: M3EAppBar.top(
        backgroundColor: theme.colorScheme.surfaceContainer,
        titleText: l10n.statisticsTitle,
        leading: M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(M3EIcons.arrow_back),
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        variant: M3EAppBarVariant.small,
        density: M3EAppBarDensity.compact,
        shapeFamily: M3EAppBarShapeFamily.square,
        safeArea: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: const [MobileHistorySection()],
      ),
    );
  }
}

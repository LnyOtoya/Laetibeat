import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../mobile_navigation.dart';
import '../routes.dart';
import '../settings/mobile_settings_page.dart';
import '../stats/mobile_stats_page.dart';

/// 移动端页面统一的顶部 AppBar。
M3EAppBar mobileTopAppBar(
  BuildContext context, {
  Widget? title,
  List<Widget> actions = const <Widget>[],
}) {
  final theme = M3ETheme.of(context);

  return M3EAppBar.top(
    backgroundColor: theme.colorScheme.surfaceContainer,
    variant: M3EAppBarVariant.small,
    hideMode: M3EAppBarHideMode.entire,
    density: M3EAppBarDensity.compact,
    shapeFamily: M3EAppBarShapeFamily.square,
    safeArea: true,
    title: title,
    actions: actions,
  );
}

/// Home / Library 共用的右侧操作：统计 + 设置。
List<Widget> mobileHomeAppBarActions(BuildContext context) {
  return <Widget>[
    mobileStatsAction(context),
    mobileSettingsAction(context),
  ];
}

/// 统计入口。
Widget mobileStatsAction(BuildContext context) {
  return M3EIconButton(
    variant: M3EIconButtonVariant.standard,
    icon: const Icon(M3EIcons.bar_chart),
    tooltip: '统计',
    onPressed: () => pushMobileRootPage(
      context,
      const MobileStatsPage(),
      name: MobileRoutes.stats,
    ),
  );
}

/// 设置入口。
Widget mobileSettingsAction(BuildContext context) {
  return Padding(
    // M3EAppBar 默认 contentPadding 只有 4，圆形背景视觉上会贴右侧太近。
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: M3EIconButton(
      variant: M3EIconButtonVariant.tonal,
      shape: M3EIconButtonShapeVariant.round,
      icon: const Icon(M3EIcons.settings),
      tooltip: '设置',
      onPressed: () => pushMobileRootPage(
        context,
        const MobileSettingsPage(),
        name: MobileRoutes.settings,
      ),
    ),
  );
}

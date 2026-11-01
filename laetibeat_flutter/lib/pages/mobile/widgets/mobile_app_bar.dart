import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import '../settings/mobile_settings_page.dart';
import '../settings/sources/mobile_music_sources_page.dart';
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

/// 移动端顶部 AppBar 的左侧标题。
Widget mobileTopAppBarTitle(BuildContext context, String text) {
  final theme = M3ETheme.of(context);
  return Padding(
    padding: const EdgeInsetsDirectional.only(start: 8),
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.typeScale.titleLarge.copyWith(
        color: theme.colorScheme.onSurface,
      ),
    ),
  );
}

/// Home / Library 共用的右侧操作：音乐源配置 + 统计 + 设置。
List<Widget> mobileHomeAppBarActions(BuildContext context) {
  return <Widget>[
    mobileMusicSourcesAction(context),
    mobileStatsAction(context),
    mobileSettingsAction(context),
  ];
}

/// 音乐源配置入口。
Widget mobileMusicSourcesAction(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return M3EIconButton(
    variant: M3EIconButtonVariant.standard,
    icon: const Icon(M3EIcons.cloud),
    tooltip: l10n.actionMusicSources,
    onPressed: () => pushMobileRootPage(
      context,
      const MobileMusicSourcesPage(),
      name: MobileRoutes.musicSources,
    ),
  );
}

/// 统计入口。
Widget mobileStatsAction(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return M3EIconButton(
    variant: M3EIconButtonVariant.standard,
    icon: const Icon(M3EIcons.bar_chart),
    tooltip: l10n.actionStatistics,
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
      tooltip: AppLocalizations.of(context).actionSettings,
      onPressed: () => pushMobileRootPage(
        context,
        const MobileSettingsPage(),
        name: MobileRoutes.settings,
      ),
    ),
  );
}

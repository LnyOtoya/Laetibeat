import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_destination.dart';
import 'home/mobile_home_page.dart';
import 'library/mobile_library_page.dart';
import 'routes.dart';
import 'search/mobile_search_page.dart';
import 'settings/mobile_settings_page.dart';
import 'stats/mobile_stats_page.dart';

/// 移动端 UI 的唯一入口。
///
/// 顶层的 Home / Library / Search 不是同一个 IndexedStack 的兄弟页面，
/// 而是嵌套 Navigator 中的真实 route。这样：
/// - Home 是根 route；
/// - 打开 Library / Search 会 push 新 route；
/// - 返回时 pop 回 Home；
/// - Android 预测性返回手势可以正常播放路由动画。
class MobileApp extends StatefulWidget {
  const MobileApp({super.key});

  @override
  State<MobileApp> createState() => _MobileAppState();
}

class _MobileAppState extends State<MobileApp> {
  static const List<AppDestination> _tabs = [
    AppDestination.home,
    AppDestination.library,
    AppDestination.search,
  ];

  static const List<M3ENavigationBarDestination> _destinations = [
    M3ENavigationBarDestination(
      icon: Icon(M3EIcons.home),
      label: 'Home',
    ),
    M3ENavigationBarDestination(
      icon: Icon(M3EIcons.music_note),
      label: 'Library',
    ),
    M3ENavigationBarDestination(
      icon: Icon(M3EIcons.search),
      label: 'Search',
    ),
  ];

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final _MobileNavigatorObserver _navigatorObserver =
      _MobileNavigatorObserver(_handleRouteChanged);
  AppDestination _currentTab = AppDestination.home;

  String _routeNameOf(AppDestination destination) {
    return switch (destination) {
      AppDestination.library => MobileRoutes.library,
      AppDestination.search => MobileRoutes.search,
      _ => MobileRoutes.home,
    };
  }

  void _handleRouteChanged(Route<dynamic>? route) {
    final String? name = route?.settings.name;
    final AppDestination? tab = switch (name) {
      MobileRoutes.home => AppDestination.home,
      MobileRoutes.library => AppDestination.library,
      MobileRoutes.search => AppDestination.search,
      _ => null,
    };

    // 详情页等未知 route 不改变底部导航的选中项。
    if (tab == null || tab == _currentTab) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || tab == _currentTab) return;
      setState(() => _currentTab = tab);
    });
  }

  void _selectTab(AppDestination destination) {
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    if (destination == AppDestination.home) {
      // 即使底部导航已经选中 Home，也可能有统计 / 设置等二级页
      // push 在 Home 之上，此时点 Home 应该回到根页面。
      if (_currentTab == AppDestination.home && !navigator.canPop()) return;
      navigator.popUntil((Route<dynamic> route) => route.isFirst);
      return;
    }

    final String routeName = _routeNameOf(destination);
    if (_currentTab == destination) {
      // 当前 tab 上可能还有详情页：重复点选时回到该 tab 的根 route。
      navigator.popUntil(
        (Route<dynamic> route) =>
            route.isFirst || route.settings.name == routeName,
      );
      return;
    }

    // 底部导航是平级目的地：先回到 Home，再打开目标页面。
    // 这样任意非 Home 页面的返回栈都是 Home -> 目标页面。
    navigator.popUntil((Route<dynamic> route) => route.isFirst);
    navigator.pushNamed(routeName);
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      MobileRoutes.home => const MobileHomePage(),
      MobileRoutes.library => const MobileLibraryPage(),
      MobileRoutes.search => const MobileSearchPage(),
      MobileRoutes.stats => const MobileStatsPage(),
      MobileRoutes.settings => const MobileSettingsPage(),
      _ => const MobileHomePage(),
    };

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final int selectedIndex = _tabs.indexOf(_currentTab);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      body: NavigatorPopHandler<void>(
        onPopWithResult: (_) => _navigatorKey.currentState?.pop(),
        child: Navigator(
          key: _navigatorKey,
          observers: [_navigatorObserver],
          onGenerateRoute: _onGenerateRoute,
        ),
      ),
      bottomNavigationBar: M3ENavigationBar(
        destinations: _destinations,
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (int index) {
          if (index < 0 || index >= _tabs.length) return;
          _selectTab(_tabs[index]);
        },
        size: M3ENavBarSize.medium,
        density: M3ENavBarDensity.compact,
        shapeFamily: M3ENavBarShapeFamily.square,
        labelBehavior: M3ENavBarLabelBehavior.alwaysShow,
      ),
    );
  }
}

class _MobileNavigatorObserver extends NavigatorObserver {
  _MobileNavigatorObserver(this.onChanged);

  final void Function(Route<dynamic>? route) onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    onChanged(newRoute);
  }
}

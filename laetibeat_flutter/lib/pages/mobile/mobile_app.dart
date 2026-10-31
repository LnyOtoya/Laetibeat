import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_destination.dart';
import 'home/mobile_home_page.dart';
import 'library/mobile_library_page.dart';
import 'routes.dart';
import 'search/mobile_search_page.dart';
import 'settings/content/mobile_content_settings_page.dart';
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
  bool _showNavigationBar = true;

  String _routeNameOf(AppDestination destination) {
    return switch (destination) {
      AppDestination.library => MobileRoutes.library,
      AppDestination.search => MobileRoutes.search,
      _ => MobileRoutes.home,
    };
  }

  void _handleRouteChanged(Route<dynamic>? route) {
    if (!mounted) return;

    final String? name = route?.settings.name;
    final AppDestination? tab = switch (name) {
      MobileRoutes.home => AppDestination.home,
      MobileRoutes.library => AppDestination.library,
      MobileRoutes.search => AppDestination.search,
      _ => null,
    };
    final bool? showNavigationBar = switch (name) {
      MobileRoutes.home ||
      MobileRoutes.library ||
      MobileRoutes.search => true,
      MobileRoutes.stats ||
      MobileRoutes.settings ||
      MobileRoutes.contentSettings => false,
      _ => null,
    };

    bool changed = false;
    if (tab != null && tab != _currentTab) {
      _currentTab = tab;
      changed = true;
    }
    // 统计 / 设置是独立页面，不显示底部导航。
    // 未知 route（例如详情页）保持当前导航栏状态。
    if (showNavigationBar != null &&
        showNavigationBar != _showNavigationBar) {
      _showNavigationBar = showNavigationBar;
      changed = true;
    }

    if (changed) {
      // NavigatorObserver 已经统一在 post-frame 回调中通知，
      // 此时 setState 是安全的。
      setState(() {});
    }
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

    // 保留真实的 tab 历史：
    // Home -> Library -> Search
    // 返回时 Search -> Library -> Home。
    // 这里直接 push，不 pop 到 Home，也不会出现 Home 的闪现。
    navigator.pushNamed(routeName);
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      MobileRoutes.home => const MobileHomePage(),
      MobileRoutes.library => const MobileLibraryPage(),
      MobileRoutes.search => const MobileSearchPage(),
      MobileRoutes.stats => const MobileStatsPage(),
      MobileRoutes.settings => const MobileSettingsPage(),
      MobileRoutes.contentSettings => const MobileContentSettingsPage(),
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
      bottomNavigationBar: _showNavigationBar
          ? M3ENavigationBar(
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
            )
          : null,
    );
  }
}

class _MobileNavigatorObserver extends NavigatorObserver {
  _MobileNavigatorObserver(this.onChanged);

  final void Function(Route<dynamic>? route) onChanged;
  final List<Route<dynamic>> _routes = <Route<dynamic>>[];
  bool _syncScheduled = false;

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      onChanged(_routes.isEmpty ? null : _routes.last);
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _scheduleSync();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _scheduleSync();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _scheduleSync();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      final int index = _routes.indexOf(oldRoute);
      if (index >= 0) {
        if (newRoute != null) {
          _routes[index] = newRoute;
        } else {
          _routes.removeAt(index);
        }
      } else if (newRoute != null) {
        _routes.add(newRoute);
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _scheduleSync();
  }
}

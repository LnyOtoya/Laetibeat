import 'package:material_ui/material_ui.dart';

import 'routes.dart';

/// 移动端唯一的根 Navigator。
///
/// Home、Library、Search、设置、详情页全部 push 到这条 Navigator 上，
/// 不再使用“根 Navigator + 嵌套 Navigator”的交错结构。
final GlobalKey<NavigatorState> mobileNavigatorKey =
    GlobalKey<NavigatorState>();

/// 当前最上层的移动端路由名，供外层 Shell 决定底部导航是否显示。
final ValueNotifier<String?> mobileCurrentRouteName = ValueNotifier<String?>(
  MobileRoutes.home,
);

class MobileNavigatorObserver extends NavigatorObserver {
  void _setRoute(Route<dynamic>? route) {
    final String? name = route?.settings.name;
    mobileCurrentRouteName.value = name ?? MobileRoutes.home;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _setRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _setRoute(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _setRoute(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _setRoute(newRoute ?? oldRoute);
  }
}

final MobileNavigatorObserver mobileNavigatorObserver =
    MobileNavigatorObserver();

/// 将移动端页面推到根 Navigator。
Future<T?> pushMobileRootPage<T>(
  BuildContext context,
  Widget page, {
  String? name,
}) {
  // MiniPlayer 等 Shell 组件在根 Navigator 外层，context 中没有 Navigator。
  // 优先使用全局 key，页面内调用时再回退到 context 查找。
  final NavigatorState? navigator =
      mobileNavigatorKey.currentState ??
      Navigator.maybeOf(context, rootNavigator: true);
  if (navigator == null) {
    return Future<T?>.value(null);
  }
  return navigator.push<T>(
    MaterialPageRoute<T>(
      settings: name == null ? null : RouteSettings(name: name),
      builder: (_) => page,
    ),
  );
}

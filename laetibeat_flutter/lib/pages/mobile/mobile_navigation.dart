import 'package:material_ui/material_ui.dart';

/// 将移动端二级页面推到根 Navigator。
///
/// 嵌套 Navigator 中的 NavigatorPopHandler 会把 PopScope.canPop 置为 false，
/// Android 在 canPop=false 时不会播放预测性返回动画。
/// 统计、设置、内容这类全屏二级页因此改走根 Navigator。
Future<T?> pushMobileRootPage<T>(
  BuildContext context,
  Widget page, {
  String? name,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute<T>(
      settings: name == null ? null : RouteSettings(name: name),
      builder: (_) => page,
    ),
  );
}

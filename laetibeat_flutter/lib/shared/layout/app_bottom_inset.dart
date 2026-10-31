import 'package:flutter/widgets.dart';

/// 由 Shell 提供：页面内容需要在底部预留的高度（如浮动 mini player）。
///
/// 页面只依赖这个抽象，不依赖“移动端”“mini player”等具体概念。
/// 桌面端没有该作用域时返回 0。
class AppBottomInsetScope extends InheritedWidget {
  const AppBottomInsetScope({
    super.key,
    required this.bottomInset,
    required super.child,
  });

  final double bottomInset;

  static double bottomInsetOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppBottomInsetScope>()
          ?.bottomInset ??
      0;

  @override
  bool updateShouldNotify(AppBottomInsetScope oldWidget) =>
      oldWidget.bottomInset != bottomInset;
}

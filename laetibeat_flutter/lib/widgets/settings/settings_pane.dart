import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../../animations.dart';
import '../../shared/layout/app_bottom_inset.dart';

/// 给设置内容内部滚动区追加底部间距，避免内容被浮动 mini player 遮挡。
/// 桌面端没有该作用域时返回 0。
class SettingsPaneInset extends InheritedWidget {
  const SettingsPaneInset({
    super.key,
    required this.bottom,
    required super.child,
  });

  final double bottom;

  static double bottomOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsPaneInset>()?.bottom ??
      0;

  @override
  bool updateShouldNotify(SettingsPaneInset oldWidget) =>
      oldWidget.bottom != bottom;
}

//右侧设置内容统一外壳:表面容器+内滚动+标题
class SettingsPane extends StatelessWidget {
  const SettingsPane({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final bottomInset = math.max(
      SettingsPaneInset.bottomOf(context),
      AppBottomInsetScope.bottomInsetOf(context),
    );

    return AnimatedContainer(
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
      padding: EdgeInsets.all(theme.spacing.xl),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.typeScale.titleLarge,
              ),
              SizedBox(height: theme.spacing.lg),
              ...children,
              SizedBox(height: bottomInset),
            ],
          ),
        ),
      ),
    );
  }
}

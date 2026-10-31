import 'package:flutter/widgets.dart';

/// 窗口尺寸档位。与 [AppFormFactor] 是两个独立维度：
/// - AppFormFactor 决定使用哪套 Shell；
/// - AppSizeClass 决定 Shell 内部如何排版。
enum AppSizeClass { compact, medium, expanded }

/// 桌面单栏折叠阈值。集中在这里，避免各页面散落魔法数字。
const double kSinglePaneBreakpoint = 720;

/// Material 3 window size class 的常用阈值。
const double kCompactMaxWidth = 600;
const double kMediumMaxWidth = 840;

AppSizeClass appSizeClassOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < kCompactMaxWidth) return AppSizeClass.compact;
  if (width < kMediumMaxWidth) return AppSizeClass.medium;
  return AppSizeClass.expanded;
}

bool isSinglePaneWidth(double width, {double breakpoint = kSinglePaneBreakpoint}) {
  return width < breakpoint;
}

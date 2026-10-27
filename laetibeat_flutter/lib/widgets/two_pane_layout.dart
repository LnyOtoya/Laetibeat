import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

const double kSinglePaneBreakpoint = 720;

// 与 TwoPaneLayout 使用同一套单栏判断，供页面自己决定是否走独立页面导航
bool useSinglePaneLayout(
  BuildContext context,
  double width, {
  double breakpoint = kSinglePaneBreakpoint,
}) {
  final bool isMobilePlatform =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  return isMobilePlatform || width < breakpoint;
}

class TwoPaneLayout extends StatelessWidget {
  // leftFlex/rightFlex控制左右占比,默认1:1等分
  const TwoPaneLayout({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
    // 右区最大宽度:null时维持 flex 比例;非null时右区封顶,超出让给左区
    this.rightMaxWidth,
    // 小于该宽度时只显示左侧,右区暂时隐藏
    this.singlePaneBreakpoint = kSinglePaneBreakpoint,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double? rightMaxWidth;
  final double singlePaneBreakpoint;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return LayoutBuilder(
      builder: (context, c) {
        // 移动端/窄窗口暂时隐藏右区,左侧占满可用宽度
        if (useSinglePaneLayout(
          context,
          c.maxWidth,
          breakpoint: singlePaneBreakpoint,
        )) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spacing.md,
              0,
              theme.spacing.md,
              theme.spacing.md,
            ),
            child: left,
          );
        }

        // 按 flex比例算出的右区宽度,再与 rightMaxWidth 取较小值
        final rightW = (c.maxWidth * rightFlex / (leftFlex + rightFlex))
            .clamp(0.0, rightMaxWidth ?? double.infinity)
            .toDouble();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左区吃掉剩余全部宽度
            Expanded(
              flex: leftFlex,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  theme.spacing.md,
                  0,
                  theme.spacing.sm,
                  theme.spacing.md,
                ),
                child: left,
              ),
            ),
            // 右区为固定宽度槽位
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.sm,
                0,
                theme.spacing.md,
                theme.spacing.md,
              ),
              child: SizedBox(width: rightW, child: right),
            ),
          ],
        );
      },
    );
  }
}
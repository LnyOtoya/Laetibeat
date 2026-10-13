import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

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
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double? rightMaxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return LayoutBuilder(
      builder: (context, c) {
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
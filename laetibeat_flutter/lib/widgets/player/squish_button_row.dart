import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

/// SquishButtonRow —— 上一首 / 播放暂停 / 下一首 控制排
///
/// 复刻 material_3_expressive 的 neighbor-squish 效果(内部 M3E 未用作分组,
/// 而是用普通 widget 驱动宽度动画,按钮本体用仓库的 [M3EButton]):
///   growth = 被按按钮自然宽 * expandedRatio * 动画进度
///   被按按钮宽度 += growth
///   中间被按 -> 两侧邻居各 - growth / 2;  边缘被按 -> 唯一邻居 - growth
///
/// 因内部重分配宽度,整排总宽在按压时保持不变,整体居中后两侧间距稳定。
///
/// [haptic] 在按下瞬间触发(与 M3EButtonGroup.haptic 同义),[M3EHapticFeedback.none] 不触发。
class SquishButtonRow extends StatefulWidget {
  const SquishButtonRow({
    super.key,
    this.isPlaying = false,
    this.previousEnabled = true,
    this.toggleEnabled = true,
    this.nextEnabled = true,
    this.onPrevious,
    this.onToggle,
    this.onNext,
    this.expandedRatio = 0.35,
    this.haptic = M3EHapticFeedback.none,
  });

  /// 播放中(true)时中间按钮显示"暂停"
  final bool isPlaying;

  /// 三个按钮各自是否可交互(禁用时 M3EButton 自动置灰且不可点)
  final bool previousEnabled;
  final bool toggleEnabled;
  final bool nextEnabled;

  final VoidCallback? onPrevious;
  final VoidCallback? onToggle;
  final VoidCallback? onNext;

  /// 被按按钮最大增长率(M3EButtonGroup 默认 0.15)
  final double expandedRatio;

  /// 按压震动反馈强度
  final M3EHapticFeedback haptic;

  @override
  State<SquishButtonRow> createState() => _SquishButtonRowState();
}

class _SquishButtonRowState extends State<SquishButtonRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 260),
  );
  late final CurvedAnimation _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  /// 当前被按住的按钮索引, null 表示没有
  int? _pressed;

  /// 纯圆形(前后)按钮的基本宽度
  static const double _roundBase = 56.0;
  static const double _iconSize = 24.0;

  /// 按钮高度与 [M3EButtonSize.md] 对齐,行内三键等高
  static const double _buttonHeight = 56.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _enabled(int i) => switch (i) {
        0 => widget.previousEnabled,
        1 => widget.toggleEnabled,
        2 => widget.nextEnabled,
        _ => false,
      };

  void _fire(int i) => switch (i) {
        0 => widget.onPrevious?.call(),
        1 => widget.onToggle?.call(),
        2 => widget.onNext?.call(),
        _ => null,
      };

  // ---- 宽度计算 ----

  double _naturalWidth(int i, M3EThemeData theme, TextStyle labelStyle) {
    switch (i) {
      case 0:
      case 2:
        return _roundBase;
      case 1:
        // 胶囊: 圆形部分 + 文本 + 图标 + 间距 + 呼吸余量
        // 呼吸余量刻意放大,让中间按钮更长,以填掉两侧留白
        final tp = TextPainter(
          text: TextSpan(
            text: widget.isPlaying ? '暂停' : '播放',
            style: labelStyle,
          ),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        return _roundBase + tp.width + _iconSize + theme.spacing.lg * 4;
    }
    return _roundBase;
  }

  List<double> _squishSizes(M3EThemeData theme, TextStyle labelStyle) {
    const n = 3;
    final natural = [
      for (var i = 0; i < n; i++) _naturalWidth(i, theme, labelStyle),
    ];
    final sizes = List<double>.of(natural);

    final pressed = _pressed;
    final t = _curve.value;
    if (pressed == null || t <= 0) {
      return sizes;
    }

    final growth = natural[pressed] * widget.expandedRatio * t;
    sizes[pressed] += growth;

    // 邻居收缩: 中间 -> 各减 growth/2; 边缘 -> 唯一邻居减 growth
    if (pressed > 0 && pressed < n - 1) {
      sizes[pressed - 1] = math.max(0, sizes[pressed - 1] - growth / 2);
      sizes[pressed + 1] = math.max(0, sizes[pressed + 1] - growth / 2);
    } else if (pressed == 0 && n > 1) {
      sizes[1] = math.max(0, sizes[1] - growth);
    } else if (pressed == n - 1 && n > 1) {
      sizes[pressed - 1] = math.max(0, sizes[pressed - 1] - growth);
    }
    return sizes;
  }

  // ---- 交互 ----

  void _press(int i) {
    if (!_enabled(i)) {
      return;
    }
    M3EHaptics.trigger(widget.haptic);
    setState(() => _pressed = i);
    _controller.forward(from: 0);
  }

  void _release(int i) {
    if (_pressed != i) {
      return;
    }
    setState(() => _pressed = null);
    _controller.reverse();
    _fire(i);
  }

  void _cancel(int i) {
    if (_pressed != i) {
      return;
    }
    setState(() => _pressed = null);
    _controller.reverse();
  }

  // ---- 构建 ----

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final labelStyle = theme.typeScale.labelMedium;

    // 其余控件用同款 FittedBox 防溢出: 空间不足时整行缩放而非横向溢出
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final sizes = _squishSizes(theme, labelStyle);
          // 居中、三键紧密相邻; 通过加长中间按钮来缩小两侧留白
          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _button(
                  0,
                  sizes[0],
                  icon: Icons.skip_previous,
                  label: null,
                  tooltip: '上一首',
                ),
                SizedBox(width: theme.spacing.sm),
                _button(
                  1,
                  sizes[1],
                  icon: widget.isPlaying ? Icons.pause : Icons.play_arrow,
                  label: widget.isPlaying ? '暂停' : '播放',
                  tooltip: widget.isPlaying ? '暂停' : '播放',
                ),
                SizedBox(width: theme.spacing.sm),
                _button(
                  2,
                  sizes[2],
                  icon: Icons.skip_next,
                  label: null,
                  tooltip: '下一首',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _button(
    int index,
    double width, {
    required IconData icon,
    required String? label,
    required String tooltip,
  }) {
    final enabled = _enabled(index);
    // GestureDetector 持有手势(驱动 squish 动画),按钮只做视觉;
    // IgnorePointer 阻止按钮抢夺手势,behavior opaque 保证外层仍被命中。
    final Widget visual = label == null
        // 两侧纯图标: M3EIconButton 原生居中图标;
        // matchParentConstraints 让其随 squish 槽位宽度伸缩、保持圆角不裁切
        ? M3EIconButton(
            icon: Icon(icon),
            variant: M3EIconButtonVariant.filled,
            size: M3EIconButtonSize.md,
            shape: M3EIconButtonShapeVariant.round,
            matchParentConstraints: true,
            tooltip: tooltip,
          )
        // 中间播放/暂停: 带 label 的 M3EButton, 用 fixedSize 精确等于 squish
        // 宽度并居中 icon+label, 不再依赖外层 SizedBox 强改宽度
        : M3EButton(
            icon: Icon(icon),
            label: Text(label!),
            decoration: M3EButtonDecoration(
              fixedSize: Size(width, _buttonHeight),
            ),
            onPressed: enabled ? () {} : null,
            enabled: enabled,
            style: M3EButtonStyle.filled,
            size: M3EButtonSize.md,
            shape: M3EButtonShape.round,
            tooltip: tooltip,
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _press(index) : null,
      onTapUp: enabled ? (_) => _release(index) : null,
      onTapCancel: () {
        if (enabled) {
          _cancel(index);
        }
      },
      child: IgnorePointer(
        child: SizedBox(
          width: width,
          height: _buttonHeight,
          child: visual,
        ),
      ),
    );
  }
}
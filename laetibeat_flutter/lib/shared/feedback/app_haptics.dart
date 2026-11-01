import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 全局触感反馈入口。
abstract final class AppHaptics {
  static bool _suppressNextTap = false;

  /// 普通点击反馈。
  static void tap() {
    unawaited(HapticFeedback.selectionClick());
  }

  /// 更明显的一次性反馈。
  static void impact() {
    unawaited(HapticFeedback.mediumImpact());
  }

  /// 让下一次全局点击反馈跳过，用于按钮自己提供专属震动。
  static void suppressNextTap() {
    _suppressNextTap = true;
  }

  /// 全局点击层消费一次抑制标记。
  static bool consumeSuppressedTap() {
    if (!_suppressNextTap) return false;
    _suppressNextTap = false;
    return true;
  }
}

/// 监听移动端所有点击，并触发统一触感。
///
/// 只有短按且没有明显拖动时才触发，避免滚动列表时持续震动。
class TapHapticDetector extends StatefulWidget {
  const TapHapticDetector({super.key, required this.child});

  final Widget child;

  @override
  State<TapHapticDetector> createState() => _TapHapticDetectorState();
}

class _TapHapticDetectorState extends State<TapHapticDetector> {
  static const double _maxTapDistance = 12;
  static const Duration _maxTapDuration = Duration(milliseconds: 450);

  int? _pointer;
  Offset? _downPosition;
  DateTime? _downAt;
  double _maxDistance = 0;

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _downPosition = event.position;
    _downAt = DateTime.now();
    _maxDistance = 0;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final start = _downPosition;
    if (start == null) return;
    final distance = (event.position - start).distance;
    if (distance > _maxDistance) _maxDistance = distance;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final downAt = _downAt;
    final isTap =
        _maxDistance <= _maxTapDistance &&
        downAt != null &&
        DateTime.now().difference(downAt) <= _maxTapDuration;
    if (isTap && !AppHaptics.consumeSuppressedTap()) {
      AppHaptics.tap();
    }
    _reset();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) _reset();
  }

  void _reset() {
    _pointer = null;
    _downPosition = null;
    _downAt = null;
    _maxDistance = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}

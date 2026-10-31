import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

/// 窗口管理能力。移动端使用无操作实现，桌面端使用 window_manager。
abstract interface class WindowService {
  Future<void> initialize();

  Future<void> minimize();

  Future<void> toggleMaximize();

  Future<void> close();
}

class DesktopWindowService implements WindowService {
  const DesktopWindowService();

  @override
  Future<void> initialize() async {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(1200, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<void> close() => windowManager.close();
}

/// 移动端没有桌面窗口概念，保持空实现。
class NoopWindowService implements WindowService {
  const NoopWindowService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> minimize() async {}

  @override
  Future<void> toggleMaximize() async {}

  @override
  Future<void> close() async {}
}

final windowServiceProvider = Provider<WindowService>((ref) {
  throw UnimplementedError(
    'windowServiceProvider 必须在 bootstrap 中注入',
  );
});

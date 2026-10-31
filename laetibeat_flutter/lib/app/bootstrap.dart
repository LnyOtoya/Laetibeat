import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/library.dart' as rust_library;
import 'package:laetibeat/src/rust/api/stats.dart' as rust_stats;
import 'package:laetibeat/src/rust/frb_generated.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers/playback_backend_provider.dart';
import '../core/services/directory_picker.dart';
import '../core/services/window_service.dart';
import '../widgets/player/playback_backend.dart';
import '../widgets/settings/persistence.dart';
import '../widgets/settings/subsonic_provider.dart';
import 'app.dart';
import 'app_form_factor.dart';

/// 应用启动装配层：平台判断、平台服务选择、全局初始化都在这里完成。
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final formFactor = detectAppFormFactor();

  final windowService = switch (formFactor) {
    AppFormFactor.desktop => const DesktopWindowService(),
    AppFormFactor.mobile => const NoopWindowService(),
  };
  try {
    await windowService.initialize();
  } catch (e) {
    debugPrint('窗口管理器初始化失败: $e');
  }

  await RustLib.init();

  // 初始化播放统计库(失败不阻塞应用启动)
  try {
    final supportDir = await getApplicationSupportDirectory();
    await supportDir.create(recursive: true);
    await rust_stats.initStatsDb(
      path: '${supportDir.path}/laetibeat_stats.db',
    );
  } catch (e) {
    debugPrint('初始化播放统计库失败: $e');
  }

  // 初始化远端音乐库数据库(失败不阻塞应用启动)
  try {
    final supportDir = await getApplicationSupportDirectory();
    await supportDir.create(recursive: true);
    await rust_library.initLibraryDb(
      path: '${supportDir.path}/laetibeat_library.db',
    );
  } catch (e) {
    debugPrint('初始化远端音乐库数据库失败: $e');
  }

  // 预加载本地设置与播放快照,供 Riverpod provider 构建时同步恢复
  final prefs = await SharedPreferences.getInstance();
  final playbackStore = PlaybackSnapshotStore();
  final playbackSnapshot = await playbackStore.load();

  // 后台重连已保存的 OpenSubsonic 服务器,不阻塞启动
  unawaited(reconnectSubsonicServers(prefs));

  final directoryPicker = switch (formFactor) {
    AppFormFactor.desktop => const DesktopDirectoryPicker(),
    AppFormFactor.mobile => const MobileDirectoryPicker(),
  };

  runApp(
    ProviderScope(
      overrides: [
        appFormFactorProvider.overrideWithValue(formFactor),
        windowServiceProvider.overrideWithValue(windowService),
        directoryPickerProvider.overrideWithValue(directoryPicker),
        playbackBackendProvider.overrideWithValue(MediaKitBackend()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        playbackSnapshotStoreProvider.overrideWithValue(playbackStore),
        initialPlaybackSnapshotProvider.overrideWithValue(playbackSnapshot),
      ],
      child: const LaetibeatApp(),
    ),
  );
}

import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/frb_generated.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'nav_shell.dart';
import 'widgets/integration/media_integration_host.dart';
import 'widgets/settings/persistence.dart';
import 'widgets/settings/settings_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(1200, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  await RustLib.init();
  // 预加载本地设置,供 Riverpod provider 同步读取
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //按设置的主题模式驱动亮暗/跟随系统
    final AppThemeMode themeMode = ref.watch(appThemeModeProvider);
    final bool followSystem = themeMode == AppThemeMode.system;
    final Brightness? initialTheme = followSystem
        ? null
        : (themeMode == AppThemeMode.dark ? Brightness.dark : Brightness.light);

    return M3EMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Laetibeat',
      data: M3EThemeData.light(
        seedColor: const Color(0xFF6750A4),
      ).copyWith(
        navigationRailTheme: M3ENavigationRailTheme(
          collapsedWidth: 104,
        ),
        fontFamilyFallback: const <String>[
          'Noto Sans SC',
          'Noto Sans TC',
          'Noto Sans JP',
          'Noto Sans KR',
        ],
      ),
      dynamicColoring: true,
      autoTheming: followSystem,
      initialTheme: initialTheme,
      fontFamily: 'Google Sans Flex',
      variableFont: const M3EVariableFontConfig(
        enableOpsz: true,
        syncWghtToWeight: true,
        emphasizedGrad: 50,
      ),
      home: const MediaIntegrationHost(child: NavShell()),
    );
  }
}


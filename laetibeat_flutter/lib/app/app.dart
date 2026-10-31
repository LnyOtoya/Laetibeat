import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../widgets/integration/media_integration_host.dart';
import '../widgets/settings/settings_provider.dart';
import 'app_form_factor.dart';
import 'shell/desktop_shell.dart';
import 'shell/mobile_shell.dart';
import 'theme/app_theme.dart';

/// 应用根节点：只负责形态选择、主题装配与全局宿主。
class LaetibeatApp extends ConsumerWidget {
  const LaetibeatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formFactor = ref.watch(appFormFactorProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final followSystem = themeMode == AppThemeMode.system;
    final initialTheme = followSystem
        ? null
        : (themeMode == AppThemeMode.dark ? Brightness.dark : Brightness.light);

    return M3EMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Laetibeat',
      data: AppThemeFactory.dataFor(formFactor),
      dynamicColoring: true,
      autoTheming: followSystem,
      initialTheme: initialTheme,
      fontFamily: 'Google Sans Flex',
      variableFont: const M3EVariableFontConfig(
        enableOpsz: true,
        syncWghtToWeight: true,
        emphasizedGrad: 50,
      ),
      home: MediaIntegrationHost(
        child: switch (formFactor) {
          AppFormFactor.desktop => const DesktopShell(),
          AppFormFactor.mobile => const MobileShell(),
        },
      ),
    );
  }
}

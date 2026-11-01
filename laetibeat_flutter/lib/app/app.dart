import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    as flutter_l10n;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

import '../l10n/generated/app_localizations.dart';
import '../pages/desktop/desktop_app.dart';
import '../pages/mobile/mobile_app.dart';
import '../widgets/integration/media_integration_host.dart';
import '../widgets/settings/settings_provider.dart';
import 'app_form_factor.dart';
import 'app_locale.dart';
import 'theme/app_theme.dart';

/// 应用根节点：只负责形态选择、主题装配与全局宿主。
class LaetibeatApp extends ConsumerWidget {
  const LaetibeatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formFactor = ref.watch(appFormFactorProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final language = ref.watch(appLanguageProvider);
    final followSystem = themeMode == AppThemeMode.system;
    final initialTheme = followSystem
        ? null
        : (themeMode == AppThemeMode.dark ? Brightness.dark : Brightness.light);

    return M3EMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Laetibeat',
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: localeFor(language),
      // M3EMaterialApp uses material_ui's MaterialApp/Cupertino types, so the
      // Flutter-global delegates from flutter_localizations do not satisfy it.
      // Use material_ui's global delegates plus our generated app delegate.
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        // M3EMaterialApp uses material_ui's Material/Cupertino localizations.
        ...GlobalMaterialLocalizations.delegates,
        // Some pages still use widgets from Flutter's material library.
        flutter_l10n.GlobalMaterialLocalizations.delegate,
        flutter_l10n.GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
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
          AppFormFactor.desktop => const DesktopApp(),
          AppFormFactor.mobile => const MobileApp(),
        },
      ),
    );
  }
}

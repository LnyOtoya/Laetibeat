import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/settings/persistence.dart';

/// 应用语言。`system` 表示交给系统与 Flutter 的 localeResolution 处理。
enum AppLanguage { system, zh, en }

const String kAppLocaleKey = 'settings.locale';

Locale? localeFor(AppLanguage language) {
  return switch (language) {
    AppLanguage.system => null,
    AppLanguage.zh => const Locale('zh'),
    AppLanguage.en => const Locale('en'),
  };
}

AppLanguage appLanguageFromCode(String? code) {
  return switch (code) {
    'zh' => AppLanguage.zh,
    'en' => AppLanguage.en,
    _ => AppLanguage.system,
  };
}

class AppLanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return appLanguageFromCode(prefs.getString(kAppLocaleKey));
  }

  Future<void> select(AppLanguage language) async {
    state = language;
    final prefs = ref.read(sharedPreferencesProvider);
    if (language == AppLanguage.system) {
      await prefs.remove(kAppLocaleKey);
    } else {
      await prefs.setString(kAppLocaleKey, language.name);
    }
  }
}

final appLanguageProvider = NotifierProvider<AppLanguageNotifier, AppLanguage>(
  AppLanguageNotifier.new,
);

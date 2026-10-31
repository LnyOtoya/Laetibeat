import 'package:flutter/widgets.dart';

import '../../widgets/settings/about_settings.dart';
import '../../widgets/settings/appearance_settings.dart';
import '../../widgets/settings/content_settings.dart';
import '../../widgets/settings/settings_pane.dart';
import '../../widgets/settings/settings_provider.dart';

String settingsCategoryLabel(SettingsCategory category) {
  return switch (category) {
    SettingsCategory.appearance => '外观',
    SettingsCategory.playerAudio => '播放器与音频',
    SettingsCategory.content => '内容',
    SettingsCategory.storage => '储存',
    SettingsCategory.backup => '备份与还原',
    SettingsCategory.changelog => '更新日志',
    SettingsCategory.about => '关于',
  };
}

Widget settingsContent(SettingsCategory category) {
  return switch (category) {
    SettingsCategory.appearance => const AppearanceSettings(),
    SettingsCategory.playerAudio => const SettingsPlaceholder(title: '播放器与音频'),
    SettingsCategory.content => const ContentSettings(),
    SettingsCategory.storage => const SettingsPlaceholder(title: '储存'),
    SettingsCategory.backup => const SettingsPlaceholder(title: '备份与还原'),
    SettingsCategory.changelog => const SettingsPlaceholder(title: '更新日志'),
    SettingsCategory.about => const AboutSettings(),
  };
}

/// 未开发分类的占位内容。
class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SettingsPane(
      title: title,
      children: const [],
    );
  }
}

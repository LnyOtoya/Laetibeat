import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../widgets/settings/settings_provider.dart';
import '../../widgets/settings/settings_section.dart';
import '../settings/settings_content.dart';
import 'mobile_sub_page.dart';

/// 移动端设置分类列表。外壳由 MobileSubPage 提供。
class MobileSettingsPage extends StatelessWidget {
  const MobileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      showTitle: false,
      onSelected: (category) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MobileSettingsCategoryPage(category: category),
          ),
        );
      },
    );
  }
}

class MobileSettingsCategoryPage extends StatelessWidget {
  const MobileSettingsCategoryPage({super.key, required this.category});

  final SettingsCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return MobileSubPage(
      title: settingsCategoryLabel(category),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: settingsContent(category),
      ),
    );
  }
}

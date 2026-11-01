import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../mobile_navigation.dart';
import '../routes.dart';
import 'appearance/mobile_appearance_settings_page.dart';
import 'content/mobile_content_settings_page.dart';
import '../widgets/mobile_search_bar.dart';

/// 移动端设置页面。
///
/// 顶部使用与 Search 页同款的搜索栏，不显示 AppBar。
/// 只展示四大部分，每部分使用一个 connected filled card list，
/// 只保留 headline / supporting，不显示叶子设置项。
class MobileSettingsPage extends StatelessWidget {
  const MobileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: MobileSearchBar(
                hintText: '搜索设置',
                variant: MobileSearchBarVariant.outlined,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _SettingsGroup(
                    onTap: (int index) {
                      if (index == 0) {
                        pushMobileRootPage(
                          context,
                          const MobileAppearanceSettingsPage(),
                          name: MobileRoutes.appearanceSettings,
                        );
                      }
                    },
                    items: [
                      M3EListItem(
                        headline: '外观',
                        supportingText: '主题与明暗切换',
                        leading: _SettingsLeadingAvatar(icon: M3EIcons.palette),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _SettingsGroup(
                    onTap: (int index) {
                      if (index == 1) {
                        pushMobileRootPage(
                          context,
                          const MobileContentSettingsPage(),
                          name: MobileRoutes.contentSettings,
                        );
                      }
                    },
                    items: [
                      M3EListItem(
                        headline: '播放器与音频',
                        supportingText: '淡入淡出与电池优化',
                        leading: _SettingsLeadingAvatar(
                          icon: M3EIcons.graphic_eq,
                        ),
                      ),
                      M3EListItem(
                        headline: '内容',
                        supportingText: '音乐库、歌词与语言',
                        leading: _SettingsLeadingAvatar(
                          icon: M3EIcons.library_music,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _SettingsGroup(
                    items: [
                      M3EListItem(
                        headline: '储存',
                        supportingText: '缓存管理',
                        leading: _SettingsLeadingAvatar(icon: M3EIcons.storage),
                      ),
                      M3EListItem(
                        headline: '备份与还原',
                        supportingText: '备份设置或从另一份配置中导入设置',
                        leading: _SettingsLeadingAvatar(
                          icon: M3EIcons.settings_backup_restore,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _SettingsGroup(
                    items: [
                      M3EListItem(
                        headline: '关于',
                        supportingText: '当前版本',
                        leading: _SettingsLeadingAvatar(icon: M3EIcons.info),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.items, this.onTap});

  final List<M3EListItem> items;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return M3EList(
      color: theme.colorScheme.surface,
      variant: M3ECardVariant.filled,
      onTap: onTap,
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) => items[index],
    );
  }
}

class _SettingsLeadingAvatar extends StatelessWidget {
  const _SettingsLeadingAvatar({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return SizedBox.square(
      dimension: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

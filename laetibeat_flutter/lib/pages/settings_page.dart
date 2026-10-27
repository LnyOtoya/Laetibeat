import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../animations.dart';
import '../widgets/two_pane_layout.dart';
import '../widgets/settings/settings_section.dart';
import '../widgets/settings/settings_provider.dart';
import '../widgets/settings/appearance_settings.dart';
import '../widgets/settings/about_settings.dart';
import '../widgets/settings/content_settings.dart';
import '../widgets/settings/settings_pane.dart';
import '../widgets/player/mini_player.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 移动端/窄窗口：分类列表独立成页，点击后 push 对应详情页
        if (useSinglePaneLayout(context, constraints.maxWidth)) {
          return SettingsSection(
            onSelected: (category) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _SettingsCategoryPage(category: category),
                ),
              );
            },
          );
        }

        // 桌面端保持原双栏
        return const TwoPaneLayout(
          leftFlex: 2,
          rightFlex: 3,
          left: SettingsSection(),
          right: _SettingsDetail(),
        );
      },
    );
  }
}

// 右侧详情槽,按选中分类切换内容
class _SettingsDetail extends ConsumerWidget {
  const _SettingsDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(settingsCategoryProvider);
    final Widget content = _settingsContent(category);

    return AnimatedSwitcher(
      duration: kSectionAnimDuration,
      switchInCurve: kSectionAnimCurve,
      switchOutCurve: kSectionAnimCurve,
      layoutBuilder: (currentChild, previousChildren) {
        //保持切换前后内容同尺寸,避免跳动
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.topLeft,
          children: [
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey(category),
        child: content,
      ),
    );
  }
}

// 移动端独立设置详情页
class _SettingsCategoryPage extends StatelessWidget {
  const _SettingsCategoryPage({required this.category});

  final SettingsCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.sm,
                theme.spacing.sm,
                theme.spacing.sm,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: M3EIconButton(
                  size: M3EIconButtonSize.sm,
                  icon: const Icon(M3EIcons.arrow_back),
                  tooltip: '返回',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  theme.spacing.sm,
                  0,
                  theme.spacing.sm,
                  theme.spacing.md,
                ),
                child: _settingsContent(category),
              ),
            ),
          ],
        ),
      ),
      // 独立详情页也保留全局迷你播放器
      bottomNavigationBar: const SafeArea(
        top: false,
        child: MiniPlayer(),
      ),
    );
  }
}

Widget _settingsContent(SettingsCategory category) {
  return switch (category) {
    SettingsCategory.appearance => const AppearanceSettings(),
    SettingsCategory.playerAudio => const _PlaceholderSettings(title: '播放器与音频'),
    SettingsCategory.content => const ContentSettings(),
    SettingsCategory.storage => const _PlaceholderSettings(title: '储存'),
    SettingsCategory.backup => const _PlaceholderSettings(title: '备份与还原'),
    SettingsCategory.changelog => const _PlaceholderSettings(title: '更新日志'),
    SettingsCategory.about => const AboutSettings(),
  };
}

//未开发分类的占位内容
class _PlaceholderSettings extends StatelessWidget {
  const _PlaceholderSettings({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SettingsPane(
      title: title,
      children: const [],
    );
  }
}

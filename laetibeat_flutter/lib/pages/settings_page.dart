import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../animations.dart';
import '../widgets/two_pane_layout.dart';
import '../widgets/settings/settings_section.dart';
import '../widgets/settings/settings_provider.dart';
import '../widgets/settings/appearance_settings.dart';
import '../widgets/settings/about_settings.dart';
import '../widgets/settings/content_settings.dart';
import '../widgets/settings/settings_pane.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TwoPaneLayout(
      leftFlex: 2,
      rightFlex: 3,
      left: SettingsSection(),
      right: _SettingsDetail(),
    );
  }
}

//右侧详情槽,按选中分类切换内容
class _SettingsDetail extends ConsumerWidget {
  const _SettingsDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(settingsCategoryProvider);

    final Widget content = switch (category) {
      SettingsCategory.appearance => const AppearanceSettings(),
      SettingsCategory.playerAudio => const _PlaceholderSettings(title: '播放器与音频'),
      SettingsCategory.content => const ContentSettings(),
      SettingsCategory.storage => const _PlaceholderSettings(title: '储存'),
      SettingsCategory.backup => const _PlaceholderSettings(title: '备份与还原'),
      SettingsCategory.changelog => const _PlaceholderSettings(title: '更新日志'),
      SettingsCategory.about => const AboutSettings(),
    };

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

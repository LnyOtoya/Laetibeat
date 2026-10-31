import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../widgets/mobile_large_subpage_app_bar.dart';

/// 内容设置子页面。
class MobileContentSettingsPage extends StatelessWidget {
  const MobileContentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(context, title: '内容'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const _ContentGroupTitle('歌词'),
            const SizedBox(height: 8),
            M3EList(
              color: theme.colorScheme.surface,
              variant: M3ECardVariant.filled,
              itemCount: 3,
              itemBuilder: (BuildContext context, int index) {
                return switch (index) {
                  0 => const M3EListItem(
                      headline: '歌词来源',
                      supportingText: '选择要启用的歌词来源',
                    ),
                  1 => const M3EListItem(
                      headline: '歌词来源优先级',
                      supportingText: '按照偏好重新排序歌词源优先级',
                    ),
                  _ => const M3EListItem(
                      headline: '重置已导入的歌词',
                      supportingText: '从数据库中移除所有已经导入的歌词',
                    ),
                };
              },
            ),
            const SizedBox(height: 24),
            const _ContentGroupTitle('同步与扫描'),
            const SizedBox(height: 8),
            M3EList(
              color: theme.colorScheme.surface,
              variant: M3ECardVariant.filled,
              itemCount: 1,
              itemBuilder: (BuildContext context, int index) {
                return const M3EListItem(
                  headline: '选择本地媒体库',
                  supportingText: '选择您的音乐文件夹所在的目录',
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                M3EButton(
                  label: const Text('选择媒体库'),
                  onPressed: () {},
                ),
                M3EButton(
                  style: M3EButtonStyle.tonal,
                  label: const Text('同步数据库'),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentGroupTitle extends StatelessWidget {
  const _ContentGroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16),
      child: Text(
        text,
        style: theme.typeScale.titleSmall.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

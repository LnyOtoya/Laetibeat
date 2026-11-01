import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/widgets/settings/song_sort_settings.dart';
import 'package:laetibeat/widgets/settings/song_source_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../widgets/mobile_large_subpage_app_bar.dart';

/// 移动端外观设置子页面。
class MobileAppearanceSettingsPage extends ConsumerWidget {
  const MobileAppearanceSettingsPage({super.key});

  Future<void> _pickSongSource(BuildContext context, WidgetRef ref) async {
    final current = ref.read(defaultSongSourceProvider);
    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: '歌曲来源',
      options: SongSources.all,
      initialSelection: <String>[current],
      icon: const Icon(M3EIcons.library_music),
    );
    if (!context.mounted || picked == null || picked.isEmpty) return;
    ref.read(defaultSongSourceProvider.notifier).setSource(picked.first);
  }

  Future<void> _pickSongSort(BuildContext context, WidgetRef ref) async {
    final current = ref.read(defaultSongSortProvider);
    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: '歌曲排序',
      options: SongSortModes.all,
      initialSelection: <String>[current],
      icon: const Icon(M3EIcons.sort),
    );
    if (!context.mounted || picked == null || picked.isEmpty) return;
    ref.read(defaultSongSortProvider.notifier).setMode(picked.first);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(context, title: '外观'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const _AppearanceGroupTitle('显示'),
            const SizedBox(height: 8),
            M3EList(
              color: theme.colorScheme.surface,
              variant: M3ECardVariant.filled,
              onTap: (int index) {
                if (index == 0) {
                  _pickSongSource(context, ref);
                } else {
                  _pickSongSort(context, ref);
                }
              },
              itemCount: 2,
              itemBuilder: (BuildContext context, int index) {
                return index == 0
                    ? const M3EListItem(
                        headline: '歌曲来源',
                        supportingText: '选择在歌曲列表默认显示的歌曲来源',
                      )
                    : const M3EListItem(
                        headline: '歌曲排序',
                        supportingText: '选择默认的歌曲排序方式',
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceGroupTitle extends StatelessWidget {
  const _AppearanceGroupTitle(this.text);

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

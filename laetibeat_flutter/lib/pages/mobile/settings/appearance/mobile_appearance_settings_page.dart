import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/widgets/settings/song_sort_settings.dart';
import 'package:laetibeat/widgets/settings/song_source_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_locale.dart';
import '../../../../widgets/settings/settings_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';

/// 移动端外观设置子页面。
class MobileAppearanceSettingsPage extends ConsumerWidget {
  const MobileAppearanceSettingsPage({super.key});

  Future<void> _pickSongSource(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(defaultSongSourceProvider);
    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: l10n.songSource,
      options: SongSources.all,
      initialSelection: <String>[current],
      icon: const Icon(M3EIcons.library_music),
    );
    if (!context.mounted || picked == null || picked.isEmpty) return;
    ref.read(defaultSongSourceProvider.notifier).setSource(picked.first);
  }

  Future<void> _pickSongSort(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(defaultSongSortProvider);
    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: l10n.songSort,
      options: SongSortModes.all,
      initialSelection: <String>[current],
      icon: const Icon(M3EIcons.sort),
    );
    if (!context.mounted || picked == null || picked.isEmpty) return;
    ref.read(defaultSongSortProvider.notifier).setMode(picked.first);
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(appLanguageProvider);
    final labels = <String>[
      l10n.languageSystem,
      l10n.languageChinese,
      l10n.languageEnglish,
    ];
    final currentLabel = switch (current) {
      AppLanguage.system => l10n.languageSystem,
      AppLanguage.zh => l10n.languageChinese,
      AppLanguage.en => l10n.languageEnglish,
    };
    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: l10n.languageDialogTitle,
      options: labels,
      initialSelection: <String>[currentLabel],
      icon: const Icon(M3EIcons.translate),
    );
    if (!context.mounted || picked == null || picked.isEmpty) return;
    final index = labels.indexOf(picked.first);
    if (index < 0) return;
    await ref
        .read(appLanguageProvider.notifier)
        .select(AppLanguage.values[index]);
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(appThemeModeProvider);
    final labels = <String>[l10n.themeLight, l10n.themeDark, l10n.themeSystem];
    final currentLabel = switch (current) {
      AppThemeMode.light => l10n.themeLight,
      AppThemeMode.dark => l10n.themeDark,
      AppThemeMode.system => l10n.themeSystem,
    };
    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: l10n.appThemeTitle,
      options: labels,
      initialSelection: <String>[currentLabel],
      icon: const Icon(M3EIcons.brightness_6),
    );
    if (!context.mounted || picked == null || picked.isEmpty) return;
    final index = labels.indexOf(picked.first);
    if (index < 0) return;
    ref.read(appThemeModeProvider.notifier).select(AppThemeMode.values[index]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(context, title: l10n.appearanceTitle),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _AppearanceGroupTitle(l10n.displayGroup),
            const SizedBox(height: 8),
            M3EList(
              color: theme.colorScheme.surface,
              variant: M3ECardVariant.filled,
              onTap: (int index) {
                switch (index) {
                  case 0:
                    _pickTheme(context, ref);
                  case 1:
                    _pickSongSource(context, ref);
                  case 2:
                    _pickSongSort(context, ref);
                  case 3:
                    _pickLanguage(context, ref);
                }
              },
              itemCount: 4,
              itemBuilder: (BuildContext context, int index) {
                return switch (index) {
                  0 => M3EListItem(
                    headline: l10n.appThemeTitle,
                    supportingText: l10n.appThemeSupporting,
                  ),
                  1 => M3EListItem(
                    headline: l10n.songSource,
                    supportingText: l10n.songSourceSupporting,
                  ),
                  2 => M3EListItem(
                    headline: l10n.songSort,
                    supportingText: l10n.songSortSupporting,
                  ),
                  _ => M3EListItem(
                    headline: l10n.language,
                    supportingText: l10n.languageSupporting,
                  ),
                };
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

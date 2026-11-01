import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';

/// 内容设置子页面。
class MobileContentSettingsPage extends StatelessWidget {
  const MobileContentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(context, title: l10n.settingsContent),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _ContentGroupTitle(l10n.lyricsGroup),
            const SizedBox(height: 8),
            M3EList(
              color: theme.colorScheme.surface,
              variant: M3ECardVariant.filled,
              itemCount: 3,
              itemBuilder: (BuildContext context, int index) {
                return switch (index) {
                  0 => M3EListItem(
                    headline: l10n.lyricsSource,
                    supportingText: l10n.lyricsSourceSupporting,
                  ),
                  1 => M3EListItem(
                    headline: l10n.lyricsPriority,
                    supportingText: l10n.lyricsPrioritySupporting,
                  ),
                  _ => M3EListItem(
                    headline: l10n.lyricsReset,
                    supportingText: l10n.lyricsResetSupporting,
                  ),
                };
              },
            ),
            const SizedBox(height: 24),
            _ContentGroupTitle(l10n.syncScanGroup),
            const SizedBox(height: 8),
            M3EList(
              color: theme.colorScheme.surface,
              variant: M3ECardVariant.filled,
              itemCount: 1,
              itemBuilder: (BuildContext context, int index) {
                return M3EListItem(
                  headline: l10n.chooseLocalLibrary,
                  supportingText: l10n.chooseLocalLibrarySupporting,
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                M3EButton(label: Text(l10n.chooseLibrary), onPressed: () {}),
                M3EButton(
                  style: M3EButtonStyle.tonal,
                  label: Text(l10n.syncDatabase),
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

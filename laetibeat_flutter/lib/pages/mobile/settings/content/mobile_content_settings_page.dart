import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../widgets/settings/lyrics_settings.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';

/// 内容设置子页面。
class MobileContentSettingsPage extends ConsumerWidget {
  const MobileContentSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              onTap: (int index) {
                switch (index) {
                  case 0:
                    _showLyricsSources(context, ref);
                  case 1:
                    _showLyricsPriority(context, ref);
                }
              },
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

  Future<void> _showLyricsSources(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(lyricsSettingsProvider);
    final optionSources = <String, LyricsSourceId>{
      _sourceLabel(l10n, LyricsSourceId.tags, includingServer: true):
          LyricsSourceId.tags,
      _sourceLabel(l10n, LyricsSourceId.lrclib): LyricsSourceId.lrclib,
      _sourceLabel(l10n, LyricsSourceId.liriqo): LyricsSourceId.liriqo,
    };
    final options = optionSources.keys.toList(growable: false);
    final initialSelection = <String>[
      for (final source in settings.order)
        if (settings.isEnabled(source))
          _sourceLabel(
            l10n,
            source,
            includingServer: source == LyricsSourceId.tags,
          ),
    ];

    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: l10n.lyricsSource,
      options: options,
      multiSelect: true,
      initialSelection: initialSelection,
      icon: const Icon(M3EIcons.lyrics),
    );
    if (picked == null) return;

    final enabled = <LyricsSourceId>{
      for (final value in picked)
        if (optionSources[value] != null) optionSources[value]!,
    };
    await ref.read(lyricsSettingsProvider.notifier).setEnabled(enabled);
  }

  Future<void> _showLyricsPriority(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _LyricsPrioritySheet(
          initialOrder: ref.read(lyricsSettingsProvider).order,
          onChanged: (order) =>
              ref.read(lyricsSettingsProvider.notifier).setOrder(order),
        );
      },
    );
  }
}

String _sourceLabel(
  AppLocalizations l10n,
  LyricsSourceId source, {
  bool includingServer = false,
}) {
  return switch (source) {
    LyricsSourceId.tags =>
      includingServer
          ? l10n.lyricsSourceTagsIncludingServer
          : l10n.lyricsSourceTags,
    LyricsSourceId.lrclib => l10n.lyricsSourceLrclib,
    LyricsSourceId.liriqo => l10n.lyricsSourceLiriqo,
  };
}

class _LyricsPrioritySheet extends StatefulWidget {
  const _LyricsPrioritySheet({
    required this.initialOrder,
    required this.onChanged,
  });

  final List<LyricsSourceId> initialOrder;
  final ValueChanged<List<LyricsSourceId>> onChanged;

  @override
  State<_LyricsPrioritySheet> createState() => _LyricsPrioritySheetState();
}

class _LyricsPrioritySheetState extends State<_LyricsPrioritySheet> {
  late final List<LyricsSourceId> _order = List<LyricsSourceId>.of(
    widget.initialOrder,
  );

  void _handleReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    setState(() {
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
    widget.onChanged(List<LyricsSourceId>.unmodifiable(_order));
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(theme.spacing.lg),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            theme.spacing.lg,
            theme.spacing.md,
            theme.spacing.md,
            theme.spacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.lyricsPriority,
                      style: theme.typeScale.titleLarge,
                    ),
                  ),
                  M3EIconButton(
                    size: M3EIconButtonSize.xs,
                    icon: const Icon(M3EIcons.close),
                    tooltip: l10n.closeLyricsPriority,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                l10n.lyricsPriorityHint,
                style: theme.typeScale.bodySmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              M3EList.scrollable(
                shrinkWrap: true,
                reorder: true,
                onReorder: _handleReorder,
                itemCount: _order.length,
                itemBuilder: (BuildContext context, int index) {
                  final source = _order[index];
                  return M3EListItem(
                    headline: _sourceLabel(
                      l10n,
                      source,
                      includingServer: source == LyricsSourceId.tags,
                    ),
                    trailing: Icon(
                      M3EIcons.drag_handle,
                      color: scheme.onSurfaceVariant,
                      semanticLabel: l10n.lyricsReorderHandle,
                    ),
                  );
                },
              ),
            ],
          ),
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

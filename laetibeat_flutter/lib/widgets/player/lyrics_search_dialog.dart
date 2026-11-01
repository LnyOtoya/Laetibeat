import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:laetibeat/src/rust/api/lyrics.dart' as rust_lyrics;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

import '../../l10n/generated/app_localizations.dart';
import 'lyric_provider.dart';

/// 打开“搜索歌词”流程：输入歌名/艺术家 -> 选择结果 -> 应用到当前曲目。
Future<void> showLyricsSearchDialog(
  BuildContext context,
  WidgetRef ref,
  rust.UiTrack track,
) async {
  final query = await M3EDialog.show<_LyricsQuery>(
    context,
    dialog: _LyricsSearchQueryDialog(
      initialTitle: track.title,
      initialArtist: track.artist,
    ),
  );
  if (query == null || !context.mounted) return;

  final result = await M3EDialog.show<rust_lyrics.UiLyricsSearchResult>(
    context,
    dialog: _LyricsSearchResultsDialog(
      title: query.title,
      artist: query.artist,
      durationSeconds: track.durationSeconds.toInt(),
    ),
  );
  if (result == null) return;

  ref.read(lyricsOverridesProvider.notifier).apply(track, result.text);
}

class _LyricsQuery {
  const _LyricsQuery({required this.title, required this.artist});

  final String title;
  final String artist;
}

class _LyricsSearchQueryDialog extends StatefulWidget {
  const _LyricsSearchQueryDialog({
    required this.initialTitle,
    required this.initialArtist,
  });

  final String initialTitle;
  final String initialArtist;

  @override
  State<_LyricsSearchQueryDialog> createState() =>
      _LyricsSearchQueryDialogState();
}

class _LyricsSearchQueryDialogState extends State<_LyricsSearchQueryDialog> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.initialTitle,
  );
  late final TextEditingController _artistController = TextEditingController(
    text: widget.initialArtist,
  );

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return M3EDialog(
      title: l10n.searchLyrics,
      icon: const Icon(M3EIcons.search),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            M3ETextField(
              controller: _titleController,
              label: l10n.lyricsSearchTitleLabel,
              placeholder: l10n.lyricsSearchTitleLabel,
              textInputAction: TextInputAction.next,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            M3ETextField(
              controller: _artistController,
              label: l10n.lyricsSearchArtistLabel,
              placeholder: l10n.lyricsSearchArtistLabel,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
      actions: [
        M3EButton(
          label: Text(l10n.lyricsSearchCancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        M3EButton(
          label: Text(l10n.lyricsSearchConfirm),
          onPressed: () {
            final title = _titleController.text.trim();
            final artist = _artistController.text.trim();
            if (title.isEmpty && artist.isEmpty) return;
            Navigator.of(
              context,
            ).pop(_LyricsQuery(title: title, artist: artist));
          },
        ),
      ],
    );
  }
}

class _LyricsSearchResultsDialog extends StatefulWidget {
  const _LyricsSearchResultsDialog({
    required this.title,
    required this.artist,
    required this.durationSeconds,
  });

  final String title;
  final String artist;
  final int durationSeconds;

  @override
  State<_LyricsSearchResultsDialog> createState() =>
      _LyricsSearchResultsDialogState();
}

class _LyricsSearchResultsDialogState
    extends State<_LyricsSearchResultsDialog> {
  late final Future<List<rust_lyrics.UiLyricsSearchResult>> _future =
      rust_lyrics.searchLyrics(
        title: widget.title,
        artist: widget.artist,
        durationSeconds: widget.durationSeconds,
      );
  final Set<String> _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return M3EDialog(
      title: l10n.searchLyrics,
      icon: const Icon(M3EIcons.search),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: FutureBuilder<List<rust_lyrics.UiLyricsSearchResult>>(
            future: _future,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<rust_lyrics.UiLyricsSearchResult>>
                  snapshot,
                ) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: M3EProgressIndicator.circular()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.lyricsSearchFailed,
                        style: M3ETheme.of(context).typeScale.bodyMedium,
                      ),
                    );
                  }
                  final results =
                      snapshot.data ??
                      const <rust_lyrics.UiLyricsSearchResult>[];
                  if (results.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.lyricsSearchNoResults,
                        style: M3ETheme.of(context).typeScale.bodyMedium,
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final result = results[index];
                      final expanded = _expanded.contains(result.id);
                      return _LyricsResultCard(
                        result: result,
                        expanded: expanded,
                        onToggle: () {
                          setState(() {
                            if (expanded) {
                              _expanded.remove(result.id);
                            } else {
                              _expanded.add(result.id);
                            }
                          });
                        },
                        onApply: () => Navigator.of(context).pop(result),
                      );
                    },
                  );
                },
          ),
        ),
      ),
      actions: [
        M3EButton(
          label: Text(l10n.lyricsSearchCancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _LyricsResultCard extends StatelessWidget {
  const _LyricsResultCard({
    required this.result,
    required this.expanded,
    required this.onToggle,
    required this.onApply,
  });

  final rust_lyrics.UiLyricsSearchResult result;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;
    final preview = _lyricsLines(result.text);
    final previewText = preview.take(2).join('\n');

    return M3ECard(
      variant: M3ECardVariant.filled,
      color: scheme.surfaceContainerHigh,
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onApply,
                  child: Text(
                    expanded ? preview.join('\n') : previewText,
                    maxLines: expanded ? null : 2,
                    overflow: expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: theme.typeScale.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              M3EIconButton(
                size: M3EIconButtonSize.xs,
                icon: Icon(
                  expanded ? M3EIcons.expand_less : M3EIcons.expand_more,
                ),
                tooltip: expanded
                    ? l10n.lyricsSearchCollapse
                    : l10n.lyricsSearchShowMore,
                onPressed: onToggle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onApply,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    result.provider.isEmpty ? result.source : result.provider,
                    style: theme.typeScale.labelMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (result.synced)
                  Icon(
                    M3EIcons.music_note,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _lyricsLines(String text) {
  final cleaned = text
      .replaceAll(RegExp(r'^\[[^\]]+\]\s*$', multiLine: true), '')
      .replaceAll(RegExp(r'\[\d+,\d+\]'), '')
      .replaceAll(RegExp(r'\(\d+,\d+\)'), '')
      .replaceAll(RegExp(r'\[\d{1,}:\d{2}(?:[.:]\d{1,})?\]'), '');
  return cleaned
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

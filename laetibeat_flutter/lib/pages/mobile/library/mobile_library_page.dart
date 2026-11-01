import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../widgets/mobile_app_bar.dart';
import 'views/albums_library_view.dart';
import 'views/artists_library_view.dart';
import 'views/playlists_library_view.dart';
import 'views/songs_library_view.dart';

/// 移动端音乐库页面。
class MobileLibraryPage extends StatefulWidget {
  const MobileLibraryPage({super.key});

  @override
  State<MobileLibraryPage> createState() => _MobileLibraryPageState();
}

class _MobileLibraryPageState extends State<MobileLibraryPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    M3EButtonGroupAction action(IconData icon, String label) {
      return M3EButtonGroupAction(
        icon: Icon(icon),
        label: Text(label),
        decoration: M3EButtonDecoration(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            return states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surfaceContainerHigh;
          }),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileTopAppBar(
        context,
        title: mobileTopAppBarTitle(context, l10n.libraryTitle),
        actions: mobileHomeAppBarActions(context),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: M3EButtonGroup(
                type: M3EButtonGroupType.standard,
                shape: M3EButtonShape.round,
                size: M3EButtonSize.sm,
                style: M3EButtonStyle.filled,
                multiSelect: false,
                selectionRequired: true,
                neighborSquish: true,
                overflow: M3EButtonGroupOverflow.scroll,
                selectedIndex: _selectedIndex,
                onSelectedIndexChanged: (int? index) {
                  if (index == null) return;
                  setState(() => _selectedIndex = index);
                },
                actions: [
                  action(M3EIcons.music_note, l10n.librarySongs),
                  action(M3EIcons.queue_music, l10n.libraryPlaylists),
                  action(M3EIcons.person, l10n.libraryArtists),
                  action(M3EIcons.album, l10n.libraryAlbums),
                  action(M3EIcons.podcasts, l10n.libraryPodcasts),
                ],
              ),
            ),
            Expanded(child: _buildContent(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    return switch (_selectedIndex) {
      0 => const SongsLibraryView(),
      1 => const PlaylistsLibraryView(),
      2 => const ArtistsLibraryView(),
      3 => const AlbumsLibraryView(),
      _ => _LibraryPlaceholder(l10n.libraryPodcasts),
    };
  }
}

class _LibraryPlaceholder extends StatelessWidget {
  const _LibraryPlaceholder(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Center(child: Text(label, style: theme.typeScale.headlineSmall));
  }
}

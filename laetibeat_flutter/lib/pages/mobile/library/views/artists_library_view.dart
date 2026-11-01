import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';

import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../artists/artist_detail_page.dart';
import '../widgets/library_layout_control_bar.dart';

/// 艺术家分类内容。数据来自 OpenSubsonic。
class ArtistsLibraryView extends ConsumerStatefulWidget {
  const ArtistsLibraryView({super.key});

  @override
  ConsumerState<ArtistsLibraryView> createState() => _ArtistsLibraryViewState();
}

class _ArtistsLibraryViewState extends ConsumerState<ArtistsLibraryView> {
  bool _isGrid = true;

  void _openArtist(String sourceId, rust_subsonic.UiRemoteArtist artist) {
    pushMobileRootPage(
      context,
      ArtistDetailPage(sourceId: sourceId, artist: artist),
      name: MobileRoutes.artistDetail,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LibraryLayoutControlBar(
          isGrid: _isGrid,
          onToggleLayout: () => setState(() => _isGrid = !_isGrid),
        ),
        Expanded(child: _buildContent(theme, bottomInset)),
      ],
    );
  }

  Widget _buildContent(M3EThemeData theme, double bottomInset) {
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    if (servers.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).configureSubsonicFirst),
      );
    }

    final server = servers.first;
    final artists = ref.watch(remoteArtistsProvider(server.id));
    return artists.when(
      loading: () => Center(
        child: M3ELoadingIndicator(
          color: theme.colorScheme.primary,
          containerColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ),
      error: (Object error, StackTrace stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${AppLocalizations.of(context).loadArtistsFailed}\n$error',
            textAlign: TextAlign.center,
            style: theme.typeScale.bodyMedium.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context).noArtists));
        }
        return _isGrid
            ? _buildGrid(theme, server.id, list, bottomInset)
            : _buildList(theme, server.id, list, bottomInset);
      },
    );
  }

  Widget _buildGrid(
    M3EThemeData theme,
    String sourceId,
    List<rust_subsonic.UiRemoteArtist> artists,
    double bottomInset,
  ) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: artists.length,
      itemBuilder: (BuildContext context, int index) {
        final artist = artists[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openArtist(sourceId, artist),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: _ArtistCover(
                  sourceId: sourceId,
                  coverId: artist.coverId,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                _formatAlbumCount(artist.albumCount?.toInt()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(
    M3EThemeData theme,
    String sourceId,
    List<rust_subsonic.UiRemoteArtist> artists,
    double bottomInset,
  ) {
    return M3EList.scrollable(
      color: theme.colorScheme.surface,
      variant: M3ECardVariant.filled,
      itemCount: artists.length,
      onTap: (int index) => _openArtist(sourceId, artists[index]),
      listPadding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      itemBuilder: (BuildContext context, int index) {
        final artist = artists[index];
        return M3EListItem(
          leading: SizedBox.square(
            dimension: 40,
            child: _ArtistCover(sourceId: sourceId, coverId: artist.coverId),
          ),
          headline: artist.name,
          trailingText: _formatAlbumCount(artist.albumCount?.toInt()),
        );
      },
    );
  }

  String _formatAlbumCount(int? count) {
    if (count == null || count < 0) return '--';
    return '$count 张专辑';
  }
}

class _ArtistCover extends ConsumerWidget {
  const _ArtistCover({required this.sourceId, required this.coverId});

  final String sourceId;
  final String? coverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final id = coverId;
    final bytes = id == null || id.isEmpty
        ? null
        : ref
              .watch(remoteCoverProvider((sourceId: sourceId, coverId: id)))
              .value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipOval(
      child: hasArt
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            )
          : ColoredBox(
              color: theme.colorScheme.secondaryContainer,
              child: Center(
                child: Icon(
                  M3EIcons.person,
                  size: 28,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
    );
  }
}

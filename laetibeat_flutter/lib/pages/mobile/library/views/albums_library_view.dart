import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../albums/album_detail_page.dart';
import '../widgets/library_layout_control_bar.dart';

/// 专辑分类内容。数据来自 OpenSubsonic。
class AlbumsLibraryView extends ConsumerStatefulWidget {
  const AlbumsLibraryView({super.key});

  @override
  ConsumerState<AlbumsLibraryView> createState() => _AlbumsLibraryViewState();
}

class _AlbumsLibraryViewState extends ConsumerState<AlbumsLibraryView> {
  bool _isGrid = true;

  void _openAlbum(String sourceId, rust_subsonic.UiRemoteAlbum album) {
    pushMobileRootPage(
      context,
      AlbumDetailPage(sourceId: sourceId, album: album),
      name: MobileRoutes.albumDetail,
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
      return const Center(child: Text('请先配置 Subsonic 音源'));
    }

    final server = servers.first;
    final albums = ref.watch(remoteAllAlbumsProvider(server.id));
    return albums.when(
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
            '读取专辑失败\n$error',
            textAlign: TextAlign.center,
            style: theme.typeScale.bodyMedium.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('还没有专辑'));
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
    List<rust_subsonic.UiRemoteAlbum> albums,
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
      itemCount: albums.length,
      itemBuilder: (BuildContext context, int index) {
        final album = albums[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openAlbum(sourceId, album),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: _AlbumCover(sourceId: sourceId, coverId: album.coverId),
              ),
              const SizedBox(height: 8),
              Text(
                album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                album.artist,
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
    List<rust_subsonic.UiRemoteAlbum> albums,
    double bottomInset,
  ) {
    return M3EList.scrollable(
      color: theme.colorScheme.surface,
      variant: M3ECardVariant.filled,
      itemCount: albums.length,
      onTap: (int index) => _openAlbum(sourceId, albums[index]),
      listPadding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      itemBuilder: (BuildContext context, int index) {
        final album = albums[index];
        return M3EListItem(
          leading: SizedBox.square(
            dimension: 40,
            child: _AlbumCover(sourceId: sourceId, coverId: album.coverId),
          ),
          headline: album.title,
          supportingText: album.artist,
          trailingText: _formatSongCount(album.songCount?.toInt()),
        );
      },
    );
  }

  String _formatSongCount(int? count) {
    if (count == null || count < 0) return '--';
    return '$count 首';
  }
}

class _AlbumCover extends ConsumerWidget {
  const _AlbumCover({required this.sourceId, required this.coverId});

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

    return M3EShapeContainer.cookie12Sided(
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
                  M3EIcons.album,
                  size: 28,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
    );
  }
}

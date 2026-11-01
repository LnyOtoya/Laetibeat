import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/library_layout_control_bar.dart';

/// 歌单分类内容。
///
/// 歌单数据来自已配置的 OpenSubsonic 服务器。
class PlaylistsLibraryView extends ConsumerStatefulWidget {
  const PlaylistsLibraryView({super.key});

  @override
  ConsumerState<PlaylistsLibraryView> createState() =>
      _PlaylistsLibraryViewState();
}

class _PlaylistsLibraryViewState extends ConsumerState<PlaylistsLibraryView> {
  bool _isGrid = true;

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
    final playlists = ref.watch(remotePlaylistsProvider(server.id));
    return playlists.when(
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
            '读取歌单失败\n$error',
            textAlign: TextAlign.center,
            style: theme.typeScale.bodyMedium.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('还没有歌单'));
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
    List<rust_subsonic.UiRemotePlaylist> playlists,
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
      itemCount: playlists.length,
      itemBuilder: (BuildContext context, int index) {
        final playlist = playlists[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: _PlaylistCover(
                  sourceId: sourceId,
                  coverId: playlist.coverId,
                  radius: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                _formatSongCount(playlist.songCount?.toInt()),
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
    List<rust_subsonic.UiRemotePlaylist> playlists,
    double bottomInset,
  ) {
    return M3EList.scrollable(
      color: theme.colorScheme.surface,
      variant: M3ECardVariant.filled,
      itemCount: playlists.length,
      listPadding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      itemBuilder: (BuildContext context, int index) {
        final playlist = playlists[index];
        return M3EListItem(
          leading: SizedBox.square(
            dimension: 40,
            child: _PlaylistCover(
              sourceId: sourceId,
              coverId: playlist.coverId,
              radius: 8,
            ),
          ),
          headline: playlist.name,
          trailingText: _formatSongCount(playlist.songCount?.toInt()),
        );
      },
    );
  }

  String _formatSongCount(int? count) {
    if (count == null || count < 0) return '--';
    return '$count 首';
  }
}

/// OpenSubsonic 歌单封面；无封面时显示占位图标。
class _PlaylistCover extends ConsumerWidget {
  const _PlaylistCover({
    required this.sourceId,
    required this.coverId,
    required this.radius,
  });

  final String sourceId;
  final String? coverId;
  final double radius;

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

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
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
                  M3EIcons.queue_music,
                  size: 28,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:material_3_expressive/material_3_expressive.dart';

import 'player/player_provider.dart';
import 'remote_browser_provider.dart';

/// 远端音乐库:艺术家 → 专辑 → 曲目,全部按需加载。
class RemoteLibraryView extends ConsumerStatefulWidget {
  const RemoteLibraryView({
    super.key,
    required this.sourceId,
    required this.serverName,
  });

  final String sourceId;
  final String serverName;

  @override
  ConsumerState<RemoteLibraryView> createState() => _RemoteLibraryViewState();
}

class _RemoteLibraryViewState extends ConsumerState<RemoteLibraryView> {
  rust_subsonic.UiRemoteArtist? _artist;
  rust_subsonic.UiRemoteAlbum? _album;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    if (_album != null) return _buildTracks(theme);
    if (_artist != null) return _buildAlbums(theme);
    return _buildArtists(theme);
  }

  Widget _buildArtists(M3EThemeData theme) {
    final artists = ref.watch(remoteArtistsProvider(widget.sourceId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          theme: theme,
          title: widget.serverName,
          subtitle: '远端艺术家',
        ),
        SizedBox(height: theme.spacing.md),
        Expanded(
          child: artists.when(
            loading: () => _loading(theme),
            error: (error, _) => _error(theme, error),
            data: (list) => list.isEmpty
                ? _empty(theme, '服务器上还没有艺术家')
                : M3EList.scrollable(
                    itemCount: list.length,
                    onTap: (index) =>
                        setState(() => _artist = list[index]),
                    itemBuilder: (context, index) {
                      final artist = list[index];
                      return M3EListItem(
                        leading: _leadingIcon(theme, Icons.person),
                        headline: artist.name,
                        supportingText: artist.albumCount == null
                            ? null
                            : '${artist.albumCount!.toInt()} 张专辑',
                        trailing: const Icon(Icons.chevron_right),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbums(M3EThemeData theme) {
    final artist = _artist!;
    final albums = ref.watch(
      remoteAlbumsProvider(
        (sourceId: widget.sourceId, artistId: artist.id),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          theme: theme,
          title: artist.name,
          subtitle: '专辑',
          onBack: () => setState(() => _artist = null),
        ),
        SizedBox(height: theme.spacing.md),
        Expanded(
          child: albums.when(
            loading: () => _loading(theme),
            error: (error, _) => _error(theme, error),
            data: (list) => list.isEmpty
                ? _empty(theme, '这位艺术家还没有专辑')
                : M3EList.scrollable(
                    itemCount: list.length,
                    onTap: (index) =>
                        setState(() => _album = list[index]),
                    itemBuilder: (context, index) {
                      final album = list[index];
                      return M3EListItem(
                        leading: _leadingIcon(theme, Icons.album),
                        headline: album.title,
                        supportingText: [
                          album.artist,
                          if (album.year != null) '${album.year}',
                        ].join(' · '),
                        trailing: album.songCount == null
                            ? null
                            : Text(
                                '${album.songCount!.toInt()} 首',
                                style: theme.typeScale.bodySmall.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTracks(M3EThemeData theme) {
    final album = _album!;
    final tracks = ref.watch(
      remoteTracksProvider(
        (sourceId: widget.sourceId, albumId: album.id),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          theme: theme,
          title: album.title,
          subtitle: '${album.artist} · 曲目',
          onBack: () => setState(() => _album = null),
        ),
        SizedBox(height: theme.spacing.md),
        Expanded(
          child: tracks.when(
            loading: () => _loading(theme),
            error: (error, _) => _error(theme, error),
            data: (list) => list.isEmpty
                ? _empty(theme, '这张专辑还没有曲目')
                : M3EList.scrollable(
                    itemCount: list.length,
                    onTap: (index) => _play(list, index),
                    itemBuilder: (context, index) {
                      final track = list[index];
                      return M3EListItem(
                        leading: _leadingIcon(theme, Icons.music_note),
                        headline: track.title,
                        supportingText: track.artist,
                        trailing: Text(
                          _formatDuration(track.durationSeconds.toInt()),
                          style: theme.typeScale.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _play(List<rust_subsonic.UiRemoteTrack> tracks, int index) {
    final queue = <rust.UiTrack>[
      for (final track in tracks) _toUiTrack(track),
    ];
    ref.read(playerProvider.notifier).load(
          queue,
          index,
          source: widget.serverName,
        );
  }

  rust.UiTrack _toUiTrack(rust_subsonic.UiRemoteTrack track) {
    final seconds = track.durationSeconds.toInt();
    return rust.UiTrack(
      id: track.id,
      relativePath: null,
      title: track.title,
      artist: track.artist,
      album: track.album,
      albumArtist: track.artist,
      albumId: track.albumId ?? '',
      artistId: track.artistId ?? '',
      trackNumber: track.trackNumber,
      discNumber: track.discNumber,
      year: track.year,
      genre: track.genre,
      duration: _formatDuration(seconds),
      durationSeconds: BigInt.from(seconds),
      path: '',
      source: 'opensubsonic',
      sourceId: widget.sourceId,
      coverId: track.coverId,
      bitrate: track.bitRate,
      sampleRate: null,
      channels: null,
      modifiedMs: null,
      fileSize: track.size == null ? null : BigInt.from(track.size!.toInt()),
    );
  }

  Widget _header({
    required M3EThemeData theme,
    required String title,
    required String subtitle,
    VoidCallback? onBack,
  }) {
    return Row(
      children: [
        if (onBack != null) ...[
          M3EIconButton(
            size: M3EIconButtonSize.xs,
            icon: const Icon(Icons.arrow_back),
            tooltip: '返回',
            onPressed: onBack,
          ),
          SizedBox(width: theme.spacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.titleLarge,
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _leadingIcon(M3EThemeData theme, IconData icon) {
    return M3EShapeContainer.square(
      width: theme.spacing.xxl * 1.5,
      height: theme.spacing.xxl * 1.5,
      color: theme.colorScheme.secondaryContainer,
      child: Icon(icon, size: 20),
    );
  }

  Widget _loading(M3EThemeData theme) {
    return Center(
      child: M3ELoadingIndicator(
        color: theme.colorScheme.primary,
        containerColor: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _error(M3EThemeData theme, Object error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 40,
              color: theme.colorScheme.error,
            ),
            SizedBox(height: theme.spacing.md),
            Text('无法加载远端音乐', style: theme.typeScale.titleMedium),
            SizedBox(height: theme.spacing.xs),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: theme.typeScale.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(M3EThemeData theme, String message) {
    return Center(
      child: Text(
        message,
        style: theme.typeScale.bodyMedium.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }
}

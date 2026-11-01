import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:laetibeat/widgets/settings/song_sort_settings.dart';
import 'package:laetibeat/widgets/settings/song_source_settings.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// 歌曲分类内容。
class SongsLibraryView extends ConsumerStatefulWidget {
  const SongsLibraryView({super.key});

  @override
  ConsumerState<SongsLibraryView> createState() => _SongsLibraryViewState();
}

class _SongsLibraryViewState extends ConsumerState<SongsLibraryView> {
  static const String _localSource = SongSources.local;
  static const String _subsonicSource = SongSources.subsonic;

  late String _selectedSource;
  final Set<String> _selectedTrackIds = <String>{};
  final Set<String> _dismissedTrackIds = <String>{};
  late final M3EToolbarVisibilityController _toolbarVisibilityController;
  late final M3EToolbarScrollBehavior _toolbarScrollBehavior;

  @override
  void initState() {
    super.initState();
    _selectedSource = ref.read(defaultSongSourceProvider);
    _toolbarVisibilityController = M3EToolbarVisibilityController();
    _toolbarScrollBehavior = M3EToolbarScrollBehavior.exitAlways(
      exitDirection: M3EToolbarExitDirection.top,
      controller: _toolbarVisibilityController,
    );
  }

  @override
  void dispose() {
    _toolbarVisibilityController.dispose();
    super.dispose();
  }

  void _clearSelection() {
    if (_selectedTrackIds.isEmpty) return;
    setState(_selectedTrackIds.clear);
  }

  void _toggleSelection(String trackId) {
    setState(() {
      if (!_selectedTrackIds.add(trackId)) {
        _selectedTrackIds.remove(trackId);
      }
    });
    if (_selectedTrackIds.isNotEmpty) {
      _toolbarVisibilityController.show();
    }
  }

  void _dismissTrack(String trackId) {
    setState(() {
      _dismissedTrackIds.add(trackId);
      _selectedTrackIds.remove(trackId);
    });
  }

  List<rust.UiTrack> _currentTracks() {
    if (_selectedSource == _localSource) {
      final tracks =
          (ref.read(musicLibraryProvider).value?.tracks ??
                  const <rust.UiTrack>[])
              .where((track) => !_dismissedTrackIds.contains(track.id))
              .toList(growable: false);
      return sortTracksByMode(tracks, ref.read(defaultSongSortProvider));
    }
    if (_selectedSource == _subsonicSource) {
      final servers =
          ref.read(subsonicServersProvider).value ??
          const <SubsonicServerConfig>[];
      if (servers.isEmpty) return const <rust.UiTrack>[];
      final server = servers.first;
      final remote =
          ref.read(remoteAllTracksProvider(server.id)).value ?? const [];
      final tracks = remote
          .map((track) => remoteTrackToUiTrack(track, server.id))
          .where((track) => !_dismissedTrackIds.contains(track.id))
          .toList(growable: false);
      return sortTracksByMode(tracks, ref.read(defaultSongSortProvider));
    }
    return const <rust.UiTrack>[];
  }

  void _playTracks(List<rust.UiTrack> tracks, int index) {
    if (tracks.isEmpty) return;
    ref
        .read(playerProvider.notifier)
        .load(tracks, index, source: _selectedSource);
  }

  void _playRandom() {
    final tracks = _currentTracks();
    if (tracks.isEmpty) return;
    ref
        .read(playerProvider.notifier)
        .playShuffled(tracks, source: _selectedSource);
  }

  List<rust.UiTrack> _selectedTracksInOrder() {
    final selected = _currentTracks()
        .where((track) => _selectedTrackIds.contains(track.id))
        .toList(growable: false);
    return selected;
  }

  void _playSelectedNow() {
    final tracks = _selectedTracksInOrder();
    if (tracks.isEmpty) return;
    ref
        .read(playerProvider.notifier)
        .load(tracks, 0, source: _selectedSource, shuffle: false);
    _clearSelection();
  }

  void _playSelectedNext() {
    final tracks = _selectedTracksInOrder();
    if (tracks.isEmpty) return;
    ref.read(playerProvider.notifier).insertNext(tracks);
    _clearSelection();
  }

  void _selectSource(String source) {
    if (source == _selectedSource) return;
    setState(() {
      _selectedSource = source;
      _selectedTrackIds.clear();
      _dismissedTrackIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(defaultSongSourceProvider, (
      String? previous,
      String next,
    ) {
      if (next == _selectedSource) return;
      setState(() {
        _selectedSource = next;
        _selectedTrackIds.clear();
        _dismissedTrackIds.clear();
      });
    });

    final theme = M3ETheme.of(context);
    ref.watch(defaultSongSortProvider);
    final localState = ref.watch(musicLibraryProvider).value;
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final server = servers.isEmpty ? null : servers.first;
    final selectionActive = _selectedTrackIds.isNotEmpty;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  M3EButton.icon(
                    icon: const Icon(M3EIcons.shuffle),
                    label: const Text('随机播放'),
                    style: M3EButtonStyle.filled,
                    size: M3EButtonSize.sm,
                    shape: M3EButtonShape.round,
                    onPressed: _playRandom,
                  ),
                  const Spacer(),
                  M3ESplitButton<String>(
                    items: const [],
                    label: '排序',
                    leadingIcon: M3EIcons.sort,
                    style: M3EButtonStyle.tonal,
                    size: M3EButtonSize.sm,
                    shape: M3EButtonShape.round,
                    trailingTooltip: '当前音源：$_selectedSource',
                    selectedValue: _selectedSource,
                    decoration: const M3ESplitButtonDecoration(
                      menuStyle: M3ESplitButtonMenuStyle.popup,
                    ),
                    onPressed: _showSortSheet,
                    m3eMenuBuilder: (BuildContext context) {
                      return [
                        M3EMenuSelectable(
                          label: _localSource,
                          value: _localSource,
                          selected: _selectedSource == _localSource,
                        ),
                        M3EMenuSelectable(
                          label: _subsonicSource,
                          value: _subsonicSource,
                          selected: _selectedSource == _subsonicSource,
                          enabled: server != null,
                          supportingText: server?.baseUrl ?? '未配置',
                        ),
                        for (final source in const [
                          SongSources.jellyfin,
                          SongSources.emby,
                          SongSources.lx,
                          SongSources.qq,
                          SongSources.netease,
                        ])
                          M3EMenuSelectable(
                            label: source,
                            value: source,
                            selected: _selectedSource == source,
                            enabled: false,
                            supportingText: '暂未提供',
                          ),
                      ];
                    },
                    onSelected: _selectSource,
                  ),
                ],
              ),
            ),
            Expanded(child: _buildSongContent(theme, localState, server)),
          ],
        ),
        if (selectionActive)
          Positioned(
            top: 56,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: M3EToolbar.floating(
                colorStyle: M3EToolbarColorStyle.standard,
                axis: Axis.horizontal,
                alignment: Alignment.topCenter,
                expanded: true,
                maxInlineActions: 2,
                screenOffset: 24,
                scrollBehavior: _toolbarScrollBehavior,
                leading: M3EToolbarIconButton(
                  action: M3EToolbarAction(
                    icon: M3EIcons.close,
                    tooltip: '退出选择',
                    onPressed: _clearSelection,
                  ),
                  size: M3EIconButtonSize.sm,
                  colorStyle: M3EToolbarColorStyle.standard,
                ),
                actions: <M3EToolbarItem>[
                  M3EToolbarAction(
                    icon: M3EIcons.play_arrow,
                    tooltip: '立即播放',
                    onPressed: _playSelectedNow,
                  ),
                  M3EToolbarAction(
                    icon: M3EIcons.queue_play_next,
                    tooltip: '下一首播放',
                    onPressed: _playSelectedNext,
                  ),
                  M3EToolbarAction(
                    icon: M3EIcons.playlist_add,
                    tooltip: '添加到歌单',
                    onPressed: () {},
                  ),
                  M3EToolbarWidget(
                    child: M3EIconButton(
                      variant: M3EIconButtonVariant.tonal,
                      shape: M3EIconButtonShapeVariant.round,
                      icon: const Icon(M3EIcons.favorite_border),
                      tooltip: '添加到喜欢',
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showSortSheet() async {
    final current = ref.read(defaultSongSortProvider);
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final theme = M3ETheme.of(sheetContext);
        final scheme = theme.colorScheme;
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
                        child: Text('排序方式', style: theme.typeScale.titleLarge),
                      ),
                      M3EIconButton(
                        size: M3EIconButtonSize.xs,
                        icon: const Icon(M3EIcons.close),
                        tooltip: '关闭排序方式',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: theme.spacing.sm),
                  M3EList.scrollable(
                    shrinkWrap: true,
                    itemCount: SongSortModes.all.length,
                    onTap: (int index) => Navigator.of(
                      sheetContext,
                    ).pop(SongSortModes.all[index]),
                    itemBuilder: (BuildContext context, int index) {
                      final mode = SongSortModes.all[index];
                      final selected = mode == current;
                      return M3EListItem(
                        selected: selected,
                        headline: mode,
                        trailing: selected
                            ? Icon(M3EIcons.check, color: scheme.primary)
                            : null,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    ref.read(defaultSongSortProvider.notifier).setMode(picked);
  }

  Widget _buildSongContent(
    M3EThemeData theme,
    MusicLibraryState? localState,
    SubsonicServerConfig? server,
  ) {
    if (_selectedSource == _localSource) {
      final tracks = (localState?.tracks ?? const <rust.UiTrack>[])
          .where((track) => !_dismissedTrackIds.contains(track.id))
          .toList(growable: false);
      return _buildTrackList(theme, tracks, '暂无歌曲');
    }

    if (_selectedSource == _subsonicSource) {
      if (server == null) {
        return const Center(child: Text('请先配置 Subsonic 音源'));
      }

      final remote = ref.watch(remoteAllTracksProvider(server.id));
      return remote.when(
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
              '读取远端歌曲失败\n$error',
              textAlign: TextAlign.center,
              style: theme.typeScale.bodyMedium.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ),
        data: (remoteTracks) {
          final tracks = remoteTracks
              .map((track) => remoteTrackToUiTrack(track, server.id))
              .where((track) => !_dismissedTrackIds.contains(track.id))
              .toList(growable: false);
          return _buildTrackList(theme, tracks, '还没有远端歌曲，请先在内容设置中扫描');
        },
      );
    }

    return Center(child: Text('$_selectedSource暂未提供'));
  }

  Widget _buildTrackList(
    M3EThemeData theme,
    List<rust.UiTrack> inputTracks,
    String emptyText,
  ) {
    final tracks = sortTracksByMode(
      inputTracks,
      ref.read(defaultSongSortProvider),
    );
    final selectionActive = _selectedTrackIds.isNotEmpty;
    final scheme = theme.colorScheme;
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return M3EToolbarScrollWrapper(
      behavior: _toolbarScrollBehavior,
      child: M3EList.scrollable(
        color: scheme.surface,
        variant: M3ECardVariant.filled,
        itemCount: tracks.length,
        listPadding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        emptyBuilder: Center(child: Text(emptyText)),
        colorBuilder: (int index) {
          return _selectedTrackIds.contains(tracks[index].id)
              ? scheme.secondaryContainer
              : scheme.surface;
        },
        borderRadiusBuilder: (int index, M3ECardPosition position) {
          return _selectedTrackIds.contains(tracks[index].id)
              ? BorderRadius.circular(16)
              : null;
        },
        itemBuilder: (BuildContext context, int index) {
          final track = tracks[index];
          final selected = _selectedTrackIds.contains(track.id);

          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () => _toggleSelection(track.id),
                onTap: selectionActive
                    ? () => _toggleSelection(track.id)
                    : () => _playTracks(tracks, index),
                child: M3EListItem(
                  selected: selected,
                  headline: track.title,
                  supportingText: track.artist,
                  leading: _TrackCover(track: track),
                  trailingText: track.duration,
                  swipe: M3EListItemSwipe(
                    mode: M3EListSwipeMode.dismiss,
                    edge: M3EListSwipeEdge.end,
                    onDismiss: (DismissDirection direction) async {
                      _dismissTrack(track.id);
                      return true;
                    },
                  ),
                ),
              ),
              if (selected)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.primary, width: 2),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TrackCover extends ConsumerWidget {
  const _TrackCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: 40,
        child: hasArt
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  size: 20,
                  color: scheme.onSecondaryContainer,
                ),
              ),
      ),
    );
  }
}

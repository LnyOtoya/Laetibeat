import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:shared_preferences/shared_preferences.dart';

import '../animations.dart';
import '../widgets/player/cover_provider.dart';
import '../widgets/player/mini_player.dart' show MiniPlayerScope;
import '../widgets/player/player_provider.dart';
import '../widgets/player/player_right_pane.dart';
import '../widgets/remote_browser_provider.dart';
import '../widgets/settings/music_library_provider.dart';
import '../widgets/settings/remote_sync_provider.dart';
import '../widgets/settings/subsonic_provider.dart';
import '../widgets/two_pane_layout.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const String _searchHint = '搜索你的专辑，艺术家，单曲';
  static const String _recentSearchesKey = 'search.recent_queries';

  final TextEditingController _controller = TextEditingController();

  List<String> _recentSearches = <String>[];
  String _query = '';

  //右区播放面板,点击搜索结果后仍复用同一播放器
  final GlobalKey<PlayerRightPaneState> _rightPaneKey =
      GlobalKey<PlayerRightPaneState>();

  @override
  void initState() {
    super.initState();
    // 清除按钮等程序化修改不会触发 onChanged，用监听同步页面结果
    _controller.addListener(_onControllerChanged);
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.text == _query) return;
    _onQueryChanged(_controller.text);
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentSearchesKey);
    if (!mounted || stored == null) return;
    setState(() => _recentSearches = stored);
  }

  // 记录搜索词：最近的排前面，去重并限制 10 条
  Future<void> _rememberSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final next = <String>[
      query,
      ..._recentSearches.where((item) => item != query),
    ];
    if (next.length > 10) {
      next.removeRange(10, next.length);
    }
    if (!mounted) return;
    setState(() => _recentSearches = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, next);
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches = <String>[]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  void _applyRecentSearch(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _rememberSearch(query);
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
  }

  @override
  Widget build(BuildContext context) {
    return TwoPaneLayout(
      leftFlex: 3,
      rightFlex: 2,
      rightMaxWidth: 520,
      left: _buildLeft(context),
      right: PlayerRightPane(key: _rightPaneKey),
    );
  }

  Widget _buildLeft(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final miniPlayerInset = MiniPlayerScope.reservedHeightOf(context);
    final query = _query.trim();

    return AnimatedContainer(
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
      padding: EdgeInsets.all(theme.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SearchBar only：不再打开独立 search view
          M3ESearchBar(
            controller: _controller,
            hintText: _searchHint,
            leading: const Icon(M3EIcons.search),
            avatar: _buildAvatar(theme),
            showClearButton: true,
            autoFocus: true,
            margin: 0,
            focusedMargin: 0,
            onSubmitted: _rememberSearch,
          ),
          SizedBox(height: theme.spacing.lg),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: miniPlayerInset),
              child: query.isEmpty
                  ? _buildSearchHistory(theme)
                  : _buildSearchResults(theme, query),
            ),
          ),
        ],
      ),
    );
  }

  // 搜索框右侧的占位头像
  Widget _buildAvatar(M3EThemeData theme) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: theme.colorScheme.secondaryContainer,
      child: Icon(
        M3EIcons.person,
        size: 18,
        color: theme.colorScheme.onSecondaryContainer,
      ),
    );
  }

  // ===== 页面内搜索结果 =====

  Widget _buildSearchResults(M3EThemeData theme, String query) {
    final music = ref.watch(musicLibraryProvider).value;
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final remoteServer = servers.isEmpty ? null : servers.first;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRemoteSearchSection(theme, query, remoteServer),
            _buildLocalSearchSection(theme, query, music),
            SizedBox(height: theme.spacing.xl),
          ],
        ),
      ),
    );
  }


  // 默认状态：最近搜索
  Widget _buildSearchHistory(M3EThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('最近搜索', style: theme.typeScale.titleMedium),
              ),
              if (_recentSearches.isNotEmpty)
                M3EButton(
                  style: M3EButtonStyle.text,
                  size: M3EButtonSize.sm,
                  label: const Text('清除'),
                  onPressed: _clearRecentSearches,
                ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          if (_recentSearches.isEmpty)
            Text(
              '暂无最近搜索',
              style: theme.typeScale.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: [
                for (final query in _recentSearches)
                  M3EChip(
                    label: query,
                    type: M3EChipType.suggestion,
                    leading: const Icon(M3EIcons.history, size: 18),
                    onPressed: () => _applyRecentSearch(query),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRemoteSearchSection(
    M3EThemeData theme,
    String query,
    SubsonicServerConfig? server,
  ) {
    final title = server?.name ?? 'Navidrome';
    if (server == null) {
      return _searchSection(
        theme: theme,
        title: title,
        children: [_searchSectionHint(theme, '未配置 Navidrome 服务')],
      );
    }

    final sync = ref.watch(remoteSyncProvider).value;
    if (sync != null && sync.meta == null && !sync.isSyncing) {
      return _searchSection(
        theme: theme,
        title: title,
        children: [_searchSectionHint(theme, '远端音乐尚未同步')],
      );
    }

    final result = ref.watch(
      remoteSearchProvider((sourceId: server.id, query: query)),
    );
    return _searchSection(
      theme: theme,
      title: title,
      children: result.when(
        loading: () => [_searchSectionHint(theme, '正在搜索…')],
        error: (error, _) => [_searchSectionHint(theme, '远端搜索失败：$error')],
        data: (data) => _remoteSearchChildren(theme, server, data),
      ),
    );
  }

  List<Widget> _remoteSearchChildren(
    M3EThemeData theme,
    SubsonicServerConfig server,
    rust_subsonic.UiRemoteSearchResult result,
  ) {
    return [
      if (result.tracks.isNotEmpty) ...[
        _searchCategoryTitle(theme, '单曲'),
        _searchHorizontalCards(
          theme,
          height: 144,
          count: result.tracks.length,
          itemBuilder: (index) =>
              _remoteTrackCard(theme, server, result.tracks, index),
        ),
      ],
      if (result.albums.isNotEmpty) ...[
        _searchCategoryTitle(theme, '专辑'),
        _searchHorizontalCards(
          theme,
          height: 184,
          count: result.albums.length,
          itemBuilder: (index) =>
              _remoteAlbumCard(theme, server, result.albums[index]),
        ),
      ],
      if (result.artists.isNotEmpty) ...[
        _searchCategoryTitle(theme, '艺术家'),
        _searchHorizontalCards(
          theme,
          height: 144,
          count: result.artists.length,
          itemBuilder: (index) =>
              _remoteArtistCard(theme, server, result.artists[index]),
        ),
      ],
      if (result.tracks.isEmpty &&
          result.albums.isEmpty &&
          result.artists.isEmpty)
        _searchSectionHint(theme, '未找到相关内容'),
    ];
  }

  Widget _buildLocalSearchSection(
    M3EThemeData theme,
    String query,
    MusicLibraryState? state,
  ) {
    if (state == null) {
      return _searchSection(
        theme: theme,
        title: '本地',
        children: [_searchSectionHint(theme, '本地音乐库加载中…')],
      );
    }

    final lower = query.toLowerCase();
    final tracks = <rust.UiTrack>[
      for (final track in state.tracks)
        if (_matches(track.title, lower) ||
            _matches(track.artist, lower) ||
            _matches(track.album, lower) ||
            _matches(track.albumArtist, lower))
          track,
    ].take(30).toList();
    final albums = <rust.UiAlbum>[
      for (final album in state.albums)
        if (_matches(album.title, lower) || _matches(album.artist, lower))
          album,
    ].take(20).toList();
    final artists = <rust.UiArtist>[
      for (final artist in state.artists)
        if (_matches(artist.name, lower)) artist,
    ].take(20).toList();

    final byId = {for (final track in state.tracks) track.id: track};

    return _searchSection(
      theme: theme,
      title: '本地',
      children: [
        if (tracks.isNotEmpty) ...[
          _searchCategoryTitle(theme, '单曲'),
          _searchHorizontalCards(
            theme,
            height: 144,
            count: tracks.length,
            itemBuilder: (index) => _localTrackCard(theme, tracks, index),
          ),
        ],
        if (albums.isNotEmpty) ...[
          _searchCategoryTitle(theme, '专辑'),
          _searchHorizontalCards(
            theme,
            height: 184,
            count: albums.length,
            itemBuilder: (index) =>
                _localAlbumCard(theme, state, byId, albums[index]),
          ),
        ],
        if (artists.isNotEmpty) ...[
          _searchCategoryTitle(theme, '艺术家'),
          _searchHorizontalCards(
            theme,
            height: 144,
            count: artists.length,
            itemBuilder: (index) =>
                _localArtistCard(theme, state, byId, artists[index]),
          ),
        ],
        if (tracks.isEmpty && albums.isEmpty && artists.isEmpty)
          _searchSectionHint(theme, '未找到相关内容'),
      ],
    );
  }

  Widget _searchSection({
    required M3EThemeData theme,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            theme.spacing.lg,
            0,
            theme.spacing.xs,
          ),
          child: Text(title, style: theme.typeScale.titleMedium),
        ),
        ...children,
      ],
    );
  }

  Widget _searchCategoryTitle(M3EThemeData theme, String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        theme.spacing.md,
        0,
        theme.spacing.sm,
      ),
      child: Text(
        title,
        style: theme.typeScale.titleSmall.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _searchSectionHint(M3EThemeData theme, String message) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        0,
        0,
        theme.spacing.lg,
      ),
      child: Text(
        message,
        style: theme.typeScale.bodySmall.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _searchHorizontalCards(
    M3EThemeData theme, {
    required double height,
    required int count,
    required Widget Function(int index) itemBuilder,
  }) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: count,
        separatorBuilder: (_, _) => SizedBox(width: theme.spacing.md),
        itemBuilder: (context, index) => itemBuilder(index),
      ),
    );
  }

  Widget _localTrackCard(
    M3EThemeData theme,
    List<rust.UiTrack> tracks,
    int index,
  ) {
    final track = tracks[index];
    return _searchMediaCard(
      theme: theme,
      width: 112,
      cover: _CoverThumb(track: track, size: 96, circle: true),
      title: track.title,
      onTap: () => _playLocalTracks(tracks, index),
    );
  }

  Widget _remoteTrackCard(
    M3EThemeData theme,
    SubsonicServerConfig server,
    List<rust_subsonic.UiRemoteTrack> tracks,
    int index,
  ) {
    final track = tracks[index];
    return _searchMediaCard(
      theme: theme,
      width: 112,
      cover: _RemoteThumb(
        sourceId: server.id,
        coverId: track.coverId,
        fallbackIcon: M3EIcons.music_note,
        size: 96,
        circle: true,
      ),
      title: track.title,
      onTap: () => _playRemoteTracks(
        tracks,
        index,
        sourceId: server.id,
        sourceLabel: server.name,
      ),
    );
  }

  Widget _localAlbumCard(
    M3EThemeData theme,
    MusicLibraryState state,
    Map<String, rust.UiTrack> byId,
    rust.UiAlbum album,
  ) {
    final cover = byId[album.coverTrackId];
    return _searchMediaCard(
      theme: theme,
      cover: cover == null
          ? _IconThumb(
              theme: theme,
              scheme: theme.colorScheme,
              icon: M3EIcons.album,
              size: 140,
            )
          : _CoverThumb(track: cover, size: 140),
      title: album.title,
      onTap: () => _playLocalAlbum(state, album),
    );
  }

  Widget _localArtistCard(
    M3EThemeData theme,
    MusicLibraryState state,
    Map<String, rust.UiTrack> byId,
    rust.UiArtist artist,
  ) {
    final cover = byId[artist.coverTrackId];
    return _searchMediaCard(
      theme: theme,
      width: 112,
      cover: cover == null
          ? _IconThumb(
              theme: theme,
              scheme: theme.colorScheme,
              icon: M3EIcons.person,
              size: 96,
              circle: true,
            )
          : _CoverThumb(track: cover, size: 96, circle: true),
      title: artist.name,
      onTap: () => _playLocalArtist(state, artist),
    );
  }

  Widget _remoteAlbumCard(
    M3EThemeData theme,
    SubsonicServerConfig server,
    rust_subsonic.UiRemoteAlbum album,
  ) {
    return _searchMediaCard(
      theme: theme,
      cover: _RemoteThumb(
        sourceId: server.id,
        coverId: album.coverId,
        fallbackIcon: M3EIcons.album,
        size: 140,
      ),
      title: album.title,
      onTap: () => _playRemoteAlbum(album, sourceId: server.id),
    );
  }

  Widget _remoteArtistCard(
    M3EThemeData theme,
    SubsonicServerConfig server,
    rust_subsonic.UiRemoteArtist artist,
  ) {
    return _searchMediaCard(
      theme: theme,
      width: 112,
      cover: _RemoteThumb(
        sourceId: server.id,
        coverId: artist.coverId,
        fallbackIcon: M3EIcons.person,
        size: 96,
        circle: true,
      ),
      title: artist.name,
      onTap: () => _playRemoteArtist(server, artist),
    );
  }

  Widget _searchMediaCard({
    required M3EThemeData theme,
    required Widget cover,
    required String title,
    required VoidCallback onTap,
    double width = 150,
  }) {
    return M3ECard(
      width: width,
      variant: M3ECardVariant.filled,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      borderRadius: M3EDimensions.borderRadiusLarge,
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: cover,
          ),
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.typeScale.titleSmall,
            ),
          ),
        ],
      ),
    );
  }

  void _playLocalTracks(
    List<rust.UiTrack> tracks,
    int index, {
    String? sourceLabel,
  }) {
    if (tracks.isEmpty) return;
    _rememberSearch(_query);
    ref
        .read(playerProvider.notifier)
        .load(tracks, index, source: sourceLabel ?? '搜索');
  }

  void _playLocalAlbum(MusicLibraryState state, rust.UiAlbum album) {
    final byId = {for (final track in state.tracks) track.id: track};
    final tracks = <rust.UiTrack>[
      for (final id in album.trackIds)
        if (byId[id] != null) byId[id]!,
    ];
    _playLocalTracks(tracks, 0, sourceLabel: album.title);
  }

  void _playLocalArtist(MusicLibraryState state, rust.UiArtist artist) {
    final tracks = <rust.UiTrack>[
      for (final track in state.tracks)
        if (track.artistId == artist.id) track,
    ];
    _playLocalTracks(tracks, 0, sourceLabel: artist.name);
  }

  void _playRemoteTracks(
    List<rust_subsonic.UiRemoteTrack> tracks,
    int index, {
    required String sourceId,
    required String sourceLabel,
  }) {
    if (tracks.isEmpty) return;
    _rememberSearch(_query);
    final queue = <rust.UiTrack>[
      for (final track in tracks) remoteTrackToUiTrack(track, sourceId),
    ];
    ref
        .read(playerProvider.notifier)
        .load(queue, index, source: sourceLabel);
  }

  Future<void> _playRemoteAlbum(
    rust_subsonic.UiRemoteAlbum album, {
    required String sourceId,
  }) async {
    try {
      final tracks = await ref.read(
        remoteTracksProvider((sourceId: sourceId, albumId: album.id)).future,
      );
      if (!mounted || tracks.isEmpty) return;
      _playRemoteTracks(
        tracks,
        0,
        sourceId: sourceId,
        sourceLabel: album.title,
      );
    } catch (e) {
      debugPrint('播放远端专辑失败: $e');
    }
  }

  Future<void> _playRemoteArtist(
    SubsonicServerConfig server,
    rust_subsonic.UiRemoteArtist artist,
  ) async {
    try {
      final albums = await ref.read(
        remoteAlbumsProvider(
          (sourceId: server.id, artistId: artist.id),
        ).future,
      );
      final tracks = <rust_subsonic.UiRemoteTrack>[];
      for (final album in albums) {
        tracks.addAll(
          await ref.read(
            remoteTracksProvider(
              (sourceId: server.id, albumId: album.id),
            ).future,
          ),
        );
      }
      if (!mounted || tracks.isEmpty) return;
      _playRemoteTracks(
        tracks,
        0,
        sourceId: server.id,
        sourceLabel: artist.name,
      );
    } catch (e) {
      debugPrint('播放远端艺术家失败: $e');
    }
  }

  static bool _matches(String value, String query) =>
      value.toLowerCase().contains(query);
}

//搜索结果行首封面:懒加载曲目封面,无封面回退占位图标
class _CoverThumb extends ConsumerWidget {
  const _CoverThumb({
    required this.track,
    this.size,
    this.circle = false,
  });

  final rust.UiTrack track;
  final double? size;
  final bool circle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final dimension = size ?? theme.spacing.xxl * 1.5;
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipRRect(
      borderRadius: circle
          ? BorderRadius.circular(dimension / 2)
          : M3EDimensions.borderRadiusSmall,
      child: SizedBox(
        width: dimension,
        height: dimension,
        child: hasArt
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  size: dimension * 0.32,
                  color: scheme.onSecondaryContainer,
                ),
              ),
      ),
    );
  }
}

//远端结果行首封面:按 (sourceId, coverId) 懒加载,无封面回退占位图标
class _RemoteThumb extends ConsumerWidget {
  const _RemoteThumb({
    required this.sourceId,
    required this.coverId,
    required this.fallbackIcon,
    this.size,
    this.circle = false,
  });

  final String sourceId;
  final String? coverId;
  final IconData fallbackIcon;
  final double? size;
  final bool circle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final dimension = size ?? theme.spacing.xxl * 1.5;
    final id = coverId;

    Widget fallback() => ColoredBox(
      color: scheme.secondaryContainer,
      child: Icon(
        fallbackIcon,
        size: dimension * 0.32,
        color: scheme.onSecondaryContainer,
      ),
    );

    return ClipRRect(
      borderRadius: circle
          ? BorderRadius.circular(dimension / 2)
          : M3EDimensions.borderRadiusSmall,
      child: SizedBox(
        width: dimension,
        height: dimension,
        child: id == null || id.isEmpty
            ? fallback()
            : ref
                  .watch(remoteCoverProvider((sourceId: sourceId, coverId: id)))
                  .when(
                    loading: fallback,
                    error: (_, _) => fallback(),
                    data: (bytes) => bytes == null || bytes.isEmpty
                        ? fallback()
                        : Image.memory(bytes, fit: BoxFit.cover),
                  ),
      ),
    );
  }
}

//无代表曲目时的图标占位
class _IconThumb extends StatelessWidget {
  const _IconThumb({
    required this.theme,
    required this.scheme,
    required this.icon,
    this.size,
    this.circle = false,
  });

  final M3EThemeData theme;
  final M3EColorScheme scheme;
  final IconData icon;
  final double? size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final dimension = size ?? theme.spacing.xxl * 1.5;
    final child = Icon(icon, size: dimension * 0.32);
    return circle
        ? M3EShapeContainer.circle(
            width: dimension,
            height: dimension,
            color: scheme.secondaryContainer,
            child: child,
          )
        : M3EShapeContainer.square(
            width: dimension,
            height: dimension,
            color: scheme.secondaryContainer,
            child: child,
          );
  }
}

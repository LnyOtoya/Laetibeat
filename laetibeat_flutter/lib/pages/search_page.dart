import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:shared_preferences/shared_preferences.dart';

import '../animations.dart';
import '../widgets/player/cover_provider.dart';
import '../widgets/player/player_provider.dart';
import '../widgets/player/player_right_pane.dart';
import '../widgets/remote_browser_provider.dart';
import '../widgets/settings/music_library_provider.dart';
import '../widgets/settings/remote_sync_provider.dart';
import '../widgets/settings/subsonic_provider.dart';
import '../widgets/two_pane_layout.dart';

/// 搜索结果类型
enum _SearchFilter { track, artist, album }

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  /// 音源切换里的"本地音乐"哨兵值
  static const String _localSource = '__local__';

  static const String _searchHint = '搜索你的专辑，艺术家，单曲';
  static const String _recentSearchesKey = 'search.recent_queries';

  final M3ESearchController _controller = M3ESearchController();

  List<String> _recentSearches = <String>[];

  //右区播放面板,点击搜索结果后仍复用同一播放器
  final GlobalKey<PlayerRightPaneState> _rightPaneKey =
      GlobalKey<PlayerRightPaneState>();

  _SearchFilter _filter = _SearchFilter.track;
  String _query = '';

  //远端:输入防抖后的查询词与当前音源
  String _sourceId = _localSource;
  String _debouncedQuery = '';
  Timer? _debounce;

  //远端艺术家结果的专辑下钻状态
  rust_subsonic.UiRemoteArtist? _remoteArtist;

  @override
  void initState() {
    super.initState();
    // 清除按钮等程序化修改不会触发 onChanged，用监听同步页面结果
    _controller.addListener(_onControllerChanged);
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _debounce?.cancel();
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

  void _applyRecentSearch(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _rememberSearch(query);
  }

  String get _filterLabel => switch (_filter) {
    _SearchFilter.track => '曲目',
    _SearchFilter.artist => '艺术家',
    _SearchFilter.album => '专辑',
  };

  bool get _isLocal => _sourceId == _localSource;

  String _sourceName(List<SubsonicServerConfig> servers) {
    if (_isLocal) return '本地音乐';
    for (final server in servers) {
      if (server.id == _sourceId) return server.name;
    }
    return '远端音乐';
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _remoteArtist = null;
    });
    _debounce?.cancel();
    if (_isLocal) return;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _debouncedQuery = value.trim());
    });
  }

  void _selectSource(String sourceId) {
    if (sourceId == _sourceId) return;
    _debounce?.cancel();
    setState(() {
      _sourceId = sourceId;
      _remoteArtist = null;
      _debouncedQuery = _query.trim();
    });
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
    final music = ref.watch(musicLibraryProvider);
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];

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
          // 搜索锚点：点击打开 search view
          M3ESearchAnchor.bar(
            searchController: _controller,
            // contained 样式；isFullScreen 不传 => 自动布局（窄屏全屏/宽屏 docked）
            viewStyle: M3ESearchViewStyle.contained,
            barHintText: _searchHint,
            viewHintText: _searchHint,
            // 收起态：leading 搜索，trailing 头像
            barLeading: const Icon(M3EIcons.search),
            barAvatar: _buildAvatar(theme),
            // 展开态：同样保留头像；clear 按钮由 showViewClearButton 控制
            viewTrailing: [_buildAvatar(theme)],
            showViewClearButton: true,
            // 页面已有内边距，关闭搜索框自带的外扩 margin
            expandOnFocus: false,
            onChanged: _onQueryChanged,
            onSubmitted: _rememberSearch,
            onClose: () => _rememberSearch(_controller.text),
            suggestionsBuilder: _buildSuggestions,
          ),
          SizedBox(height: theme.spacing.lg),
          //结果类型 + 音源切换(内容自适应宽度,与音乐库页一致)
          Wrap(
            spacing: theme.spacing.md,
            runSpacing: theme.spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              M3ESplitButton<_SearchFilter>(
                items: const [
                  M3ESplitButtonItem(
                    value: _SearchFilter.track,
                    child: Text('曲目'),
                  ),
                  M3ESplitButtonItem(
                    value: _SearchFilter.artist,
                    child: Text('艺术家'),
                  ),
                  M3ESplitButtonItem(
                    value: _SearchFilter.album,
                    child: Text('专辑'),
                  ),
                ],
                selectedValue: _filter,
                label: _filterLabel,
                style: M3EButtonStyle.filled,
                size: M3EButtonSize.md,
                shape: M3EButtonShape.round,
                onSelected: (value) => setState(() => _filter = value),
              ),
              if (servers.isNotEmpty)
                M3ESplitButton<String>(
                  items: [
                    const M3ESplitButtonItem(
                      value: _localSource,
                      child: Text('本地音乐'),
                    ),
                    for (final server in servers)
                      M3ESplitButtonItem(
                        value: server.id,
                        child: Text(server.name),
                      ),
                  ],
                  selectedValue: _sourceId,
                  label: _sourceName(servers),
                  style: M3EButtonStyle.tonal,
                  size: M3EButtonSize.md,
                  shape: M3EButtonShape.round,
                  onSelected: _selectSource,
                ),
            ],
          ),
          SizedBox(height: theme.spacing.lg),
          Expanded(
            child: _isLocal
                ? _buildResults(theme, scheme, music.value)
                : _buildRemoteResults(theme, scheme, servers),
          ),
        ],
      ),
    );
  }

  // 搜索框/搜索视图右侧的占位头像
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

  // ===== Search view 内容 =====

  // 空输入显示最近搜索；有输入时上下分为 Navidrome / 本地两部分
  Future<Iterable<Widget>> _buildSuggestions(
    BuildContext context,
    M3ESearchController controller,
  ) async {
    final theme = M3ETheme.of(context);
    final query = controller.text.trim();
    if (query.isEmpty) {
      return <Widget>[_buildRecentSearches(theme)];
    }

    final music = ref.read(musicLibraryProvider).value;
    final servers =
        ref.read(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final remoteServer = _activeRemoteServer(servers);

    return <Widget>[
      await _buildRemoteSearchSection(theme, query, remoteServer),
      _buildLocalSearchSection(theme, query, music),
    ];
  }

  // 当前优先的远端音源：跟随页面上的音源选择，否则取第一个
  SubsonicServerConfig? _activeRemoteServer(
    List<SubsonicServerConfig> servers,
  ) {
    for (final server in servers) {
      if (server.id == _sourceId) return server;
    }
    return servers.isEmpty ? null : servers.first;
  }

  Widget _buildRecentSearches(M3EThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.lg,
        theme.spacing.sm,
        theme.spacing.lg,
        theme.spacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最近搜索', style: theme.typeScale.titleMedium),
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

  Future<Widget> _buildRemoteSearchSection(
    M3EThemeData theme,
    String query,
    SubsonicServerConfig? server,
  ) async {
    final title = server?.name ?? 'Navidrome';
    if (server == null) {
      return _searchSection(
        theme: theme,
        title: title,
        children: [_searchSectionHint(theme, '未配置 Navidrome 服务')],
      );
    }

    final sync = ref.read(remoteSyncProvider).value;
    if (sync != null && sync.meta == null && !sync.isSyncing) {
      return _searchSection(
        theme: theme,
        title: title,
        children: [_searchSectionHint(theme, '远端音乐尚未同步')],
      );
    }

    rust_subsonic.UiRemoteSearchResult result;
    final provider = remoteSearchProvider(
      (sourceId: server.id, query: query),
    );
    // 查询期间保持 autoDispose provider 存活
    final keepAlive = ref.listenManual(provider, (_, _) {});
    try {
      result = await ref.read(provider.future);
    } catch (error) {
      return _searchSection(
        theme: theme,
        title: title,
        children: [_searchSectionHint(theme, '远端搜索失败：$error')],
      );
    } finally {
      keepAlive.close();
    }

    return _searchSection(
      theme: theme,
      title: title,
      children: [
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
      ],
    );
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
            theme.spacing.lg,
            theme.spacing.lg,
            theme.spacing.lg,
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
        theme.spacing.lg,
        theme.spacing.md,
        theme.spacing.lg,
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
        theme.spacing.lg,
        0,
        theme.spacing.lg,
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
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
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
      onTap: () {
        // 远端艺术家：切到该音源并在页面里下钻专辑
        setState(() {
          _sourceId = server.id;
          _debouncedQuery = _query.trim();
          _remoteArtist = artist;
        });
        _controller.closeView(null);
      },
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

  Widget _buildResults(
    M3EThemeData theme,
    M3EColorScheme scheme,
    MusicLibraryState? state,
  ) {
    if (state == null) {
      return Center(
        child: M3ELoadingIndicator(
          color: scheme.primary,
          containerColor: scheme.surfaceContainerHighest,
        ),
      );
    }
    if (state.tracks.isEmpty) {
      return _hint(theme, scheme, '音乐库为空', '请先在设置-内容中选择目录并扫描');
    }

    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return _hint(theme, scheme, '搜索本地音乐', '输入歌名、艺术家或专辑关键词');
    }

    return switch (_filter) {
      _SearchFilter.track => _buildTrackResults(theme, scheme, state, query),
      _SearchFilter.artist => _buildArtistResults(theme, scheme, state, query),
      _SearchFilter.album => _buildAlbumResults(theme, scheme, state, query),
    };
  }

  //曲目结果:歌名/艺术家/专辑/专辑艺术家任一命中;点击以搜索结果整体为队列播放
  Widget _buildTrackResults(
    M3EThemeData theme,
    M3EColorScheme scheme,
    MusicLibraryState state,
    String query,
  ) {
    final results = <rust.UiTrack>[
      for (final track in state.tracks)
        if (_matches(track.title, query) ||
            _matches(track.artist, query) ||
            _matches(track.album, query) ||
            _matches(track.albumArtist, query))
          track,
    ];
    if (results.isEmpty) {
      return _hint(theme, scheme, '未找到匹配曲目', null);
    }

    return M3EList.scrollable(
      itemCount: results.length,
      onTap: (i) =>
          ref.read(playerProvider.notifier).load(results, i, source: '搜索'),
      itemBuilder: (context, i) {
        final track = results[i];
        return M3EListItem(
          leading: _CoverThumb(track: track),
          headline: track.title,
          supportingText: '${track.artist} · ${track.album}',
          trailingText: track.duration,
        );
      },
    );
  }

  //艺术家结果:点击播放该艺术家的全部曲目
  Widget _buildArtistResults(
    M3EThemeData theme,
    M3EColorScheme scheme,
    MusicLibraryState state,
    String query,
  ) {
    final results = <rust.UiArtist>[
      for (final artist in state.artists)
        if (_matches(artist.name, query)) artist,
    ];
    if (results.isEmpty) {
      return _hint(theme, scheme, '未找到匹配艺术家', null);
    }

    final byId = {for (final t in state.tracks) t.id: t};
    return M3EList.scrollable(
      itemCount: results.length,
      onTap: (i) {
        final artist = results[i];
        final tracks = <rust.UiTrack>[
          for (final t in state.tracks)
            if (t.artistId == artist.id) t,
        ];
        if (tracks.isNotEmpty) {
          ref
              .read(playerProvider.notifier)
              .load(tracks, 0, source: artist.name);
        }
      },
      itemBuilder: (context, i) {
        final artist = results[i];
        final cover = byId[artist.coverTrackId];
        return M3EListItem(
          leading: cover == null
              ? _IconThumb(theme: theme, scheme: scheme, icon: M3EIcons.person)
              : _CoverThumb(track: cover),
          headline: artist.name,
          supportingText: '${artist.trackCount} 首曲目',
        );
      },
    );
  }

  //专辑结果:点击按专辑曲目顺序播放
  Widget _buildAlbumResults(
    M3EThemeData theme,
    M3EColorScheme scheme,
    MusicLibraryState state,
    String query,
  ) {
    final results = <rust.UiAlbum>[
      for (final album in state.albums)
        if (_matches(album.title, query) || _matches(album.artist, query))
          album,
    ];
    if (results.isEmpty) {
      return _hint(theme, scheme, '未找到匹配专辑', null);
    }

    final byId = {for (final t in state.tracks) t.id: t};
    return M3EList.scrollable(
      itemCount: results.length,
      onTap: (i) {
        final album = results[i];
        final tracks = <rust.UiTrack>[
          for (final id in album.trackIds)
            if (byId[id] != null) byId[id]!,
        ];
        if (tracks.isNotEmpty) {
          ref
              .read(playerProvider.notifier)
              .load(tracks, 0, source: album.title);
        }
      },
      itemBuilder: (context, i) {
        final album = results[i];
        final cover = byId[album.coverTrackId];
        final year = album.year == null ? '' : ' · ${album.year}';
        return M3EListItem(
          leading: cover == null
              ? _IconThumb(theme: theme, scheme: scheme, icon: M3EIcons.album)
              : _CoverThumb(track: cover),
          headline: album.title,
          supportingText: '${album.artist}$year · ${album.trackCount} 首曲目',
        );
      },
    );
  }

  //远端结果:艺术家可下钻到专辑列表,专辑/曲目点击即播放
  Widget _buildRemoteResults(
    M3EThemeData theme,
    M3EColorScheme scheme,
    List<SubsonicServerConfig> servers,
  ) {
    final artist = _remoteArtist;
    if (artist != null) {
      return _buildRemoteArtistAlbums(theme, scheme, artist);
    }

    // 远端搜索现在读本地同步库;尚未同步时直接引导去同步
    final syncState = ref.watch(remoteSyncProvider).value;
    if (syncState != null &&
        syncState.meta == null &&
        !syncState.isSyncing) {
      return _hint(
        theme,
        scheme,
        '远端音乐尚未同步',
        '请先在 设置 → 内容 → 同步音乐 中同步',
      );
    }

    if (_query.trim().isEmpty) {
      return _hint(
        theme,
        scheme,
        '搜索 ${_sourceName(servers)}',
        '输入歌名、艺术家或专辑关键词',
      );
    }
    //防抖窗口内还没发出请求
    if (_debouncedQuery.isEmpty) {
      return _hint(theme, scheme, '搜索 ${_sourceName(servers)}', '输入关键词后自动搜索');
    }

    final result = ref.watch(
      remoteSearchProvider((sourceId: _sourceId, query: _debouncedQuery)),
    );
    return result.when(
      loading: () => Center(
        child: M3ELoadingIndicator(
          color: scheme.primary,
          containerColor: scheme.surfaceContainerHighest,
        ),
      ),
      error: (error, _) => _hint(
        theme,
        scheme,
        '远端搜索失败',
        '$error',
        onRetry: () => ref.invalidate(
          remoteSearchProvider(
            (sourceId: _sourceId, query: _debouncedQuery),
          ),
        ),
      ),
      data: (data) => switch (_filter) {
        _SearchFilter.track => _buildRemoteTrackResults(theme, scheme, data),
        _SearchFilter.artist => _buildRemoteArtistResults(theme, scheme, data),
        _SearchFilter.album => _buildRemoteAlbumResults(theme, scheme, data),
      },
    );
  }

  Widget _buildRemoteTrackResults(
    M3EThemeData theme,
    M3EColorScheme scheme,
    rust_subsonic.UiRemoteSearchResult data,
  ) {
    if (data.tracks.isEmpty) {
      return _hint(theme, scheme, '未找到匹配曲目', null);
    }
    return M3EList.scrollable(
      itemCount: data.tracks.length,
      onTap: (i) => _playRemoteTracks(data.tracks, i),
      itemBuilder: (context, i) {
        final track = data.tracks[i];
        return M3EListItem(
          leading: _RemoteThumb(
            sourceId: _sourceId,
            coverId: track.coverId,
            fallbackIcon: M3EIcons.music_note,
          ),
          headline: track.title,
          supportingText: '${track.artist} · ${track.album}',
          trailingText: formatTrackDuration(track.durationSeconds.toInt()),
        );
      },
    );
  }

  Widget _buildRemoteArtistResults(
    M3EThemeData theme,
    M3EColorScheme scheme,
    rust_subsonic.UiRemoteSearchResult data,
  ) {
    if (data.artists.isEmpty) {
      return _hint(theme, scheme, '未找到匹配艺术家', null);
    }
    return M3EList.scrollable(
      itemCount: data.artists.length,
      onTap: (i) => setState(() => _remoteArtist = data.artists[i]),
      itemBuilder: (context, i) {
        final artist = data.artists[i];
        return M3EListItem(
          leading: _RemoteThumb(
            sourceId: _sourceId,
            coverId: artist.coverId,
            fallbackIcon: M3EIcons.person,
          ),
          headline: artist.name,
          supportingText: artist.albumCount == null
              ? null
              : '${artist.albumCount!.toInt()} 张专辑',
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }

  Widget _buildRemoteAlbumResults(
    M3EThemeData theme,
    M3EColorScheme scheme,
    rust_subsonic.UiRemoteSearchResult data,
  ) {
    if (data.albums.isEmpty) {
      return _hint(theme, scheme, '未找到匹配专辑', null);
    }
    return M3EList.scrollable(
      itemCount: data.albums.length,
      onTap: (i) => _playRemoteAlbum(data.albums[i]),
      itemBuilder: (context, i) => _remoteAlbumRow(theme, data.albums[i]),
    );
  }

  //艺术家下钻:展示该艺术家的专辑,点击专辑播放整张
  Widget _buildRemoteArtistAlbums(
    M3EThemeData theme,
    M3EColorScheme scheme,
    rust_subsonic.UiRemoteArtist artist,
  ) {
    final albums = ref.watch(
      remoteAlbumsProvider((sourceId: _sourceId, artistId: artist.id)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            M3EIconButton(
              size: M3EIconButtonSize.xs,
              icon: const Icon(Icons.arrow_back),
              tooltip: '返回搜索结果',
              onPressed: () => setState(() => _remoteArtist = null),
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typeScale.titleMedium,
                  ),
                  Text(
                    '专辑',
                    style: theme.typeScale.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        Expanded(
          child: albums.when(
            loading: () => Center(
              child: M3ELoadingIndicator(
                color: scheme.primary,
                containerColor: scheme.surfaceContainerHighest,
              ),
            ),
            error: (error, _) => _hint(theme, scheme, '无法加载专辑', '$error'),
            data: (list) => list.isEmpty
                ? _hint(theme, scheme, '这位艺术家还没有专辑', null)
                : M3EList.scrollable(
                    itemCount: list.length,
                    onTap: (i) => _playRemoteAlbum(list[i]),
                    itemBuilder: (context, i) =>
                        _remoteAlbumRow(theme, list[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _remoteAlbumRow(
    M3EThemeData theme,
    rust_subsonic.UiRemoteAlbum album,
  ) {
    final year = album.year == null ? '' : ' · ${album.year}';
    return M3EListItem(
      leading: _RemoteThumb(
        sourceId: _sourceId,
        coverId: album.coverId,
        fallbackIcon: M3EIcons.album,
      ),
      headline: album.title,
      supportingText: '${album.artist}$year',
      trailing: album.songCount == null
          ? null
          : Text(
              '${album.songCount!.toInt()} 首',
              style: theme.typeScale.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }

  void _playRemoteTracks(
    List<rust_subsonic.UiRemoteTrack> tracks,
    int index, {
    String? sourceId,
    String? sourceLabel,
  }) {
    final id = sourceId ?? _sourceId;
    final queue = <rust.UiTrack>[
      for (final track in tracks) remoteTrackToUiTrack(track, id),
    ];
    ref
        .read(playerProvider.notifier)
        .load(
          queue,
          index,
          source:
              sourceLabel ??
              _sourceName(
                ref.read(subsonicServersProvider).value ??
                    const <SubsonicServerConfig>[],
              ),
        );
  }

  Future<void> _playRemoteAlbum(
    rust_subsonic.UiRemoteAlbum album, {
    String? sourceId,
  }) async {
    final id = sourceId ?? _sourceId;
    try {
      final tracks = await ref.read(
        remoteTracksProvider((sourceId: id, albumId: album.id)).future,
      );
      if (!mounted || tracks.isEmpty) return;
      _playRemoteTracks(
        tracks,
        0,
        sourceId: id,
        sourceLabel: album.title,
      );
    } catch (e) {
      debugPrint('播放远端专辑失败: $e');
    }
  }

  static bool _matches(String value, String query) =>
      value.toLowerCase().contains(query);

  //空态/无结果提示
  Widget _hint(
    M3EThemeData theme,
    M3EColorScheme scheme,
    String title,
    String? detail, {
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            M3EIcons.search,
            size: 56,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
          ),
          SizedBox(height: theme.spacing.lg),
          Text(title, style: theme.typeScale.titleMedium),
          if (detail != null) ...[
            SizedBox(height: theme.spacing.xs),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.typeScale.bodyMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (onRetry != null) ...[
            SizedBox(height: theme.spacing.lg),
            M3EButton(
              size: M3EButtonSize.sm,
              style: M3EButtonStyle.filled,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
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

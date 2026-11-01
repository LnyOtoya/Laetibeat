import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import '../../../src/rust/api/simple.dart' as rust;
import '../../../src/rust/api/subsonic.dart' as rust_subsonic;
import '../../../widgets/player/cover_provider.dart';
import '../../../widgets/player/player_provider.dart';
import '../../../widgets/remote_browser_provider.dart';
import '../../../widgets/settings/music_library_provider.dart';
import '../../../widgets/settings/persistence.dart';
import '../../../widgets/settings/remote_sync_provider.dart';
import '../../../widgets/settings/subsonic_provider.dart';
import '../library/albums/album_detail_page.dart';
import '../library/artists/artist_detail_page.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import '../widgets/mobile_app_bar.dart';
import '../widgets/mobile_search_bar.dart';

/// 移动端搜索页面。
///
/// 搜索结果同时展示远端与本地内容；full screen 搜索视图内也会直接显示。
class MobileSearchPage extends ConsumerStatefulWidget {
  const MobileSearchPage({super.key});

  @override
  ConsumerState<MobileSearchPage> createState() => _MobileSearchPageState();
}

class _MobileSearchPageState extends ConsumerState<MobileSearchPage> {
  static const String _recentSearchesKey = 'search.recent_queries';

  static const int _recentSearchLimit = 30;

  late final M3ESearchController _searchController;
  String _query = '';
  List<String> _recentSearches = const <String>[];

  @override
  void initState() {
    super.initState();
    _searchController = M3ESearchController()..addListener(_onSearchChanged);
    _recentSearches =
        ref.read(sharedPreferencesProvider).getStringList(_recentSearchesKey) ??
        const <String>[];
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _query) return;
    setState(() => _query = query);
  }

  Future<void> _rememberSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final next = <String>[
      query,
      ..._recentSearches.where((item) => item != query),
    ];
    if (next.length > _recentSearchLimit) {
      next.removeRange(_recentSearchLimit, next.length);
    }
    if (!mounted) return;
    setState(() => _recentSearches = next);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_recentSearchesKey, next);
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches = const <String>[]);
    await ref.read(sharedPreferencesProvider).remove(_recentSearchesKey);
  }

  void _applyRecentSearch(String query) {
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    unawaited(_rememberSearch(query));
  }

  void _clearSearch() {
    final current = _searchController.text.trim();
    if (current.isNotEmpty) {
      unawaited(_rememberSearch(current));
    }
    if (_searchController.text.isEmpty && _query.isEmpty) return;
    _searchController.clear();
    if (mounted) {
      setState(() => _query = '');
    }
  }

  Widget _buildSearchHistory(
    M3EThemeData theme,
    AppLocalizations l10n,
    double bottomInset,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
      child: _buildSearchHistoryContent(theme, l10n),
    );
  }

  Widget _buildSearchHistoryContent(M3EThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.searchRecentTitle,
                style: theme.typeScale.titleMedium,
              ),
            ),
            if (_recentSearches.isNotEmpty)
              M3EButton(
                style: M3EButtonStyle.text,
                size: M3EButtonSize.sm,
                label: Text(l10n.searchRecentClear),
                onPressed: _clearRecentSearches,
              ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        if (_recentSearches.isEmpty)
          Text(
            l10n.searchRecentEmpty,
            style: theme.typeScale.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return PopScope(
      canPop: _query.isEmpty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _clearSearch();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainer,
        appBar: mobileTopAppBar(
          context,
          title: MobileSearchBar(
            searchController: _searchController,
            onViewClosed: _clearSearch,
            onSubmitted: (String value) => unawaited(_rememberSearch(value)),
            suggestionsBuilder:
                (BuildContext context, M3ESearchController controller) {
                  final query = controller.text.trim();
                  if (query.isEmpty) {
                    return <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: _buildSearchHistoryContent(
                          M3ETheme.of(context),
                          AppLocalizations.of(context),
                        ),
                      ),
                    ];
                  }
                  return <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: _MobileSearchResults(query: query),
                    ),
                  ];
                },
          ),
        ),
        body: SafeArea(
          top: false,
          child: _query.isEmpty
              ? _buildSearchHistory(theme, l10n, bottomInset)
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
                  child: _MobileSearchResults(query: _query),
                ),
        ),
      ),
    );
  }
}

/// 搜索视图和普通页面共用的聚合结果。
class _MobileSearchResults extends ConsumerWidget {
  const _MobileSearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final server = servers.isEmpty ? null : servers.first;
    final local = ref.watch(musicLibraryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (server != null)
          _buildRemoteSection(context, ref, theme, l10n, server),
        _buildLocalSection(ref, theme, l10n, local),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRemoteSection(
    BuildContext context,
    WidgetRef ref,
    M3EThemeData theme,
    AppLocalizations l10n,
    SubsonicServerConfig server,
  ) {
    final sync = ref.watch(remoteSyncProvider).value;
    final notSynced = sync != null && sync.meta == null && !sync.isSyncing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(theme, server.name),
        if (notSynced)
          _hint(theme, l10n.searchRemoteNotSynced)
        else
          ref
              .watch(remoteSearchProvider((sourceId: server.id, query: query)))
              .when(
                loading: () => _hint(theme, l10n.searchRemoteLoading),
                error: (Object error, StackTrace stackTrace) =>
                    _hint(theme, '${l10n.searchFailed}\n$error'),
                data: (rust_subsonic.UiRemoteSearchResult data) =>
                    _buildRemoteResults(
                      context,
                      ref,
                      theme,
                      l10n,
                      server,
                      data,
                    ),
              ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRemoteResults(
    BuildContext context,
    WidgetRef ref,
    M3EThemeData theme,
    AppLocalizations l10n,
    SubsonicServerConfig server,
    rust_subsonic.UiRemoteSearchResult data,
  ) {
    if (data.tracks.isEmpty && data.albums.isEmpty && data.artists.isEmpty) {
      return _hint(theme, l10n.searchNoResults);
    }

    final tracks = data.tracks
        .map((track) => remoteTrackToUiTrack(track, server.id))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tracks.isNotEmpty) ...[
          _categoryTitle(theme, l10n.librarySongs),
          _trackList(ref, theme, tracks, server.name),
        ],
        if (data.albums.isNotEmpty) ...[
          _categoryTitle(theme, l10n.libraryAlbums),
          M3EList(
            color: theme.colorScheme.surface,
            variant: M3ECardVariant.filled,
            itemCount: data.albums.length,
            onTap: (int index) {
              pushMobileRootPage(
                context,
                AlbumDetailPage(sourceId: server.id, album: data.albums[index]),
                name: MobileRoutes.albumDetail,
              );
            },
            itemBuilder: (BuildContext context, int index) {
              final album = data.albums[index];
              return M3EListItem(
                leading: SizedBox.square(
                  dimension: 40,
                  child: _RemoteCover(
                    sourceId: server.id,
                    coverId: album.coverId,
                    fallbackIcon: M3EIcons.album,
                  ),
                ),
                headline: album.title,
                supportingText: album.artist,
              );
            },
          ),
        ],
        if (data.artists.isNotEmpty) ...[
          _categoryTitle(theme, l10n.libraryArtists),
          M3EList(
            color: theme.colorScheme.surface,
            variant: M3ECardVariant.filled,
            itemCount: data.artists.length,
            onTap: (int index) {
              pushMobileRootPage(
                context,
                ArtistDetailPage(
                  sourceId: server.id,
                  artist: data.artists[index],
                ),
                name: MobileRoutes.artistDetail,
              );
            },
            itemBuilder: (BuildContext context, int index) {
              final artist = data.artists[index];
              return M3EListItem(
                leading: SizedBox.square(
                  dimension: 40,
                  child: _RemoteCover(
                    sourceId: server.id,
                    coverId: artist.coverId,
                    fallbackIcon: M3EIcons.person,
                    circle: true,
                  ),
                ),
                headline: artist.name,
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildLocalSection(
    WidgetRef ref,
    M3EThemeData theme,
    AppLocalizations l10n,
    AsyncValue<MusicLibraryState> library,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(theme, l10n.searchSourceLocal),
        library.when(
          loading: () => _hint(theme, l10n.searchLocalLoading),
          error: (Object error, StackTrace stackTrace) =>
              _hint(theme, '${l10n.searchFailed}\n$error'),
          data: (MusicLibraryState state) {
            final lower = query.toLowerCase();
            final tracks = state.tracks
                .where(
                  (track) =>
                      _matches(track.title, lower) ||
                      _matches(track.artist, lower) ||
                      _matches(track.album, lower) ||
                      _matches(track.albumArtist, lower),
                )
                .take(30)
                .toList(growable: false);
            final albums = state.albums
                .where(
                  (album) =>
                      _matches(album.title, lower) ||
                      _matches(album.artist, lower),
                )
                .take(20)
                .toList(growable: false);
            final artists = state.artists
                .where((artist) => _matches(artist.name, lower))
                .take(20)
                .toList(growable: false);

            if (tracks.isEmpty && albums.isEmpty && artists.isEmpty) {
              return _hint(theme, l10n.searchNoResults);
            }

            final byId = {for (final track in state.tracks) track.id: track};

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tracks.isNotEmpty) ...[
                  _categoryTitle(theme, l10n.librarySongs),
                  _trackList(ref, theme, tracks, l10n.searchSourceLocal),
                ],
                if (albums.isNotEmpty) ...[
                  _categoryTitle(theme, l10n.libraryAlbums),
                  M3EList(
                    color: theme.colorScheme.surface,
                    variant: M3ECardVariant.filled,
                    itemCount: albums.length,
                    onTap: (int index) {
                      _playLocalAlbum(ref, state, albums[index]);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final album = albums[index];
                      final cover = byId[album.coverTrackId];
                      return M3EListItem(
                        leading: SizedBox.square(
                          dimension: 40,
                          child: cover == null
                              ? const Icon(M3EIcons.album)
                              : _LocalCover(track: cover),
                        ),
                        headline: album.title,
                        supportingText: album.artist,
                      );
                    },
                  ),
                ],
                if (artists.isNotEmpty) ...[
                  _categoryTitle(theme, l10n.libraryArtists),
                  M3EList(
                    color: theme.colorScheme.surface,
                    variant: M3ECardVariant.filled,
                    itemCount: artists.length,
                    onTap: (int index) {
                      _playLocalArtist(ref, state, artists[index]);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final artist = artists[index];
                      final cover = byId[artist.coverTrackId];
                      return M3EListItem(
                        leading: SizedBox.square(
                          dimension: 40,
                          child: cover == null
                              ? const Icon(M3EIcons.person)
                              : _LocalCover(track: cover, circle: true),
                        ),
                        headline: artist.name,
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _sectionTitle(M3EThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 8, bottom: 4),
      child: Text(text, style: theme.typeScale.titleMedium),
    );
  }

  Widget _categoryTitle(M3EThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: theme.typeScale.titleSmall.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _hint(M3EThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: theme.typeScale.bodySmall.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _trackList(
    WidgetRef ref,
    M3EThemeData theme,
    List<rust.UiTrack> tracks,
    String sourceName,
  ) {
    return M3EList(
      color: theme.colorScheme.surface,
      variant: M3ECardVariant.filled,
      itemCount: tracks.length,
      onTap: (int index) {
        ref
            .read(playerProvider.notifier)
            .load(tracks, index, source: sourceName);
      },
      itemBuilder: (BuildContext context, int index) {
        final track = tracks[index];
        return M3EListItem(
          leading: SizedBox.square(
            dimension: 40,
            child: _LocalCover(track: track),
          ),
          headline: track.title,
          supportingText: track.artist,
          trailingText: track.duration,
        );
      },
    );
  }

  void _playLocalAlbum(
    WidgetRef ref,
    MusicLibraryState state,
    rust.UiAlbum album,
  ) {
    final byId = {for (final track in state.tracks) track.id: track};
    final tracks = <rust.UiTrack>[
      for (final id in album.trackIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (tracks.isEmpty) return;
    ref.read(playerProvider.notifier).load(tracks, 0, source: album.title);
  }

  void _playLocalArtist(
    WidgetRef ref,
    MusicLibraryState state,
    rust.UiArtist artist,
  ) {
    final tracks = state.tracks
        .where((track) => track.artistId == artist.id)
        .toList(growable: false);
    if (tracks.isEmpty) return;
    ref.read(playerProvider.notifier).load(tracks, 0, source: artist.name);
  }

  static bool _matches(String value, String query) =>
      value.toLowerCase().contains(query);
}

class _LocalCover extends ConsumerWidget {
  const _LocalCover({required this.track, this.circle = false});

  final rust.UiTrack track;
  final bool circle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipRRect(
      borderRadius: circle
          ? BorderRadius.circular(20)
          : BorderRadius.circular(8),
      child: hasArt
          ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
          : ColoredBox(
              color: scheme.secondaryContainer,
              child: Icon(
                M3EIcons.music_note,
                size: 18,
                color: scheme.onSecondaryContainer,
              ),
            ),
    );
  }
}

class _RemoteCover extends ConsumerWidget {
  const _RemoteCover({
    required this.sourceId,
    required this.coverId,
    required this.fallbackIcon,
    this.circle = false,
  });

  final String sourceId;
  final String? coverId;
  final IconData fallbackIcon;
  final bool circle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final id = coverId;

    Widget fallback() => ColoredBox(
      color: scheme.secondaryContainer,
      child: Icon(fallbackIcon, size: 18, color: scheme.onSecondaryContainer),
    );

    return ClipRRect(
      borderRadius: circle
          ? BorderRadius.circular(20)
          : BorderRadius.circular(8),
      child: id == null || id.isEmpty
          ? fallback()
          : ref
                .watch(remoteCoverProvider((sourceId: sourceId, coverId: id)))
                .when(
                  loading: fallback,
                  error: (Object error, StackTrace stackTrace) => fallback(),
                  data: (bytes) => bytes == null || bytes.isEmpty
                      ? fallback()
                      : Image.memory(bytes, fit: BoxFit.cover),
                ),
    );
  }
}

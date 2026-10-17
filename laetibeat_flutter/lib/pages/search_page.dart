import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

import '../animations.dart';
import '../widgets/player/cover_provider.dart';
import '../widgets/player/player_provider.dart';
import '../widgets/player/player_right_pane.dart';
import '../widgets/settings/music_library_provider.dart';
import '../widgets/two_pane_layout.dart';

/// 搜索结果类型
enum _SearchFilter { track, artist, album }

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();

  //右区播放面板,点击搜索结果后仍复用同一播放器
  final GlobalKey<PlayerRightPaneState> _rightPaneKey =
      GlobalKey<PlayerRightPaneState>();

  _SearchFilter _filter = _SearchFilter.track;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _filterLabel => switch (_filter) {
        _SearchFilter.track => '曲目',
        _SearchFilter.artist => '艺术家',
        _SearchFilter.album => '专辑',
      };

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
          //搜索框
          M3ESearchBar(
            controller: _controller,
            hintText: '搜索曲目、艺术家、专辑',
            leading: const Icon(M3EIcons.search),
            autoFocus: true,
            showClearButton: true,
            margin: 0,
            focusedMargin: 0,
            onChanged: (value) => setState(() => _query = value),
          ),
          SizedBox(height: theme.spacing.lg),
          //结果类型切换(保持内容自适应宽度,与音乐库页一致)
          Align(
            alignment: Alignment.centerLeft,
            child: M3ESplitButton<_SearchFilter>(
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
          ),
          SizedBox(height: theme.spacing.lg),
          Expanded(
            child: _buildResults(theme, scheme, music.value),
          ),
        ],
      ),
    );
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
      onTap: (i) => ref.read(playerProvider.notifier).load(
            results,
            i,
            source: '搜索',
          ),
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
          ref.read(playerProvider.notifier).load(
                tracks,
                0,
                source: artist.name,
              );
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
          ref.read(playerProvider.notifier).load(
                tracks,
                0,
                source: album.title,
              );
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
          supportingText:
              '${album.artist}$year · ${album.trackCount} 首曲目',
        );
      },
    );
  }

  static bool _matches(String value, String query) =>
      value.toLowerCase().contains(query);

  //空态/无结果提示
  Widget _hint(
    M3EThemeData theme,
    M3EColorScheme scheme,
    String title,
    String? detail,
  ) {
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
        ],
      ),
    );
  }
}

//搜索结果行首封面:懒加载曲目封面,无封面回退占位图标
class _CoverThumb extends ConsumerWidget {
  const _CoverThumb({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final size = theme.spacing.xxl * 1.5;
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipRRect(
      borderRadius: M3EDimensions.borderRadiusSmall,
      child: SizedBox(
        width: size,
        height: size,
        child: hasArt
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  size: 24,
                  color: scheme.onSecondaryContainer,
                ),
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
  });

  final M3EThemeData theme;
  final M3EColorScheme scheme;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return M3EShapeContainer.square(
      width: theme.spacing.xxl * 1.5,
      height: theme.spacing.xxl * 1.5,
      color: scheme.secondaryContainer,
      child: Icon(icon, size: 24),
    );
  }
}

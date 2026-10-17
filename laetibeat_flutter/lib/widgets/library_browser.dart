import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import '../animations.dart';
import 'settings/music_library_provider.dart';
import 'player/player_provider.dart';
import 'player/cover_provider.dart';

//音乐库浏览筛选
enum LibraryFilter { track, artist, album }

//音乐库左侧浏览面板:标题+筛选按钮+列表
class LibraryBrowser extends ConsumerStatefulWidget {
  const LibraryBrowser({
    super.key,
    //点击某行时的回调,由页面打开右侧详情
    this.onSelect,
  });

  final void Function(String headline, String supporting)? onSelect;

  @override
  ConsumerState<LibraryBrowser> createState() => _LibraryBrowserState();
}

class _LibraryBrowserState extends ConsumerState<LibraryBrowser> {
  LibraryFilter _filter = LibraryFilter.track;

  /// 当前在左侧面板内打开的专辑;非 null 时专辑视图显示详情而非网格
  _LibRow? _openedAlbum;

  //控制列表选中高亮(长按/点leading切换);曲目与艺术家/专辑共用,切换筛选时清空
  final M3ESelectionController _selectionController = M3ESelectionController();

  @override
  void dispose() {
    _selectionController.dispose();
    super.dispose();
  }

  String get _filterLabel => switch (_filter) {
        LibraryFilter.track => '曲目',
        LibraryFilter.artist => '艺术家',
        LibraryFilter.album => '专辑',
      };

  @override
  Widget build(BuildContext context) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //筛选按钮
          M3ESplitButton<LibraryFilter>(
            items: const [
              M3ESplitButtonItem(
                value: LibraryFilter.track,
                child: Text('曲目'),
              ),
              M3ESplitButtonItem(
                value: LibraryFilter.artist,
                child: Text('艺术家'),
              ),
              M3ESplitButtonItem(
                value: LibraryFilter.album,
                child: Text('专辑'),
              ),
            ],
            selectedValue: _filter,
            label: _filterLabel,
            style: M3EButtonStyle.filled,
            size: M3EButtonSize.md,
            shape: M3EButtonShape.round,
            onSelected: (v) => setState(() {
              _selectionController.clear();
              _filter = v;
              // 切换筛选时退出专辑详情,避免状态残留
              _openedAlbum = null;
            }),
          ),
          SizedBox(height: theme.spacing.lg),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: _buildBody(theme, scheme, music.value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    M3EThemeData theme,
    M3EColorScheme scheme,
    MusicLibraryState? st,
  ) {
    //扫描中或目录为空:加载指示
    if (st == null || st.isLoading) {
      return Padding(
        padding: EdgeInsets.only(top: theme.spacing.xxl),
        child: Center(
          child: M3ELoadingIndicator(
            color: scheme.primary,
            containerColor: scheme.surfaceContainerHighest,
          ),
        ),
      );
    }

    //扫描出错
    if (st.error != null && st.tracks.isEmpty) {
      return _hint(theme, scheme, '扫描失败', st.error);
    }

    //没有歌曲
    if (st.tracks.isEmpty) {
      return _hint(theme, scheme, '音乐库为空', '请在设置-内容中选择目录并扫描');
    }

    //三种视图:曲目/艺术家为列表,专辑为封面卡片网格(点卡片在面板内进详情)
    return switch (_filter) {
      LibraryFilter.track => _buildCardList(theme, scheme, _trackRows(st.tracks)),
      LibraryFilter.artist => _buildCardList(theme, scheme, _artistRows(st.tracks)),
      LibraryFilter.album => _openedAlbum == null
          ? _buildAlbumGrid(theme, scheme, _albumRows(st.tracks))
          : _buildAlbumDetail(theme, scheme, st.tracks, _openedAlbum!),
    };
  }

  //专辑详情:在左侧面板内展示(返回 + 封面 + 专辑信息 + 曲目列表),
  //替代原先右侧面板的占位详情。
  Widget _buildAlbumDetail(
    M3EThemeData theme,
    M3EColorScheme scheme,
    List<rust.UiTrack> allTracks,
    _LibRow album,
  ) {
    final tracks = [
      for (final t in allTracks)
        if (_albumNameOf(t) == album.headline &&
            _artistNameOf(t) == album.supporting)
          t,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        //返回专辑网格
        Row(
          children: [
            M3EIconButton(
              size: M3EIconButtonSize.sm,
              icon: const Icon(Icons.arrow_back),
              tooltip: '返回专辑',
              onPressed: () => setState(() => _openedAlbum = null),
            ),
            SizedBox(width: theme.spacing.sm),
            Text('专辑', style: theme.typeScale.titleMedium),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        //专辑信息:封面 + 名称/艺术家/曲目数
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: M3EDimensions.borderRadiusMedium,
              child: SizedBox(
                width: 132,
                height: 132,
                child: album.track == null
                    ? ColoredBox(
                        color: scheme.secondaryContainer,
                        child: Icon(
                          M3EIcons.music_note,
                          size: 48,
                          color: scheme.onSecondaryContainer,
                        ),
                      )
                    : _AlbumCover(track: album.track!),
              ),
            ),
            SizedBox(width: theme.spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    album.headline,
                    style: theme.typeScale.headlineSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    album.supporting,
                    style: theme.typeScale.bodyLarge.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: theme.spacing.sm),
                  Text(
                    '${tracks.length} 首曲目',
                    style: theme.typeScale.labelMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  // 专辑操作:立即播放 / 随机播放 / 添加到歌单 / 下载
                  SizedBox(height: theme.spacing.md),
                  Wrap(
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.sm,
                    children: [
                      M3EButton(
                        size: M3EButtonSize.sm,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('立即播放'),
                        style: M3EButtonStyle.filled,
                        onPressed: tracks.isEmpty
                            ? null
                            : () => _playAlbumSequential(
                                  tracks,
                                  album.headline,
                                ),
                      ),
                      M3EButton(
                        size: M3EButtonSize.sm,
                        icon: const Icon(Icons.shuffle),
                        label: const Text('随机播放'),
                        style: M3EButtonStyle.tonal,
                        onPressed: tracks.isEmpty
                            ? null
                            : () => _playAlbumShuffled(
                                  tracks,
                                  album.headline,
                                ),
                      ),
                      M3EButton(
                        size: M3EButtonSize.sm,
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('添加到歌单'),
                        style: M3EButtonStyle.tonal,
                        // 仅按钮占位,逻辑后续接入
                        onPressed: () {},
                      ),
                      M3EButton(
                        size: M3EButtonSize.sm,
                        icon: const Icon(Icons.download),
                        label: const Text('下载'),
                        style: M3EButtonStyle.tonal,
                        // 仅按钮占位,逻辑后续接入
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        //曲目列表:点击整行以该专辑为播放队列并从该曲开始
        Expanded(
          child: tracks.isEmpty
              ? _hint(theme, scheme, '暂无曲目', null)
              : M3EList.scrollable(
                  itemCount: tracks.length,
                  onTap: (i) => _playAlbum(tracks, i, album.headline),
                  itemBuilder: (context, i) => M3EListItem(
                    // 左侧:序号 + 歌名 + 歌手名
                    leading: SizedBox(
                      width: 28,
                      child: Text(
                        '${i + 1}'.padLeft(2, '0'),
                        textAlign: TextAlign.center,
                        style: theme.typeScale.labelMedium.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    headline: tracks[i].title,
                    supportingText: _artistNameOf(tracks[i]),
                    // 右侧:时长 + 三点菜单
                    trailingText: tracks[i].duration,
                    trailing: _moreMenu(),
                  ),
                ),
        ),
      ],
    );
  }

  void _playAlbum(List<rust.UiTrack> tracks, int index, String albumName) {
    ref
        .read(playerProvider.notifier)
        .load(tracks, index, source: albumName);
  }

  //立即播放:队列仅含该专辑曲目,顺序播放(关闭随机)
  void _playAlbumSequential(List<rust.UiTrack> tracks, String albumName) {
    ref
        .read(playerProvider.notifier)
        .playSequential(tracks, source: albumName);
  }

  //随机播放:队列仅含该专辑曲目,随机起点并随机切歌
  void _playAlbumShuffled(List<rust.UiTrack> tracks, String albumName) {
    ref
        .read(playerProvider.notifier)
        .playShuffled(tracks, source: albumName);
  }

  static String _albumNameOf(rust.UiTrack t) =>
      t.album.trim().isEmpty ? '未知专辑' : t.album;

  static String _artistNameOf(rust.UiTrack t) =>
      t.artist.trim().isEmpty ? '未知艺术家' : t.artist;

  //专辑视图:封面卡片网格。列数随可用宽度自适应,卡片高度=正方形封面+文字区,
  //保证封面始终显示为完整正方形。
  Widget _buildAlbumGrid(
    M3EThemeData theme,
    M3EColorScheme scheme,
    List<_LibRow> albums,
  ) {
    final spacing = theme.spacing.md;
    final titleStyle = theme.typeScale.titleMedium;
    final subStyle = theme.typeScale.bodyMedium;
    final scaler = MediaQuery.textScalerOf(context);

    //文字区高度:标题 + 间距 + 副标题 + 上下内边距,按当前文字缩放计算,
    //并额外留一点余量,避免字体行高差异导致网格单元内纵向溢出。
    final textBlock = scaler.scale(titleStyle.fontSize ?? 16) *
            (titleStyle.height ?? 1.4) +
        theme.spacing.xs +
        scaler.scale(subStyle.fontSize ?? 14) * (subStyle.height ?? 1.4) +
        theme.spacing.sm * 2 +
        8;

    return LayoutBuilder(
      builder: (context, c) {
        //目标单卡宽度约 170,列数四舍五入,单卡宽度保持 140~200 区间
        final columns = (c.maxWidth / 170).round().clamp(1, 8);
        final itemWidth =
            (c.maxWidth - spacing * (columns - 1)) / columns;
        return ScrollConfiguration(
          behavior:
              ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: GridView.builder(
            padding: EdgeInsets.only(bottom: theme.spacing.sm),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              mainAxisExtent: itemWidth + textBlock,
            ),
            itemCount: albums.length,
            itemBuilder: (context, i) =>
                _albumCard(theme, scheme, albums[i]),
          ),
        );
      },
    );
  }

  //单张专辑卡片:上方完整正方形封面,下方专辑名 + 艺术家名
  Widget _albumCard(
    M3EThemeData theme,
    M3EColorScheme scheme,
    _LibRow album,
  ) {
    final titleStyle = theme.typeScale.titleMedium;
    final subStyle = theme.typeScale.bodyMedium;

    return M3ECard(
      key: ValueKey('${album.headline}|${album.supporting}'),
      variant: M3ECardVariant.filled,
      color: scheme.surfaceContainer,
      borderRadius: M3EDimensions.borderRadiusMedium,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      expanded: true,
      semanticLabel: '${album.headline}, ${album.supporting}',
      // 专辑不再打开右侧详情,改为在左侧面板内切换到专辑详情
      onPressed: () => setState(() => _openedAlbum = album),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          //完整正方形封面:宽度铺满卡片,高度同比
          AspectRatio(
            aspectRatio: 1,
            child: album.track == null
                ? ColoredBox(
                    color: scheme.secondaryContainer,
                    child: Icon(
                      M3EIcons.music_note,
                      size: 48,
                      color: scheme.onSecondaryContainer,
                    ),
                  )
                : _AlbumCover(track: album.track!),
          ),
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  album.headline,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  album.supporting,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: subStyle.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //统一懒加载卡片列表(曲目/艺术家共用),仅构建可见行
  Widget _buildCardList(
    M3EThemeData theme,
    M3EColorScheme scheme,
    List<_LibRow> rows,
  ) {
    return M3EList.scrollable(
      itemCount: rows.length,
      selection: true,
      selectionController: _selectionController,
      selectionState: const M3EListSelectionState(
        selectedIcon: Icon(M3EIcons.check),
      ),
      onTap: (i) => _onRowTap(rows[i], i),
      onLongPress: (i) => _selectionController.toggle(i),
      itemBuilder: (context, i) => _libItem(theme, scheme, rows[i]),
    );
  }

  //点某行:曲目视图接入真实播放(整库为队列,从该曲开始),停在播放面板;
  //艺术家/专辑视图暂仅展示右侧详情
  void _onRowTap(_LibRow row, int index) {
    if (_filter == LibraryFilter.track) {
      final tracks =
          ref.read(musicLibraryProvider).value?.tracks ??
          const <rust.UiTrack>[];
      if (index < tracks.length) {
        ref.read(playerProvider.notifier).load(tracks, index, source: '曲目');
      }
      return; //曲目播放时展示播放面板,不切详情
    }
    widget.onSelect?.call(row.headline, row.supporting);
  }

  //列表项:leading 显示真实封面(懒加载,无封面回退图标)+三点菜单trailing
  Widget _libItem(
    M3EThemeData theme,
    M3EColorScheme scheme,
    _LibRow row,
  ) {
    return M3EListItem(
      headline: row.headline,
      supportingText: row.supporting,
      leading: row.track == null
          ? M3EShapeContainer.square(
              width: theme.spacing.xxl * 1.5,
              height: theme.spacing.xxl * 1.5,
              color: scheme.secondaryContainer,
              child: Icon(row.icon, size: 24),
            )
          : _RowCover(track: row.track!),
      trailing: _moreMenu(),
    );
  }

  //曲目视图:每首单曲一行
  List<_LibRow> _trackRows(List<rust.UiTrack> tracks) => [
        for (final t in tracks)
          _LibRow(
            t.title,
            '${t.artist} · ${t.album}',
            M3EIcons.music_note,
            track: t,
          ),
      ];

  //艺术家视图:按艺术家去重一行,副文本为曲目数,取每个艺术家的一首代表曲目取封面
  List<_LibRow> _artistRows(List<rust.UiTrack> tracks) {
    final counts = <String, int>{};
    final first = <String, rust.UiTrack>{};
    for (final t in tracks) {
      counts[t.artist] = (counts[t.artist] ?? 0) + 1;
      first.putIfAbsent(t.artist, () => t);
    }
    final rows = [
      for (final e in counts.entries)
        _LibRow(
          e.key,
          '${e.value} 首曲目',
          M3EIcons.music_note,
          track: first[e.key],
        ),
    ]..sort((a, b) => a.headline.compareTo(b.headline));
    return rows;
  }

  //专辑视图:按「专辑名 + 艺术家」去重(同名不同艺术家的专辑不合并),
  //取每张专辑的一首代表曲目取封面
  List<_LibRow> _albumRows(List<rust.UiTrack> tracks) {
    final byAlbum = <(String, String), rust.UiTrack>{};
    for (final t in tracks) {
      byAlbum.putIfAbsent((_albumNameOf(t), _artistNameOf(t)), () => t);
    }
    final rows = [
      for (final e in byAlbum.entries)
        _LibRow(
          e.key.$1,
          e.key.$2,
          M3EIcons.music_note,
          track: e.value,
        ),
    ]..sort((a, b) => a.headline.compareTo(b.headline));
    return rows;
  }

  //竖向三点菜单(由M3EMenu管理overlay,不依赖MaterialLocalizations)
  Widget _moreMenu() {
    return M3EMenu.entries(
      position: M3EMenuAnchorPosition.bottomEnd,
      entries: const [
        M3EMenuEntry(label: '播放'),
        M3EMenuEntry(label: '加入播放队列'),
        M3EMenuEntry(label: '查看详情'),
      ],
      anchorBuilder: (context, open) => M3EIconButton(
        size: M3EIconButtonSize.xs,
        icon: const Icon(Icons.more_vert),
        tooltip: '更多',
        onPressed: open,
      ),
    );
  }

  //空态提示
  Widget _hint(
    M3EThemeData theme,
    M3EColorScheme scheme,
    String title,
    String? detail,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.typeScale.titleMedium),
          if (detail != null) ...[
            SizedBox(height: theme.spacing.sm),
            Text(
              detail,
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

//列表行数据:标题+副文本+图标(音乐库三视图共用)+代表曲目(用于取封面)
class _LibRow {
  const _LibRow(this.headline, this.supporting, this.icon, {this.track});

  final String headline;
  final String supporting;
  final IconData icon;

  /// 代表曲目,用于读取/展示封面;为 null 时该行显示图标占位
  final rust.UiTrack? track;
}

//带封面的行首图:懒加载曲目封面 bytes,无封面回退占位图标
class _RowCover extends ConsumerWidget {
  const _RowCover({required this.track});

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

//专辑卡片封面:铺满正方形区域(由外层 AspectRatio 保证 1:1),
//沿用曲目封面来源与缓存,无封面回退占位图标
class _AlbumCover extends ConsumerWidget {
  const _AlbumCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ColoredBox(
      color: scheme.secondaryContainer,
      child: hasArt
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            )
          : Center(
              child: Icon(
                M3EIcons.music_note,
                size: 48,
                color: scheme.onSecondaryContainer,
              ),
            ),
    );
  }
}
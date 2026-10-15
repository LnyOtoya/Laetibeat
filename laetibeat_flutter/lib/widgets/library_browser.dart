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

    //三种视图渲染一致,仅数据不同;统一懒加载卡片列表(只构建可见行)
    return switch (_filter) {
      LibraryFilter.track => _buildCardList(theme, scheme, _trackRows(st.tracks)),
      LibraryFilter.artist => _buildCardList(theme, scheme, _artistRows(st.tracks)),
      LibraryFilter.album => _buildCardList(theme, scheme, _albumRows(st.tracks)),
    };
  }

  //统一懒加载卡片列表(曲目/艺术家/专辑共用),仅构建可见行
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

  //专辑视图:按专辑去重一行,副文本为所属艺术家,取每张专辑的一首代表曲目取封面
  List<_LibRow> _albumRows(List<rust.UiTrack> tracks) {
    final byAlbum = <String, rust.UiTrack>{};
    for (final t in tracks) {
      byAlbum.putIfAbsent(t.album, () => t);
    }
    final rows = [
      for (final e in byAlbum.entries)
        _LibRow(
          e.key,
          e.value.artist,
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
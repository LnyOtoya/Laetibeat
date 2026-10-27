import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/library_page.dart';
import 'pages/settings_page.dart';
import 'pages/playlist_page.dart';
import 'pages/chart_page.dart';
import 'widgets/player/mini_player.dart';

class NavShell extends StatefulWidget {
  const NavShell({super.key});

  @override
  State<NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<NavShell> {
  static const _animDuration = Duration(milliseconds: 280);
  static const _animCurve = Curves.easeOutCubic;

  // 导航项与页面一一对应；搜索页额外放在末尾，由 FAB 触发
  static const int _searchPageIndex = 5;

  int _selectedIndex = 0;
  int _pageIndex = 0;

  static const List<Widget> _pages = [
    HomePage(),
    LibraryPage(),
    SettingsPage(),
    PlaylistPage(),
    ChartPage(),
    SearchPage(),
  ];

  // 侧边栏固定展开，不使用 section headers
  static const List<M3ENavigationRailDestination> _destinations = [
    M3ENavigationRailDestination(
      icon: Icon(M3EIcons.home),
      label: 'Home',
    ),
    M3ENavigationRailDestination(
      icon: Icon(M3EIcons.music_note),
      label: 'Library',
    ),
    M3ENavigationRailDestination(
      icon: Icon(M3EIcons.settings),
      label: 'Settings',
    ),
    M3ENavigationRailDestination(
      icon: Icon(M3EIcons.queue_music),
      label: 'Playlists',
    ),
    M3ENavigationRailDestination(
      icon: Icon(M3EIcons.bar_chart),
      label: 'Charts',
    ),
  ];

  // 移动端 NavigationBar：搜索从桌面 FAB 变成普通目的地
  // 顺序即展示顺序，值为对应的 _pages 索引
  static const List<int> _mobilePageOrder = [0, 1, 5, 3, 4, 2];

  static const List<M3ENavigationBarDestination> _mobileDestinations = [
    M3ENavigationBarDestination(
      icon: Icon(M3EIcons.home),
      label: 'Home',
    ),
    M3ENavigationBarDestination(
      icon: Icon(M3EIcons.music_note),
      label: 'Library',
    ),
    M3ENavigationBarDestination(
      icon: Icon(M3EIcons.search),
      label: 'Search',
    ),
    M3ENavigationBarDestination(
      icon: Icon(M3EIcons.queue_music),
      label: 'Playlists',
    ),
    M3ENavigationBarDestination(
      icon: Icon(M3EIcons.bar_chart),
      label: 'Charts',
    ),
    M3ENavigationBarDestination(
      icon: Icon(M3EIcons.settings),
      label: 'Settings',
    ),
  ];

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex && _pageIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _pageIndex = index;
    });
  }

  // FAB：进入搜索页，此时侧边栏不显示选中项
  void _openSearch() {
    if (_pageIndex == _searchPageIndex) return;
    setState(() {
      _selectedIndex = -1;
      _pageIndex = _searchPageIndex;
    });
  }

  int get _mobileSelectedIndex {
    final index = _mobilePageOrder.indexOf(_pageIndex);
    return index < 0 ? 0 : index;
  }

  void _onMobileDestinationSelected(int index) {
    if (index < 0 || index >= _mobilePageOrder.length) return;
    final pageIndex = _mobilePageOrder[index];
    setState(() {
      _pageIndex = pageIndex;
      _selectedIndex = pageIndex == _searchPageIndex ? -1 : pageIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;

    // 移动端：底部 NavigationBar，搜索作为其中一个目的地
    if (!isDesktop) {
      return Scaffold(
        // 页面内容自身负责底色；toolbar 外圈不再有独立底栏背景
        backgroundColor: theme.colorScheme.surfaceContainer,
        body: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: _pages[_pageIndex],
              ),
            ),
            // 浮动在页面内容之上；周围留白直接透出页面内容
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(),
            ),
          ],
        ),
        bottomNavigationBar: M3ENavigationBar(
          destinations: _mobileDestinations,
          selectedIndex: _mobileSelectedIndex,
          onDestinationSelected: _onMobileDestinationSelected,
          size: M3ENavBarSize.small,
          density: M3ENavBarDensity.compact,
          labelBehavior: M3ENavBarLabelBehavior.onlySelected,
        ),
      );
    }

    return Scaffold(
      body: AnimatedContainer(
        duration: _animDuration,
        curve: _animCurve,
        color: theme.colorScheme.surfaceContainer,
        child: Row(
          children: [
            M3ENavigationRail(
              background: theme.colorScheme.surfaceContainer,
              sections: const [
                M3ENavigationRailSection(destinations: _destinations),
              ],
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              type: M3ENavigationRailType.alwaysExpand,
              modality: M3ENavigationRailModality.standard,
              labelBehavior: M3ENavigationRailLabelBehavior.alwaysShow,
              fab: M3ENavigationRailFabSlot(
                icon: const Icon(M3EIcons.search),
                label: 'Search',
                onPressed: _openSearch,
              ),
              expandedWidth: 220,
            ),
            Expanded(
              child: Column(
                children: [
                  // 自定义窗口按钮只在桌面端显示
                  if (isDesktop) _buildTitleBar(),
                  Expanded(
                    child: _pages[_pageIndex],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 自定义顶栏
  Widget _buildTitleBar() {
    final theme = M3ETheme.of(context);

    return DragToMoveArea(
      child: AnimatedContainer(
        duration: _animDuration,
        curve: _animCurve,
        color: theme.colorScheme.surfaceContainer,
        // height: theme.spacing.xxl,
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.xs,
        ),
        child: Row(
          children: [
            Expanded(child: SizedBox()),
            M3EIconButton(
              size: M3EIconButtonSize.xs,
              icon: const Icon(M3EIcons.minimize),
              tooltip: '最小化',
              onPressed: () => windowManager.minimize(),
            ),
            M3EIconButton(
              size: M3EIconButtonSize.xs,
              icon: const Icon(M3EIcons.crop_square),
              tooltip: '最大化',
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            M3EIconButton(
              size: M3EIconButtonSize.xs,
              icon: const Icon(M3EIcons.close),
              tooltip: '关闭',
              onPressed: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}

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

  // 移动端底部导航栏的显隐控制（配合 hideOnScroll）
  final M3ENavigationBarController _navBarController =
      M3ENavigationBarController();

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

  // 移动端 NavigationBar：只保留首页/音乐库/搜索
  // 歌单、图表、设置改由首页 AppBar 右侧按钮进入
  static const List<int> _mobilePageOrder = [0, 1, 5];

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
    _showNavBar();
  }

  // 首页 AppBar 的快捷入口：歌单/图表/设置
  void _openPage(int pageIndex) {
    if (_pageIndex == pageIndex) return;
    setState(() {
      _pageIndex = pageIndex;
      _selectedIndex = pageIndex == _searchPageIndex ? -1 : pageIndex;
    });
    _showNavBar();
  }

  void _showNavBar() {
    _navBarController.show();
  }

  // 跟随页面最外层纵向滚动控制底部导航栏显隐
  bool _onPageScroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    // 回到顶部时始终显示
    if (notification.metrics.pixels <= 0) {
      _showNavBar();
      return false;
    }
    if (notification is ScrollUpdateNotification) {
      final double delta = notification.scrollDelta ?? 0;
      if (delta > 0) {
        _navBarController.hide();
      } else if (delta < 0) {
        _showNavBar();
      }
    }
    return false;
  }

  @override
  void dispose() {
    _navBarController.dispose();
    super.dispose();
  }

  Widget _buildHomeAppBar(M3EThemeData theme) {
    return M3EAppBar.top(
      titleText: '首页',
      variant: M3EAppBarVariant.small,
      hideMode: M3EAppBarHideMode.entire,
      density: M3EAppBarDensity.regular,
      shapeFamily: M3EAppBarShapeFamily.square,
      safeArea: true,
      backgroundColor: theme.colorScheme.surfaceContainer,
      actions: [
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(M3EIcons.queue_music),
          tooltip: '播放列表',
          onPressed: () => _openPage(3),
        ),
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(M3EIcons.bar_chart),
          tooltip: '图表',
          onPressed: () => _openPage(4),
        ),
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(M3EIcons.settings),
          tooltip: '设置',
          onPressed: () => _openPage(2),
        ),
      ],
    );
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
              child: NotificationListener<ScrollNotification>(
                onNotification: _onPageScroll,
                child: _pageIndex == 0
                    ? Column(
                        children: [
                          // 移动端首页顶部 AppBar
                          _buildHomeAppBar(theme),
                          Expanded(child: _pages[_pageIndex]),
                        ],
                      )
                    : SafeArea(
                        bottom: false,
                        child: _pages[_pageIndex],
                      ),
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
          controller: _navBarController,
          size: M3ENavBarSize.medium,
          density: M3ENavBarDensity.compact,
          shapeFamily: M3ENavBarShapeFamily.square,
          labelBehavior: M3ENavBarLabelBehavior.alwaysShow,
          hideOnScroll: true,
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

import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../pages/chart_page.dart';
import '../../pages/mobile/mobile_home_page.dart';
import '../../pages/mobile/mobile_library_page.dart';
import '../../pages/mobile/mobile_search_page.dart';
import '../../pages/mobile/mobile_settings_page.dart';
import '../../pages/mobile/mobile_sub_page.dart';
import '../../pages/mobile/mini_player.dart';
import '../../pages/playlist_page.dart';
import '../../shared/layout/app_bottom_inset.dart';
import '../app_destination.dart';

/// 移动端专属导航壳：底部 NavigationBar + 浮动 mini player + 路由式二级页面。
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _tabIndex = 0;

  final M3ENavigationBarController _navBarController =
      M3ENavigationBarController();

  static const List<AppDestination> _tabs = [
    AppDestination.home,
    AppDestination.library,
    AppDestination.search,
  ];

  static const List<M3ENavigationBarDestination> _destinations = [
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
    if (index < 0 || index >= _tabs.length) return;
    setState(() => _tabIndex = index);
    _showNavBar();
  }

  void _showNavBar() => _navBarController.show();

  bool _onPageScroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
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

  void _openSubPage(String title, Widget child) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MobileSubPage(title: title, child: child),
      ),
    );
  }

  Widget _buildHomeTab(M3EThemeData theme) {
    return Column(
      children: [
        M3EAppBar.top(
          titleText: '首页',
          variant: M3EAppBarVariant.small,
          hideMode: M3EAppBarHideMode.none,
          shapeFamily: M3EAppBarShapeFamily.square,
          safeArea: true,
          backgroundColor: theme.colorScheme.surfaceContainer,
          actions: [
            M3EIconButton(
              variant: M3EIconButtonVariant.standard,
              icon: const Icon(M3EIcons.queue_music),
              tooltip: '播放列表',
              onPressed: () => _openSubPage('播放列表', const PlaylistPage()),
            ),
            M3EIconButton(
              variant: M3EIconButtonVariant.standard,
              icon: const Icon(M3EIcons.bar_chart),
              tooltip: '图表',
              onPressed: () => _openSubPage('图表', const ChartPage()),
            ),
            M3EIconButton(
              variant: M3EIconButtonVariant.standard,
              icon: const Icon(M3EIcons.settings),
              tooltip: '设置',
              onPressed: () => _openSubPage('设置', const MobileSettingsPage()),
            ),
          ],
        ),
        const Expanded(child: MobileHomePage()),
      ],
    );
  }

  Widget _buildTab(AppDestination destination, M3EThemeData theme) {
    return switch (destination) {
      AppDestination.home => _buildHomeTab(theme),
      AppDestination.library => const SafeArea(
          bottom: false,
          child: MobileLibraryPage(),
        ),
      AppDestination.search => const SafeArea(
          bottom: false,
          child: MobileSearchPage(),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  void dispose() {
    _navBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      body: Stack(
        children: [
          Positioned.fill(
            child: AppBottomInsetScope(
              bottomInset: kMiniPlayerReservedHeight,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onPageScroll,
                child: IndexedStack(
                  index: _tabIndex,
                  children: [
                    for (final tab in _tabs) _buildTab(tab, theme),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: M3ENavigationBar(
        destinations: _destinations,
        selectedIndex: _tabIndex,
        onDestinationSelected: _onDestinationSelected,
        controller: _navBarController,
        size: M3ENavBarSize.medium,
        density: M3ENavBarDensity.compact,
        shapeFamily: M3ENavBarShapeFamily.square,
        labelBehavior: M3ENavBarLabelBehavior.alwaysShow,
        hideOnScroll: true,
      ),
    );
  }
}

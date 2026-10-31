import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../pages/chart_page.dart';
import '../../pages/desktop/desktop_home_page.dart';
import '../../pages/desktop/desktop_library_page.dart';
import '../../pages/desktop/desktop_search_page.dart';
import '../../pages/desktop/desktop_settings_page.dart';
import '../../pages/playlist_page.dart';
import '../app_destination.dart';
import 'desktop_title_bar.dart';

/// 桌面端专属导航壳：NavigationRail + 自定义标题栏 + 双栏页面。
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  AppDestination _current = AppDestination.home;

  static const List<AppDestination> _railOrder = [
    AppDestination.home,
    AppDestination.library,
    AppDestination.settings,
    AppDestination.playlists,
    AppDestination.charts,
  ];

  static const Map<AppDestination, Widget> _pages = {
    AppDestination.home: DesktopHomePage(),
    AppDestination.library: DesktopLibraryPage(),
    AppDestination.settings: DesktopSettingsPage(),
    AppDestination.playlists: PlaylistPage(),
    AppDestination.charts: ChartPage(),
    AppDestination.search: DesktopSearchPage(),
  };

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

  int get _selectedIndex => _railOrder.indexOf(_current);

  void _open(AppDestination destination) {
    if (_current == destination) return;
    setState(() => _current = destination);
  }

  void _openSearch() => _open(AppDestination.search);

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      body: Container(
        color: theme.colorScheme.surfaceContainer,
        child: Row(
          children: [
            M3ENavigationRail(
              background: theme.colorScheme.surfaceContainer,
              sections: const [
                M3ENavigationRailSection(destinations: _destinations),
              ],
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                if (index < 0 || index >= _railOrder.length) return;
                _open(_railOrder[index]);
              },
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
                  const DesktopTitleBar(),
                  Expanded(child: _pages[_current]!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

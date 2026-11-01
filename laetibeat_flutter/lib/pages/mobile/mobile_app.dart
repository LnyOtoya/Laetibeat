import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_destination.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/feedback/app_haptics.dart';
import '../../shared/layout/app_bottom_inset.dart';
import '../../widgets/player/player_provider.dart';
import 'home/mobile_home_page.dart';
import 'library/mobile_library_page.dart';
import 'mobile_navigation.dart';
import 'player/mini_player.dart';
import 'routes.dart';
import 'search/mobile_search_page.dart';
import 'settings/content/mobile_content_settings_page.dart';
import 'settings/mobile_settings_page.dart';
import 'stats/mobile_stats_page.dart';

/// 移动端 Shell。
///
/// [child] 是 MaterialApp 的根 Navigator。所有页面都在这条 Navigator 上，
/// Shell 只负责底部导航、MiniPlayer 和底部 inset。
class MobileShell extends ConsumerWidget {
  const MobileShell({super.key, required this.child});

  final Widget child;

  static const List<AppDestination> _tabs = [
    AppDestination.home,
    AppDestination.library,
    AppDestination.search,
  ];

  List<M3ENavigationBarDestination> _destinations(AppLocalizations l10n) {
    return [
      M3ENavigationBarDestination(
        icon: const Icon(M3EIcons.home),
        label: l10n.navHome,
      ),
      M3ENavigationBarDestination(
        icon: const Icon(M3EIcons.music_note),
        label: l10n.navLibrary,
      ),
      M3ENavigationBarDestination(
        icon: const Icon(M3EIcons.search),
        label: l10n.navSearch,
      ),
    ];
  }

  AppDestination? _tabForRoute(String? route) {
    if (route == null || route == MobileRoutes.home) {
      return AppDestination.home;
    }
    if (route == MobileRoutes.search) return AppDestination.search;
    if (route == MobileRoutes.library || route.startsWith('/library/')) {
      return AppDestination.library;
    }
    return null;
  }

  bool _showNavigationBar(String? route) {
    const visible = <String>{
      MobileRoutes.home,
      MobileRoutes.library,
      MobileRoutes.librarySongs,
      MobileRoutes.libraryPlaylists,
      MobileRoutes.libraryArtists,
      MobileRoutes.libraryAlbums,
      MobileRoutes.libraryPodcasts,
      MobileRoutes.search,
    };
    return visible.contains(route);
  }

  void _selectTab(AppDestination destination) {
    final NavigatorState? navigator = mobileNavigatorKey.currentState;
    if (navigator == null) return;
    final String? current = mobileCurrentRouteName.value;

    switch (destination) {
      case AppDestination.home:
        if (current == MobileRoutes.home) return;
        navigator.popUntil((Route<dynamic> route) => route.isFirst);
        return;
      case AppDestination.library:
        if (current == MobileRoutes.library ||
            (current?.startsWith('/library/') ?? false)) {
          navigator.popUntil(
            (Route<dynamic> route) =>
                route.isFirst || route.settings.name == MobileRoutes.library,
          );
          return;
        }
        navigator.pushNamed(MobileRoutes.library);
        return;
      case AppDestination.search:
        if (current == MobileRoutes.search) return;
        navigator.pushNamed(MobileRoutes.search);
        return;
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final bool hasTrack = ref.watch(
      playerProvider.select((state) => state.current != null),
    );

    return ValueListenableBuilder<String?>(
      valueListenable: mobileCurrentRouteName,
      builder: (BuildContext context, String? routeName, Widget? _) {
        final AppDestination tab =
            _tabForRoute(routeName) ?? AppDestination.home;
        final int selectedIndex = _tabs.indexOf(tab);
        final bool showNavigationBar = _showNavigationBar(routeName);
        final bool showMiniPlayer = hasTrack && showNavigationBar;

        return TapHapticDetector(
          child: Scaffold(
            backgroundColor: theme.colorScheme.surfaceContainer,
            body: Stack(
              children: [
                Positioned.fill(
                  child: AppBottomInsetScope(
                    bottomInset: showMiniPlayer ? kMiniPlayerReservedHeight : 0,
                    child: child,
                  ),
                ),
                if (showMiniPlayer)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: MiniPlayer(),
                  ),
              ],
            ),
            bottomNavigationBar: showNavigationBar
                ? M3ENavigationBar(
                    destinations: _destinations(l10n),
                    selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                    onDestinationSelected: (int index) {
                      if (index < 0 || index >= _tabs.length) return;
                      _selectTab(_tabs[index]);
                    },
                    size: M3ENavBarSize.medium,
                    density: M3ENavBarDensity.compact,
                    shapeFamily: M3ENavBarShapeFamily.square,
                    labelBehavior: M3ENavBarLabelBehavior.alwaysShow,
                  )
                : null,
          ),
        );
      },
    );
  }
}

/// 移动端根 Navigator 的路由表。
///
/// 所有页面都在同一条 Navigator 上，预测性返回由 Flutter 原生处理，
/// 不再使用根 Navigator / 嵌套 Navigator 交错的导航方式。
Route<dynamic>? mobileOnGenerateRoute(RouteSettings settings) {
  final Widget page = switch (settings.name) {
    MobileRoutes.home => const MobileHomePage(),
    MobileRoutes.library || MobileRoutes.librarySongs =>
      const MobileLibraryPage(section: LibrarySection.songs),
    MobileRoutes.libraryPlaylists => const MobileLibraryPage(
      section: LibrarySection.playlists,
    ),
    MobileRoutes.libraryArtists => const MobileLibraryPage(
      section: LibrarySection.artists,
    ),
    MobileRoutes.libraryAlbums => const MobileLibraryPage(
      section: LibrarySection.albums,
    ),
    MobileRoutes.libraryPodcasts => const MobileLibraryPage(
      section: LibrarySection.podcasts,
    ),
    MobileRoutes.search => const MobileSearchPage(),
    MobileRoutes.stats => const MobileStatsPage(),
    MobileRoutes.settings => const MobileSettingsPage(),
    MobileRoutes.contentSettings => const MobileContentSettingsPage(),
    _ => const MobileHomePage(),
  };

  return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
}

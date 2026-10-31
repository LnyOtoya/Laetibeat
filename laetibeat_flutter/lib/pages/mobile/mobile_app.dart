import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../app/app_destination.dart';

/// 移动端 UI 的唯一入口。
///
/// 这里只保留最基本的 Shell：
/// - 底部三个 Tab：Home / Library / Search
/// - 页面内容先使用占位实现
///
/// 后续重写移动端时，直接替换 [_buildTab] 返回的页面即可。
/// 共享状态通过 Riverpod Provider 获取，例如：
/// `ref.watch(playerProvider)`、`ref.watch(musicLibraryProvider)`。
class MobileApp extends StatefulWidget {
  const MobileApp({super.key});

  @override
  State<MobileApp> createState() => _MobileAppState();
}

class _MobileAppState extends State<MobileApp> {
  int _tabIndex = 0;

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
  }

  Widget _buildTab(AppDestination destination) {
    return switch (destination) {
      AppDestination.home => const _MobilePlaceholder(title: '首页'),
      AppDestination.library => const _MobilePlaceholder(title: '音乐库'),
      AppDestination.search => const _MobilePlaceholder(title: '搜索'),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          for (final tab in _tabs) _buildTab(tab),
        ],
      ),
      bottomNavigationBar: M3ENavigationBar(
        destinations: _destinations,
        selectedIndex: _tabIndex,
        onDestinationSelected: _onDestinationSelected,
        size: M3ENavBarSize.medium,
        density: M3ENavBarDensity.compact,
        shapeFamily: M3ENavBarShapeFamily.square,
        labelBehavior: M3ENavBarLabelBehavior.alwaysShow,
      ),
    );
  }
}

class _MobilePlaceholder extends StatelessWidget {
  const _MobilePlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.typeScale.headlineSmall),
            SizedBox(height: theme.spacing.sm),
            Text(
              '移动端 UI 重写入口',
              style: theme.typeScale.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

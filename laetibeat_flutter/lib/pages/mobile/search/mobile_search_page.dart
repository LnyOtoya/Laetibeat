import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/mobile_app_bar.dart';

/// 移动端搜索页面。
///
/// 当前只完成搜索栏 UI：
/// - M3ESearchAnchor.bar
/// - contained / full screen
/// - leading 搜索图标
/// - avatar 预留搜索源切换入口
class MobileSearchPage extends StatefulWidget {
  const MobileSearchPage({super.key});

  @override
  State<MobileSearchPage> createState() => _MobileSearchPageState();
}

class _MobileSearchPageState extends State<MobileSearchPage> {
  late final M3ESearchController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = M3ESearchController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileTopAppBar(
        context,
        title: M3ESearchAnchor.bar(
          searchController: _searchController,
          suggestionsBuilder: (BuildContext context, M3ESearchController _) {
            return const <Widget>[];
          },
          barHintText: '搜索歌曲、艺人、专辑',
          barLeading: const Icon(M3EIcons.search),
          barAvatar: _SearchSourceAvatar(
            onTap: () {
              // TODO(search-source): 打开搜索源选择面板。
            },
          ),
          isFullScreen: true,
          viewStyle: M3ESearchViewStyle.contained,
          constraints: const BoxConstraints.tightFor(height: 56),
          expandOnFocus: false,
          expandRestPadding: 0,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: Text(
            '搜索',
            style: theme.typeScale.headlineSmall,
          ),
        ),
      ),
    );
  }
}

class _SearchSourceAvatar extends StatelessWidget {
  const _SearchSourceAvatar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Semantics(
      button: true,
      label: '切换搜索源',
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              M3EIcons.library_music,
              size: 18,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

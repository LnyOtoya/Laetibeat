import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../widgets/two_pane_layout.dart';
import '../widgets/player/player_right_pane.dart';
import '../widgets/welcome_section.dart';
import '../widgets/recent_section.dart';
import '../widgets/daily_section.dart';
import '../widgets/history_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final M3ESearchController searchController = M3ESearchController();
  //右区播放/详情状态由此控制,左侧点击时切换
  final GlobalKey<PlayerRightPaneState> _rightPaneKey =
      GlobalKey<PlayerRightPaneState>();

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return TwoPaneLayout(
      leftFlex: 3,
      rightFlex: 2,
      rightMaxWidth: 520,
      left: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          child: Column(
            children: [
              WelcomeSection(),
              SizedBox(height: theme.spacing.md),
              RecentSection(),
              SizedBox(height: theme.spacing.md),
              DailySection(),
              SizedBox(height: theme.spacing.md),
              HistorySection(),
            ],
          ),
        ),
      ),
      right: PlayerRightPane(key: _rightPaneKey),
    );
  }

  // 搜索栏(先不放了不合适感觉)
  Widget _buildSearchBar() {
    return M3ESearchAnchor.bar(
      searchController: searchController,
      barHintText: 'Search',
      shrinkWrap: true,
      suggestionsBuilder: (context, controller) => const <Widget>[],
    );
  }
}
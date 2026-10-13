import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../animations.dart';
import '../widgets/two_pane_layout.dart';
import '../widgets/player/player_right_pane.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  //右区播放/详情状态由此控制,搜索时切换为搜索结果
  final GlobalKey<PlayerRightPaneState> _rightPaneKey =
      GlobalKey<PlayerRightPaneState>();

  @override
  Widget build(BuildContext context) {
    return TwoPaneLayout(
      leftFlex: 3,
      rightFlex: 2,
      rightMaxWidth: 520,
      left: _pane(context),
      right: PlayerRightPane(key: _rightPaneKey),
    );
  }

  Widget _pane(BuildContext context) {
    final theme = M3ETheme.of(context);
    return AnimatedContainer(
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
    );
  }
}
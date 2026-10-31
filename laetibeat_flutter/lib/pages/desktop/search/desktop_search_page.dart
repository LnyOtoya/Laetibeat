import 'package:flutter/widgets.dart';

import '../layout/two_pane_layout.dart';
import '../player/player_right_pane.dart';
import 'search_view.dart';

class DesktopSearchPage extends StatefulWidget {
  const DesktopSearchPage({super.key});

  @override
  State<DesktopSearchPage> createState() => _DesktopSearchPageState();
}

class _DesktopSearchPageState extends State<DesktopSearchPage> {
  final GlobalKey<PlayerRightPaneState> _rightPaneKey =
      GlobalKey<PlayerRightPaneState>();

  @override
  Widget build(BuildContext context) {
    return SearchView(
      layoutBuilder: (context, content) {
        return TwoPaneLayout(
          leftFlex: 3,
          rightFlex: 2,
          rightMaxWidth: 520,
          left: content,
          right: PlayerRightPane(key: _rightPaneKey),
        );
      },
    );
  }
}

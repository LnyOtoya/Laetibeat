import 'package:flutter/widgets.dart';

import '../home/home_content.dart';
import 'player_right_pane.dart';
import 'two_pane_layout.dart';

class DesktopHomePage extends StatelessWidget {
  const DesktopHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TwoPaneLayout(
      leftFlex: 3,
      rightFlex: 2,
      rightMaxWidth: 520,
      left: HomeContent(),
      right: PlayerRightPane(),
    );
  }
}

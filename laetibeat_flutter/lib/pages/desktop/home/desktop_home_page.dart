import 'package:flutter/widgets.dart';

import '../layout/two_pane_layout.dart';
import '../player/player_right_pane.dart';
import 'home_content.dart';

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

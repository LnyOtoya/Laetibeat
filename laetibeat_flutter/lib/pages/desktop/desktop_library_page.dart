import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../widgets/library_browser.dart';
import 'player_right_pane.dart';
import 'two_pane_layout.dart';

class DesktopLibraryPage extends StatefulWidget {
  const DesktopLibraryPage({super.key});

  @override
  State<DesktopLibraryPage> createState() => _DesktopLibraryPageState();
}

class _DesktopLibraryPageState extends State<DesktopLibraryPage> {
  final GlobalKey<PlayerRightPaneState> _rightPaneKey =
      GlobalKey<PlayerRightPaneState>();

  @override
  Widget build(BuildContext context) {
    return TwoPaneLayout(
      leftFlex: 3,
      rightFlex: 2,
      rightMaxWidth: 520,
      fullBleedSinglePane: true,
      left: LibraryBrowser(onSelect: _openDetail),
      right: PlayerRightPane(key: _rightPaneKey),
    );
  }

  void _openDetail(String headline, String supporting) {
    _rightPaneKey.currentState?.openDetail(
      _DesktopLibraryDetail(title: headline, subtitle: supporting),
    );
  }
}

class _DesktopLibraryDetail extends StatelessWidget {
  const _DesktopLibraryDetail({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    return Align(
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.typeScale.headlineSmall,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            subtitle,
            style: theme.typeScale.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

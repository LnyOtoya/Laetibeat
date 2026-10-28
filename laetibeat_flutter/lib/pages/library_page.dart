import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../widgets/library_browser.dart';
import '../widgets/two_pane_layout.dart';
import '../widgets/player/player_right_pane.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  //右区播放/详情状态由此控制,左侧点击曲目时切换
  final GlobalKey<PlayerRightPaneState> _rightPaneKey =
      GlobalKey<PlayerRightPaneState>();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final singlePane = useSinglePaneLayout(context, constraints.maxWidth);
        return TwoPaneLayout(
          leftFlex: 3,
          rightFlex: 2,
          rightMaxWidth: 520,
          fullBleedSinglePane: true,
          left: LibraryBrowser(
            onSelect: _openDetail,
            sourceSplitAboveContainer: singlePane,
          ),
          right: PlayerRightPane(key: _rightPaneKey),
        );
      },
    );
  }

  //左侧点某行 -> 右侧切到详情视图
  void _openDetail(String headline, String supporting) {
    _rightPaneKey.currentState?.openDetail(
      _LibraryDetail(title: headline, subtitle: supporting),
    );
  }
}

//音乐库详情视图(占位,后续可按曲目/艺术家/专辑定制更多内容)
class _LibraryDetail extends StatelessWidget {
  const _LibraryDetail({required this.title, required this.subtitle});

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
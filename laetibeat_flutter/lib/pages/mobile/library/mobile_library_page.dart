import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/mobile_app_bar.dart';

/// 移动端音乐库页面。
class MobileLibraryPage extends StatefulWidget {
  const MobileLibraryPage({super.key});

  @override
  State<MobileLibraryPage> createState() => _MobileLibraryPageState();
}

class _MobileLibraryPageState extends State<MobileLibraryPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    M3EButtonGroupAction action(IconData icon, String label) {
      return M3EButtonGroupAction(
        icon: Icon(icon),
        label: Text(label),
        decoration: M3EButtonDecoration(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            return states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surfaceContainerHigh;
          }),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileTopAppBar(
        context,
        actions: mobileHomeAppBarActions(context),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: M3EButtonGroup(
                type: M3EButtonGroupType.standard,
                shape: M3EButtonShape.round,
                size: M3EButtonSize.sm,
                style: M3EButtonStyle.filled,
                multiSelect: false,
                selectionRequired: true,
                neighborSquish: true,
                overflow: M3EButtonGroupOverflow.scroll,
                selectedIndex: _selectedIndex,
                onSelectedIndexChanged: (int? index) {
                  if (index == null) return;
                  setState(() => _selectedIndex = index);
                },
                actions: [
                  action(M3EIcons.queue_music, '歌单'),
                  action(M3EIcons.person, '艺术家'),
                  action(M3EIcons.album, '专辑'),
                  action(M3EIcons.music_note, '歌曲'),
                  action(M3EIcons.podcasts, '播客'),
                ],
              ),
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

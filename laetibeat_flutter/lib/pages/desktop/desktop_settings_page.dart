import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../animations.dart';
import '../../widgets/settings/settings_provider.dart';
import '../../widgets/settings/settings_section.dart';
import '../settings/settings_content.dart';
import 'two_pane_layout.dart';

class DesktopSettingsPage extends StatelessWidget {
  const DesktopSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TwoPaneLayout(
      leftFlex: 2,
      rightFlex: 3,
      left: SettingsSection(),
      right: _DesktopSettingsDetail(),
    );
  }
}

class _DesktopSettingsDetail extends ConsumerWidget {
  const _DesktopSettingsDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(settingsCategoryProvider);

    return AnimatedSwitcher(
      duration: kSectionAnimDuration,
      switchInCurve: kSectionAnimCurve,
      switchOutCurve: kSectionAnimCurve,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.topLeft,
          children: [
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey(category),
        child: settingsContent(category),
      ),
    );
  }
}

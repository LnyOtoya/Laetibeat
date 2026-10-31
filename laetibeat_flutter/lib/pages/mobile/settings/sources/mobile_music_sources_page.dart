import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';
import 'opensubsonic/mobile_opensubsonic_config_page.dart';

/// 音乐源配置页面。
class MobileMusicSourcesPage extends StatelessWidget {
  const MobileMusicSourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(
        context,
        title: '音乐源配置',
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            M3EList(
              color: theme.colorScheme.surface,
              variant: M3ECardVariant.filled,
              onTap: (int index) {
                if (index != 0) return;
                pushMobileRootPage(
                  context,
                  const MobileOpensubsonicConfigPage(),
                  name: MobileRoutes.opensubsonicConfig,
                );
              },
              itemCount: 6,
              itemBuilder: (BuildContext context, int index) {
                return switch (index) {
                  0 => const M3EListItem(
                      headline: 'Opensubsonic',
                      supportingText:
                          '连接到您的支持opensubsonic协议的服务器，例如navidrome。',
                    ),
                  1 => const M3EListItem(
                      headline: 'Jellyfin',
                      supportingText: '暂未提供',
                    ),
                  2 => const M3EListItem(
                      headline: 'Emby音乐',
                      supportingText: '暂未提供',
                    ),
                  3 => const M3EListItem(
                      headline: '洛雪音源',
                      supportingText: '暂未提供',
                    ),
                  4 => const M3EListItem(
                      headline: 'qq音乐',
                      supportingText: '暂未提供',
                    ),
                  _ => const M3EListItem(
                      headline: '网易云',
                      supportingText: '暂未提供',
                    ),
                };
              },
            ),
          ],
        ),
      ),
    );
  }
}

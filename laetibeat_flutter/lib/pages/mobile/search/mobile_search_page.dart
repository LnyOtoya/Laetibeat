import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../widgets/mobile_app_bar.dart';
import '../widgets/mobile_search_bar.dart';

/// 移动端搜索页面。
///
/// 搜索栏当前只完成 UI，搜索逻辑后续接入。
class MobileSearchPage extends StatelessWidget {
  const MobileSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileTopAppBar(
        context,
        title: MobileSearchBar(
          avatar: _SearchSourceAvatar(
            onTap: () {
              // TODO(search-source): 打开搜索源选择面板。
            },
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: Text(l10n.searchTitle, style: theme.typeScale.headlineSmall),
        ),
      ),
    );
  }
}

class _SearchSourceAvatar extends StatelessWidget {
  const _SearchSourceAvatar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Semantics(
      button: true,
      label: AppLocalizations.of(context).switchSearchSource,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              M3EIcons.library_music,
              size: 18,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

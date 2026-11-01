import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';

/// 搜索栏的静态外观。
enum MobileSearchBarVariant {
  /// 默认 filled：surfaceContainerHigh 背景，无边框。
  filled,

  /// 描边样式：页面背景 + outlineVariant 边框。
  outlined,
}

/// 移动端搜索栏。
///
/// Search 页和 Settings 页共用同一套视觉配置：
/// - M3ESearchAnchor.bar
/// - contained / full screen
/// - leading 搜索图标
class MobileSearchBar extends StatefulWidget {
  const MobileSearchBar({
    super.key,
    this.hintText,
    this.variant = MobileSearchBarVariant.filled,
    this.avatar,
    this.trailing,
  });

  final String? hintText;
  final MobileSearchBarVariant variant;

  /// 搜索栏右侧头像；为空时不显示。
  final Widget? avatar;

  /// 搜索栏右侧图标；与 avatar 同时使用时最多再放一个。
  final Iterable<Widget>? trailing;

  @override
  State<MobileSearchBar> createState() => _MobileSearchBarState();
}

class _MobileSearchBarState extends State<MobileSearchBar> {
  late final M3ESearchController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = M3ESearchController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final bool outlined = widget.variant == MobileSearchBarVariant.outlined;

    return M3ESearchAnchor.bar(
      searchController: _searchController,
      suggestionsBuilder: (BuildContext context, M3ESearchController _) {
        return const <Widget>[];
      },
      barHintText: widget.hintText ?? AppLocalizations.of(context).searchHint,
      barLeading: const Icon(M3EIcons.search),
      barAvatar: widget.avatar,
      barTrailing: widget.trailing,
      barBackgroundColor: outlined
          ? WidgetStatePropertyAll<Color?>(
              theme.colorScheme.surfaceContainerHigh,
            )
          : null,
      barSide: outlined
          ? WidgetStatePropertyAll<BorderSide?>(
              BorderSide(color: theme.colorScheme.outlineVariant),
            )
          : null,
      barShape: outlined
          ? const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder())
          : null,
      isFullScreen: true,
      viewStyle: M3ESearchViewStyle.contained,
      constraints: const BoxConstraints.tightFor(height: 56),
      expandOnFocus: false,
      expandRestPadding: 0,
    );
  }
}

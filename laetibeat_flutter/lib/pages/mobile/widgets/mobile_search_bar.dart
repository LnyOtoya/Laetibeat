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
    this.onAvatarTap,
    this.avatarSemanticsLabel,
    this.trailing,
    this.searchController,
    this.onChanged,
    this.onSubmitted,
    this.suggestionsBuilder,
  });

  final String? hintText;
  final MobileSearchBarVariant variant;

  /// 搜索栏右侧头像；为空时不显示。
  final Widget? avatar;

  /// 头像的点击回调。
  ///
  /// M3ESearchBar 在未聚焦时会把头像放进 IgnorePointer，因此这里在
  /// 搜索栏上层覆盖一个透明的 48dp 点击目标，保证头像始终可点。
  final VoidCallback? onAvatarTap;
  final String? avatarSemanticsLabel;

  /// 搜索栏右侧图标；与 avatar 同时使用时最多再放一个。
  final Iterable<Widget>? trailing;

  /// 外部控制器；为空时由搜索栏自己创建和释放。
  final M3ESearchController? searchController;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// full screen 搜索视图中的结果构建器。
  final M3ESearchSuggestionsBuilder? suggestionsBuilder;

  @override
  State<MobileSearchBar> createState() => _MobileSearchBarState();
}

class _MobileSearchBarState extends State<MobileSearchBar> {
  late final M3ESearchController _searchController;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.searchController == null;
    _searchController = widget.searchController ?? M3ESearchController();
  }

  @override
  void dispose() {
    if (_ownsController) _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final bool outlined = widget.variant == MobileSearchBarVariant.outlined;

    final bar = M3ESearchAnchor.bar(
      searchController: _searchController,
      suggestionsBuilder:
          widget.suggestionsBuilder ??
          (BuildContext context, M3ESearchController _) {
            return const <Widget>[];
          },
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      barHintText: widget.hintText ?? AppLocalizations.of(context).searchHint,
      barLeading: const Icon(M3EIcons.search),
      barAvatar: widget.avatar == null
          ? null
          : ExcludeSemantics(child: widget.avatar),
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

    if (widget.avatar == null || widget.onAvatarTap == null) return bar;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        bar,
        PositionedDirectional(
          top: 4,
          end: 8,
          width: 48,
          height: 48,
          child: Semantics(
            button: true,
            label: widget.avatarSemanticsLabel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onAvatarTap,
            ),
          ),
        ),
      ],
    );
  }
}

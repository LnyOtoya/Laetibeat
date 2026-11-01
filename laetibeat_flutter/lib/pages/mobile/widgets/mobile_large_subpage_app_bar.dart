import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// 移动端二级页面共用的 large baseline AppBar。
M3EAppBar mobileLargeSubpageAppBar(
  BuildContext context, {
  String? title,
  bool centerTitle = false,
  Color? backgroundColor,
}) {
  final theme = M3ETheme.of(context);

  return M3EAppBar.top(
    backgroundColor: backgroundColor ?? theme.colorScheme.surfaceContainer,
    variant: M3EAppBarVariant.large,
    hideMode: M3EAppBarHideMode.none,
    shapeFamily: M3EAppBarShapeFamily.square,
    safeArea: true,
    centerTitle: centerTitle,
    title: title == null
        ? null
        : Padding(
            padding: EdgeInsetsDirectional.only(start: centerTitle ? 0 : 12),
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: centerTitle ? TextAlign.center : TextAlign.start,
              style: theme.typeScale.displaySmall.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
    leading: Padding(
      padding: const EdgeInsetsDirectional.only(start: 24),
      child: _SubpageBackButton(
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ),
  );
}

class _SubpageBackButton extends StatelessWidget {
  const _SubpageBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Semantics(
      button: true,
      label: '返回',
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                M3EIcons.arrow_back,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

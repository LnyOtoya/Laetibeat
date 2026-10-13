import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'settings_pane.dart';
import 'settings_provider.dart';

//外观设置
class AppearanceSettings extends ConsumerWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    return SettingsPane(
      title: '外观',
      children: [
        //分组:全局主题
        Text(
          '全局主题',
          style: theme.typeScale.labelMedium.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        M3EList(
          itemCount: 1,
          onTap: (i) => _showThemeSheet(context, ref),
          itemBuilder: (context, i) {
            return M3EListItem(
              headline: '应用主题',
              leading: M3EShapeContainer.square(
                width: theme.spacing.xxl * 1.5,
                height: theme.spacing.xxl * 1.5,
                color: scheme.secondaryContainer,
                child: const Icon(M3EIcons.format_paint),
              ),
            );
          },
        ),
      ],
    );
  }

  //弹出应用主题选择底部弹层
  Future<void> _showThemeSheet(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final selected = ref.read(appThemeModeProvider);

    return M3EBottomSheet.show<void>(
      context,
      builder: (sheetContext) {
        final sheet = M3ETheme.of(sheetContext);
        final scheme = sheet.colorScheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            sheet.spacing.lg,
            0,
            sheet.spacing.lg,
            sheet.spacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //左上角标题
              Text('应用主题', style: theme.typeScale.titleLarge),
              SizedBox(height: sheet.spacing.sm),
              //三项纯文字主题,选中项背景高亮(colorBuilder按索引上色)
              M3EList(
                itemCount: AppThemeMode.values.length,
                onTap: (i) {
                  ref.read(appThemeModeProvider.notifier).select(AppThemeMode.values[i]);
                  Navigator.of(context).pop();
                },
                colorBuilder: (i) =>
                    selected == AppThemeMode.values[i] ? scheme.secondaryContainer : null,
                itemBuilder: (context, i) {
                  final mode = AppThemeMode.values[i];
                  return M3EListItem(
                    headline: mode.label,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

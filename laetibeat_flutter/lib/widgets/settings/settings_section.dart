import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../animations.dart';
import '../player/mini_player.dart' show MiniPlayerScope;
import 'settings_provider.dart';

//设置页左侧分类列表
class SettingsSection extends ConsumerWidget {
  const SettingsSection({super.key, this.onSelected});

  // 移动端点击分类后由页面负责跳转；桌面端为 null，右侧详情直接切换
  final ValueChanged<SettingsCategory>? onSelected;

  //分组假数据
  static const List<_CategoryGroup> _groups = <_CategoryGroup>[
    _CategoryGroup('用户界面', <_CategoryItem>[
      _CategoryItem(SettingsCategory.appearance, M3EIcons.palette, '外观'),
    ]),
    _CategoryGroup('播放器与内容', <_CategoryItem>[
      _CategoryItem(SettingsCategory.playerAudio, M3EIcons.equalizer, '播放器与音频'),
      _CategoryItem(SettingsCategory.content, M3EIcons.library_music, '内容'),
    ]),
    _CategoryGroup('储存于数据', <_CategoryItem>[
      _CategoryItem(SettingsCategory.storage, M3EIcons.storage, '储存'),
      _CategoryItem(SettingsCategory.backup, M3EIcons.backup, '备份与还原'),
    ]),
    _CategoryGroup('系统与关于', <_CategoryItem>[
      _CategoryItem(SettingsCategory.changelog, M3EIcons.history, '更新日志'),
      _CategoryItem(SettingsCategory.about, M3EIcons.info, '关于'),
    ]),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final miniPlayerInset = MiniPlayerScope.reservedHeightOf(context);
    final selected = ref.watch(settingsCategoryProvider);

    return AnimatedContainer(
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
      padding: EdgeInsets.all(theme.spacing.xl),
      child: Padding(
        padding: EdgeInsets.only(bottom: miniPlayerInset),
        child: ScrollConfiguration(
          behavior:
              ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          //标题
          Text(
            '设置',
            style: theme.typeScale.titleLarge,
          ),
          SizedBox(height: theme.spacing.lg),
          //分组:标题+组内汉堡样式卡片列表
          for (int g = 0; g < _groups.length; g++) ...[
            if (g > 0) SizedBox(height: theme.spacing.lg),
            Text(
              _groups[g].title,
              style: theme.typeScale.labelMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            M3EList(
              itemCount: _groups[g].items.length,
              onTap: (i) {
                final category = _groups[g].items[i].category;
                ref.read(settingsCategoryProvider.notifier).select(category);
                onSelected?.call(category);
              },
              itemBuilder: (context, i) {
                final item = _groups[g].items[i];
                return M3EListItem(
                  headline: item.label,
                  leading: M3EShapeContainer.square(
                    width: theme.spacing.xxl * 1.5,
                    height: theme.spacing.xxl * 1.5,
                    color: scheme.secondaryContainer,
                    child: Icon(item.icon),
                  ),
                  selected: selected == item.category,
                );
              },
            ),
          ],
        ],
      ),
    ),
  ),
),
);
}
}

//分组
class _CategoryGroup {
  final String title;
  final List<_CategoryItem> items;

  const _CategoryGroup(this.title, this.items);
}

//分类条目
class _CategoryItem {
  final SettingsCategory category;
  final IconData icon;
  final String label;

  const _CategoryItem(this.category, this.icon, this.label);
}

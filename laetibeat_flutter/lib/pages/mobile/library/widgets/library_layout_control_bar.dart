import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// 音乐库分类页共用的排序 + 布局切换控制条。
class LibraryLayoutControlBar extends StatelessWidget {
  const LibraryLayoutControlBar({
    super.key,
    required this.isGrid,
    required this.onToggleLayout,
  });

  final bool isGrid;
  final VoidCallback onToggleLayout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          M3EButton.icon(
            icon: const Icon(M3EIcons.swap_vert),
            label: const Text('排序'),
            style: M3EButtonStyle.tonal,
            size: M3EButtonSize.sm,
            shape: M3EButtonShape.round,
            onPressed: () {},
          ),
          const Spacer(),
          M3EIconButton(
            variant: M3EIconButtonVariant.filled,
            shape: M3EIconButtonShapeVariant.round,
            icon: Icon(isGrid ? M3EIcons.view_list : M3EIcons.grid_view),
            tooltip: isGrid ? '切换为列表布局' : '切换为宫格布局',
            onPressed: onToggleLayout,
          ),
        ],
      ),
    );
  }
}

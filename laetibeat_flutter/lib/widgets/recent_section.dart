import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../animations.dart';

//最近添加的列表区块
class RecentSection extends StatefulWidget {
  const RecentSection({super.key});

  @override
  State<RecentSection> createState() => _RecentSectionState();
}

class _RecentSectionState extends State<RecentSection> {
  //假数据,之后填充
  static const List<_MockAlbum> _albums = <_MockAlbum>[
    _MockAlbum('Neon Skyline', 'Sakura Grooves'),
    _MockAlbum('Midnight Drive', 'Urban Echo'),
    _MockAlbum('Velvet Horizon', 'The Night Owls'),
    _MockAlbum('Paper Planes', 'Aiko & Friends'),
    _MockAlbum('Golden Hour', 'Lumen'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return AnimatedContainer(
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
      padding: EdgeInsets.all(theme.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //标题行:Recently Added + See all
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Recently Added',
                style: theme.typeScale.titleLarge,
              ),
              M3EButton.text(
                onPressed: () {},
                size: M3EButtonSize.sm,
                child: Text('See all'),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.lg),
          //卡片列表,只显示5个
          M3EList(
            itemCount: _albums.length,
            itemBuilder: (context, index) {
              final album = _albums[index];
              return M3EListItem(
                headline: album.name,
                supportingText: album.artist,
                leading: _buildCircleCover(theme, album.name),
              );
            },
          ),
        ],
      ),
    );
  }

  //圆形封面占位(渐变+音符图标)
  Widget _buildCircleCover(M3EThemeData theme, String name) {
    final scheme = theme.colorScheme;
    return M3EShapeContainer.circle(
      width: theme.spacing.xxl * 1.5,
      height: theme.spacing.xxl * 1.5,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [scheme.primaryContainer, scheme.tertiaryContainer],
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: Icon(
          M3EIcons.music_note,
          size: theme.spacing.xl,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

//专辑假数据
class _MockAlbum {
  final String name;
  final String artist;

  const _MockAlbum(this.name, this.artist);
}
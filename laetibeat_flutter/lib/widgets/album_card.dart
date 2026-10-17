import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

// 专辑封面卡片,最外层圆角矩形,上方封面图,下方标题与副标题
class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.cover,
    this.onTap,
  });

  final String title;
  final String subtitle;
  // 封面图地址,为空时显示占位封面
  final String? imageUrl;

  // 自定义封面(如本地内嵌封面);优先于 imageUrl
  final Widget? cover;

  // 点击整张卡片
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return M3ECard(
      variant: M3ECardVariant.filled,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      borderRadius: M3EDimensions.borderRadiusLarge,
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上方封面图区域
          AspectRatio(
            aspectRatio: 1,
            child: cover ?? _buildCover(theme),
          ),
          // 下方文本区域
          Padding(
            padding: EdgeInsets.all(theme.spacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typeScale.titleMedium,
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typeScale.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 封面图,无地址时用占位色块+图标
  Widget _buildCover(M3EThemeData theme) {
    final cover = imageUrl;

    if (cover != null) {
      return Image.network(
        cover,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(theme),
      );
    }

    return _placeholder(theme);
  }

  // 占位封面
  Widget _placeholder(M3EThemeData theme) {
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(
        M3EIcons.music_note,
        size: theme.spacing.xxl,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
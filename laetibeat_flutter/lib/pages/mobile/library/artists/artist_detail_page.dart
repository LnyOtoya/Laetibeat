import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';
import '../albums/album_detail_page.dart';

/// 艺术家详情页。
class ArtistDetailPage extends ConsumerStatefulWidget {
  const ArtistDetailPage({
    super.key,
    required this.sourceId,
    required this.artist,
  });

  final String sourceId;
  final rust_subsonic.UiRemoteArtist artist;

  @override
  ConsumerState<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends ConsumerState<ArtistDetailPage> {
  bool _biographyExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final biography = ref.watch(
      remoteArtistBiographyProvider((
        sourceId: widget.sourceId,
        artistId: widget.artist.id,
      )),
    );
    final albums = ref.watch(
      remoteAlbumsProvider((
        sourceId: widget.sourceId,
        artistId: widget.artist.id,
      )),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(
        context,
        variant: M3EAppBarVariant.small,
        actions: [
          M3EIconButton(
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(M3EIcons.favorite_border),
            tooltip: '喜欢',
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
        children: [
          Row(
            children: [
              _ArtistAvatar(
                sourceId: widget.sourceId,
                coverId: widget.artist.coverId,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typeScale.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '共 ${widget.artist.albumCount?.toInt() ?? '--'} 张专辑',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typeScale.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: M3EButton.icon(
                  icon: const Icon(M3EIcons.local_fire_department),
                  label: const Text('热门歌曲'),
                  style: M3EButtonStyle.filled,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: M3EButton.icon(
                  icon: const Icon(M3EIcons.shuffle),
                  label: const Text('随机播放'),
                  style: M3EButtonStyle.tonal,
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '公开数据',
                  style: theme.typeScale.titleSmall.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                biography.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: M3ELoadingIndicator()),
                  ),
                  error: (Object error, StackTrace stackTrace) =>
                      _biographyText(theme, '暂无歌手详情'),
                  data: (String? text) {
                    final content = text == null || text.trim().isEmpty
                        ? '暂无歌手详情'
                        : text;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(
                        () => _biographyExpanded = !_biographyExpanded,
                      ),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        alignment: Alignment.topCenter,
                        child: _biographyText(
                          theme,
                          content,
                          maxLines: _biographyExpanded ? null : 6,
                          overflow: _biographyExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  '歌手专辑',
                  style: theme.typeScale.titleSmall.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  M3EIcons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          albums.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: M3ELoadingIndicator()),
            ),
            error: (Object error, StackTrace stackTrace) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('读取专辑失败')),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('暂无专辑')),
                );
              }
              return M3EList(
                color: theme.colorScheme.surface,
                variant: M3ECardVariant.filled,
                itemCount: list.length,
                onTap: (int index) => _openAlbum(list[index]),
                itemBuilder: (BuildContext context, int index) {
                  final album = list[index];
                  return SizedBox(
                    height: 88,
                    child: M3EListItem(
                      leading: SizedBox.square(
                        dimension: 64,
                        child: _ArtistAlbumCover(
                          sourceId: widget.sourceId,
                          coverId: album.coverId,
                        ),
                      ),
                      headline: album.title,
                      supportingText:
                          '${album.year?.toString() ?? '年份未知'}\n'
                          '${_formatApproxDuration(album.durationSeconds?.toInt())}',
                      trailing: M3EIconButton(
                        size: M3EIconButtonSize.xs,
                        variant: M3EIconButtonVariant.standard,
                        icon: const Icon(M3EIcons.favorite_border),
                        tooltip: '喜欢',
                        onPressed: () {},
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatApproxDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '时长未知';
    final minutes = (seconds / 60).round();
    if (minutes <= 0) return '不到 1 分钟';
    return '大约 $minutes 分钟';
  }

  void _openAlbum(rust_subsonic.UiRemoteAlbum album) {
    pushMobileRootPage(
      context,
      AlbumDetailPage(sourceId: widget.sourceId, album: album),
      name: MobileRoutes.albumDetail,
    );
  }

  Widget _biographyText(
    M3EThemeData theme,
    String text, {
    int? maxLines,
    TextOverflow overflow = TextOverflow.clip,
  }) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      style: theme.typeScale.bodyMedium.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.6,
      ),
    );
  }
}

class _ArtistAlbumCover extends ConsumerWidget {
  const _ArtistAlbumCover({required this.sourceId, required this.coverId});

  final String sourceId;
  final String? coverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final id = coverId;
    final bytes = id == null || id.isEmpty
        ? null
        : ref
              .watch(remoteCoverProvider((sourceId: sourceId, coverId: id)))
              .value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: hasArt
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            )
          : ColoredBox(
              color: theme.colorScheme.secondaryContainer,
              child: Center(
                child: Icon(
                  M3EIcons.album,
                  size: 22,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
    );
  }
}

class _ArtistAvatar extends ConsumerWidget {
  const _ArtistAvatar({required this.sourceId, required this.coverId});

  final String sourceId;
  final String? coverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final id = coverId;
    final bytes = id == null || id.isEmpty
        ? null
        : ref
              .watch(remoteCoverProvider((sourceId: sourceId, coverId: id)))
              .value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipOval(
      child: SizedBox.square(
        dimension: 72,
        child: hasArt
            ? Image.memory(
                bytes,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
              )
            : ColoredBox(
                color: theme.colorScheme.secondaryContainer,
                child: Center(
                  child: Icon(
                    M3EIcons.person,
                    size: 32,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
      ),
    );
  }
}

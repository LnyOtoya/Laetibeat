import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

import '../animations.dart';
import 'player/cover_provider.dart';
import 'player/player_provider.dart';
import 'settings/music_library_provider.dart';

//最近添加的列表区块(按文件修改时间倒序取前 5 张专辑)
class RecentSection extends ConsumerWidget {
  const RecentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final library = ref.watch(musicLibraryProvider).value;

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
          _buildList(ref, theme, library),
        ],
      ),
    );
  }

  Widget _buildList(
    WidgetRef ref,
    M3EThemeData theme,
    MusicLibraryState? library,
  ) {
    if (library == null) {
      return _hint(theme, '正在加载音乐库…');
    }

    final byId = {for (final t in library.tracks) t.id: t};

    // 专辑的"最近添加时间"取专辑内曲目 mtime 的最大值(先算一次,避免排序中重复遍历)
    final mtimes = <String, int>{};
    for (final album in library.albums) {
      var latest = 0;
      for (final id in album.trackIds) {
        final value = byId[id]?.modifiedMs?.toInt() ?? 0;
        if (value > latest) latest = value;
      }
      mtimes[album.id] = latest;
    }

    final albums = [...library.albums]
      ..sort((a, b) {
        final ma = mtimes[a.id] ?? 0;
        final mb = mtimes[b.id] ?? 0;
        if (ma != mb) return mb.compareTo(ma);
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    final recent = albums.take(5).toList();

    if (recent.isEmpty) {
      return _hint(theme, '暂无最近添加');
    }

    return M3EList(
      itemCount: recent.length,
      onTap: (i) {
        final album = recent[i];
        final tracks = <rust.UiTrack>[
          for (final id in album.trackIds)
            if (byId[id] != null) byId[id]!,
        ];
        if (tracks.isNotEmpty) {
          ref.read(playerProvider.notifier).load(
                tracks,
                0,
                source: album.title,
              );
        }
      },
      itemBuilder: (context, i) {
        final album = recent[i];
        final cover = byId[album.coverTrackId];
        return M3EListItem(
          headline: album.title,
          supportingText: album.artist,
          leading: _RecentCover(track: cover, theme: theme),
        );
      },
    );
  }

  Widget _hint(M3EThemeData theme, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
      child: Text(
        text,
        style: theme.typeScale.bodyMedium.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

//最近添加的圆形封面:有内嵌封面显示真实封面,否则渐变占位
class _RecentCover extends ConsumerWidget {
  const _RecentCover({required this.track, required this.theme});

  final rust.UiTrack? track;
  final M3EThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = track;
    final bytes =
        current == null ? null : ref.watch(trackCoverProvider(current)).value;
    final hasArt = bytes != null && bytes.isNotEmpty;
    final scheme = theme.colorScheme;
    final size = theme.spacing.xxl * 1.5;

    return M3EShapeContainer.circle(
      width: size,
      height: size,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [scheme.primaryContainer, scheme.tertiaryContainer],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasArt
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            )
          : Center(
              child: Icon(
                M3EIcons.music_note,
                size: theme.spacing.xl,
                color: scheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

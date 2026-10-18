import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'settings_pane.dart';
import 'music_library_provider.dart';
import 'remote_sync_provider.dart';
import 'subsonic_connection_sheet.dart';
import 'subsonic_provider.dart';

//内容设置:音乐来源
class ContentSettings extends ConsumerWidget {
  const ContentSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final musicState = ref.watch(musicLibraryProvider).value;
    final directory = musicState?.directory;
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final server = servers.isEmpty ? null : servers.first;
    final remoteSync = ref.watch(remoteSyncProvider).value;

    //单个分组通用构建
    Widget group({
      required String title,
      required List<Widget> items,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //分组小标题
          Text(
            title,
            style: theme.typeScale.labelMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          ...items,
        ],
      );
    }

    //列表项通用构建
    Widget item({
      required String label,
      required IconData icon,
      String? supportingText,
      VoidCallback? onTap,
    }) {
      return M3EList(
        itemCount: 1,
        onTap: onTap == null ? null : (i) => onTap(),
        itemBuilder: (context, i) {
          return M3EListItem(
            headline: label,
            supportingText: supportingText,
            leading: M3EShapeContainer.square(
              width: theme.spacing.xxl * 1.5,
              height: theme.spacing.xxl * 1.5,
              color: scheme.secondaryContainer,
              child: Icon(icon),
            ),
          );
        },
      );
    }

    //实时扫描状态列表项(仅扫描开始后显示,与上方列表项一致的 M3EList 样式)
    Widget _statusItem(
      M3EThemeData theme,
      M3EColorScheme scheme,
      MusicLibraryState? st,
    ) {
      //未扫描时,不显示任何内容
      if (!(st?.hasScanned ?? false)) return const SizedBox.shrink();
      final leading = (Widget? child) => M3EShapeContainer.square(
            width: theme.spacing.xxl * 1.5,
            height: theme.spacing.xxl * 1.5,
            color: scheme.secondaryContainer,
            child: child,
          );
      final M3EListItem item;
      //扫描中:活动指示器
      if (st?.isLoading ?? false) {
        item = M3EListItem(
          headline: '正在扫描…',
          leading: leading(
            Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: M3EProgressIndicator.circularWavy(
                size: theme.spacing.xxl,
                strokeWidth: 8,
                trackStrokeWidth: 8,
                wavelength: 19,
              ),
            ),
          ),
        );
      } else {
        //结束:展示结果与增量扫描统计
        final String label;
        String? detail;
        if (st == null) {
          label = '未开始扫描';
        } else if (st.error != null) {
          label = '扫描失败';
          detail = st.error;
        } else {
          label = '扫描完成，共 ${st.tracks.length} 首歌曲';
          final stats = st.scanStats;
          if (st.tracks.isEmpty) {
            detail = '尚未发现歌曲';
          } else if (stats != null) {
            final seconds =
                (stats.elapsed.inMilliseconds / 1000).toStringAsFixed(1);
            detail =
                '复用 ${stats.reusedFiles} · 解析 ${stats.parsedFiles} · 移除 ${stats.removedFiles} · 耗时 ${seconds}s';
          }
        }
        item = M3EListItem(
          headline: label,
          supportingText: detail,
          leading: leading(
            Icon(
              st == null
                  ? M3EIcons.info
                  : (st.error != null ? M3EIcons.error : M3EIcons.music_note),
            ),
          ),
        );
      }
      return M3EList(
        itemCount: 1,
        itemBuilder: (context, i) => item,
      );
    }

    //远端同步状态项
    Widget remoteStatusItem(
      M3EThemeData theme,
      M3EColorScheme scheme,
      RemoteSyncState? st,
    ) {
      if (st == null) return const SizedBox.shrink();
      final leading = (Widget? child) => M3EShapeContainer.square(
            width: theme.spacing.xxl * 1.5,
            height: theme.spacing.xxl * 1.5,
            color: scheme.secondaryContainer,
            child: child,
          );

      final M3EListItem item;
      if (st.isSyncing) {
        final String detail;
        switch (st.phase) {
          case RemoteSyncPhase.artists:
            detail = st.message ?? '正在获取艺术家…';
          case RemoteSyncPhase.albums:
            detail = st.completed > 0
                ? '已获取 ${st.completed} 张专辑'
                : '正在获取专辑…';
          case RemoteSyncPhase.tracks:
            final progress = st.total > 0
                ? '${st.completed}/${st.total} 首'
                : '${st.completed} 首';
            detail = '正在获取曲目 $progress'
                '${st.message == null ? '' : ' · ${st.message}'}';
          default:
            detail = st.message ?? '正在同步…';
        }
        item = M3EListItem(
          headline: '正在同步…',
          supportingText: detail,
          leading: leading(
            Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: M3EProgressIndicator.circularWavy(
                size: theme.spacing.xxl,
                strokeWidth: 8,
                trackStrokeWidth: 8,
                wavelength: 19,
              ),
            ),
          ),
        );
      } else if (st.phase == RemoteSyncPhase.failed) {
        item = M3EListItem(
          headline: '同步失败',
          supportingText: st.error ?? st.message ?? '请稍后重试',
          leading: leading(const Icon(M3EIcons.error)),
        );
      } else {
        final meta = st.meta;
        final trackCount = meta?.trackCount.toInt() ?? st.trackCount;
        final artistCount = meta?.artistCount.toInt() ?? st.artistCount;
        final albumCount = meta?.albumCount.toInt() ?? st.albumCount;
        final elapsedMs = meta?.elapsedMs.toInt() ?? st.elapsedMs;
        final seconds = (elapsedMs / 1000).toStringAsFixed(1);
        final syncedAt = meta == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(meta.syncedAt.toInt());
        final detail =
            '艺术家 $artistCount · 专辑 $albumCount · 耗时 ${seconds}s'
            '${syncedAt == null ? '' : ' · 上次同步 ${_formatDateTime(syncedAt)}'}';

        item = M3EListItem(
          headline: '扫描完成，共 $trackCount 首歌',
          supportingText: detail,
          leading: leading(const Icon(M3EIcons.music_note)),
        );
      }

      return M3EList(
        itemCount: 1,
        itemBuilder: (context, i) => item,
      );
    }

    return SettingsPane(
      title: '内容',
      children: [
        //分组:本地目录结构
        group(
          title: '本地目录结构',
          items: [
            item(
              label: '选择目录',
              icon: M3EIcons.folder_open,
              supportingText: directory,
              onTap: () => ref.read(musicLibraryProvider.notifier).pickDirectory(),
            ),
            SizedBox(height: theme.spacing.md),
            item(
              label: '重新扫描',
              icon: M3EIcons.refresh,
              onTap: () => ref.read(musicLibraryProvider.notifier).rescan(),
            ),
            SizedBox(height: theme.spacing.md),
            //实时扫描状态
            _statusItem(theme, scheme, musicState),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        //分组:Navidrome 音乐库
        group(
          title: 'Navidrome 音乐库',
          items: [
            item(
              label: '连接配置',
              icon: M3EIcons.link,
              supportingText: server?.baseUrl ?? '未连接',
              onTap: () => showSubsonicConnectionSheet(context, ref),
            ),
            SizedBox(height: theme.spacing.md),
            item(
              label: '同步音乐',
              icon: M3EIcons.sync,
              supportingText: server == null
                  ? '请先连接 Navidrome'
                  : remoteSync == null
                  ? '正在读取同步状态…'
                  : remoteSync.isSyncing
                  ? '正在同步…'
                  : '从服务器拉取歌曲信息',
              onTap: server == null
                  ? () => showSubsonicConnectionSheet(context, ref)
                  : remoteSync == null || remoteSync.isSyncing
                  ? null
                  : () => ref.read(remoteSyncProvider.notifier).start(),
            ),
            if (remoteSync != null &&
                (remoteSync.isSyncing ||
                    remoteSync.phase == RemoteSyncPhase.failed ||
                    remoteSync.hasResult)) ...[
              SizedBox(height: theme.spacing.md),
              remoteStatusItem(theme, scheme, remoteSync),
            ],
          ],
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime dt) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}
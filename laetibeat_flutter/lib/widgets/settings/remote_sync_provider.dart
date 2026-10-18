import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/library.dart' as rust_library;
import 'package:laetibeat/src/rust/api/sync.dart' as rust_sync;

import '../remote_browser_provider.dart';
import 'subsonic_provider.dart';

/// 远端同步阶段
enum RemoteSyncPhase { idle, artists, albums, tracks, done, failed }

class RemoteSyncState {
  const RemoteSyncState({
    this.phase = RemoteSyncPhase.idle,
    this.completed = 0,
    this.total = 0,
    this.artistCount = 0,
    this.albumCount = 0,
    this.trackCount = 0,
    this.elapsedMs = 0,
    this.message,
    this.meta,
    this.error,
  });

  final RemoteSyncPhase phase;

  /// 当前阶段已完成数量
  final int completed;

  /// 当前阶段总数;0 表示未知
  final int total;

  final int artistCount;
  final int albumCount;
  final int trackCount;
  final int elapsedMs;
  final String? message;

  /// 上一次成功同步的摘要(来自 library.db)
  final rust_library.UiRemoteSyncMeta? meta;

  /// 失败原因
  final String? error;

  bool get isSyncing =>
      phase == RemoteSyncPhase.artists ||
      phase == RemoteSyncPhase.albums ||
      phase == RemoteSyncPhase.tracks;

  bool get hasResult => meta != null || phase == RemoteSyncPhase.done;
}

/// 远端音乐同步状态与进度。
/// 放在全局 provider 中,离开设置页后同步仍会继续。
final remoteSyncProvider =
    AsyncNotifierProvider<RemoteSyncNotifier, RemoteSyncState>(
      RemoteSyncNotifier.new,
    );

class RemoteSyncNotifier extends AsyncNotifier<RemoteSyncState> {
  StreamSubscription<rust_sync.UiRemoteSyncProgress>? _sub;

  @override
  Future<RemoteSyncState> build() async {
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });

    final servers = await ref.watch(subsonicServersProvider.future);
    if (servers.isEmpty) return const RemoteSyncState();

    final config = servers.first;
    rust_library.UiRemoteSyncMeta? meta;
    try {
      meta = await rust_library.getRemoteSyncMeta(sourceId: config.id);
      // 服务器地址已变化时旧快照不再可信,顺手清理
      if (meta != null && meta.baseUrl != config.baseUrl) {
        await rust_library.clearRemoteLibrary(sourceId: config.id);
        meta = null;
      }
    } catch (e) {
      debugPrint('读取远端同步摘要失败: $e');
    }
    return RemoteSyncState(meta: meta);
  }

  /// 开始同步。未配置服务器时直接进入失败态。
  Future<void> start() async {
    final current = state.value;
    if (current?.isSyncing ?? false) return;

    final servers = await ref.read(subsonicServersProvider.future);
    if (servers.isEmpty) {
      state = const AsyncData(
        RemoteSyncState(
          phase: RemoteSyncPhase.failed,
          error: '请先连接 Navidrome',
        ),
      );
      return;
    }

    final config = servers.first;
    await _sub?.cancel();
    _sub = null;

    // 连接阶段也标记为同步中,避免重复点击
    state = AsyncData(
      RemoteSyncState(
        phase: RemoteSyncPhase.artists,
        message: '正在连接服务器…',
        meta: current?.meta,
      ),
    );

    // 启动时的后台重连可能尚未完成,同步前按需补一次配置
    try {
      await ensureSubsonicConfigured(ref, config.id);
    } catch (e) {
      state = AsyncData(
        RemoteSyncState(
          phase: RemoteSyncPhase.failed,
          error: e.toString(),
          meta: current?.meta,
        ),
      );
      return;
    }

    state = AsyncData(
      RemoteSyncState(
        phase: RemoteSyncPhase.artists,
        message: '正在读取服务器音乐库…',
        meta: current?.meta,
      ),
    );

    _sub = rust_sync
        .syncSubsonicLibrary(
          sourceId: config.id,
          baseUrl: config.baseUrl,
        )
        .listen(
          _onProgress,
          onError: (Object error) {
            state = AsyncData(
              RemoteSyncState(
                phase: RemoteSyncPhase.failed,
                error: error.toString(),
                meta: state.value?.meta,
              ),
            );
          },
          onDone: () {
            final value = state.value;
            if (value != null && value.isSyncing) {
              // 流正常关闭但没有收到 done/failed 事件
              state = AsyncData(
                RemoteSyncState(
                  phase: RemoteSyncPhase.failed,
                  error: '同步意外结束',
                  meta: value.meta,
                ),
              );
            }
          },
        );
  }

  void _onProgress(rust_sync.UiRemoteSyncProgress progress) {
    final phase = switch (progress.phase) {
      'artists' => RemoteSyncPhase.artists,
      'albums' => RemoteSyncPhase.albums,
      'tracks' => RemoteSyncPhase.tracks,
      'done' => RemoteSyncPhase.done,
      'failed' => RemoteSyncPhase.failed,
      _ => RemoteSyncPhase.idle,
    };

    if (phase == RemoteSyncPhase.done) {
      state = AsyncData(
        RemoteSyncState(
          phase: RemoteSyncPhase.done,
          completed: progress.completed.toInt(),
          total: progress.total.toInt(),
          artistCount: progress.artistCount.toInt(),
          albumCount: progress.albumCount.toInt(),
          trackCount: progress.trackCount.toInt(),
          elapsedMs: progress.elapsedMs.toInt(),
          message: progress.message,
          meta: state.value?.meta,
        ),
      );
      unawaited(_refreshMeta());
      // 同步完成后让在线浏览/搜索重新取数据
      ref.invalidate(remoteArtistsProvider);
      ref.invalidate(remoteAlbumsProvider);
      ref.invalidate(remoteTracksProvider);
      ref.invalidate(remoteSearchProvider);
      return;
    }

    state = AsyncData(
      RemoteSyncState(
        phase: phase,
        completed: progress.completed.toInt(),
        total: progress.total.toInt(),
        artistCount: progress.artistCount.toInt(),
        albumCount: progress.albumCount.toInt(),
        trackCount: progress.trackCount.toInt(),
        elapsedMs: progress.elapsedMs.toInt(),
        message: progress.message,
        error: phase == RemoteSyncPhase.failed
            ? (progress.message ?? '同步失败')
            : null,
        meta: state.value?.meta,
      ),
    );
  }

  /// 完成后从数据库补一次摘要,拿到 syncedAt 等完整信息。
  Future<void> _refreshMeta() async {
    try {
      final servers = await ref.read(subsonicServersProvider.future);
      if (servers.isEmpty) return;
      final meta = await rust_library.getRemoteSyncMeta(
        sourceId: servers.first.id,
      );
      final current = state.value;
      if (current == null || current.phase != RemoteSyncPhase.done) return;

      state = AsyncData(
        RemoteSyncState(
          phase: current.phase,
          completed: current.completed,
          total: current.total,
          artistCount: meta?.artistCount.toInt() ?? current.artistCount,
          albumCount: meta?.albumCount.toInt() ?? current.albumCount,
          trackCount: meta?.trackCount.toInt() ?? current.trackCount,
          elapsedMs: meta?.elapsedMs.toInt() ?? current.elapsedMs,
          message: current.message,
          meta: meta ?? current.meta,
        ),
      );
    } catch (e) {
      debugPrint('刷新远端同步摘要失败: $e');
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

import '../../core/services/directory_picker.dart';
import 'persistence.dart';

//本地音乐库状态:记录选中的目录与扫描出的单曲/专辑/艺术家
class MusicLibraryState {
  final String? directory;
  final List<rust.UiTrack> tracks;

  /// 专辑聚合(由 Rust 侧生成,曲目已按碟号/音轨号排序)
  final List<rust.UiAlbum> albums;

  /// 艺术家聚合(由 Rust 侧生成)
  final List<rust.UiArtist> artists;
  final bool isLoading;
  final String? error;
  final bool hasScanned; //标记是否执行过扫描,用于控制状态项显隐

  /// 最近一次扫描的统计(复用/解析/移除/耗时)
  final LibraryScanStats? scanStats;

  const MusicLibraryState({
    this.directory,
    this.tracks = const <rust.UiTrack>[],
    this.albums = const <rust.UiAlbum>[],
    this.artists = const <rust.UiArtist>[],
    this.isLoading = false,
    this.error,
    this.hasScanned = false,
    this.scanStats,
  });

  /// copyWith 哨兵:区分"未传参"与"显式传入 null"
  static const Object _unset = Object();

  MusicLibraryState copyWith({
    Object? directory = _unset,
    List<rust.UiTrack>? tracks,
    List<rust.UiAlbum>? albums,
    List<rust.UiArtist>? artists,
    bool? isLoading,
    Object? error = _unset,
    bool? hasScanned,
    Object? scanStats = _unset,
  }) {
    return MusicLibraryState(
      directory: identical(directory, _unset)
          ? this.directory
          : directory as String?,
      tracks: tracks ?? this.tracks,
      albums: albums ?? this.albums,
      artists: artists ?? this.artists,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _unset) ? this.error : error as String?,
      hasScanned: hasScanned ?? this.hasScanned,
      scanStats: identical(scanStats, _unset)
          ? this.scanStats
          : scanStats as LibraryScanStats?,
    );
  }
}

class MusicLibraryNotifier extends AsyncNotifier<MusicLibraryState> {
  @override
  Future<MusicLibraryState> build() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedDirectory = prefs.getString(kMusicDirectoryKey);

    // 启动时优先恢复上次扫描的快照,避免每次都重新扫描
    final snapshot = await ref.read(librarySnapshotStoreProvider).load();

    // 快照加载期间用户可能已切换目录:以最新目录为准,丢弃旧快照
    final latestDirectory = prefs.getString(kMusicDirectoryKey);
    if (latestDirectory != savedDirectory) {
      return MusicLibraryState(directory: latestDirectory);
    }

    final directory = snapshot?.directory ?? savedDirectory;
    if (directory != null && directory != savedDirectory) {
      await prefs.setString(kMusicDirectoryKey, directory);
    }

    if (snapshot == null) {
      return MusicLibraryState(directory: directory);
    }
    return MusicLibraryState(
      directory: directory,
      tracks: snapshot.tracks,
      albums: snapshot.albums,
      artists: snapshot.artists,
      hasScanned: snapshot.hasScanned,
      scanStats: snapshot.scanStats,
    );
  }

  //选择本地音乐目录
  Future<void> pickDirectory() async {
    final path = await ref.read(directoryPickerProvider).pickMusicDirectory();
    if (path == null) return;

    final current = state.value ?? const MusicLibraryState();
    // 目录未变则保持现有库;换目录时旧库数据/快照不再有效
    if (path == current.directory) return;

    //仅记录目录,不自动扫描
    state = AsyncValue.data(
      current.copyWith(
        directory: path,
        tracks: const <rust.UiTrack>[],
        albums: const <rust.UiAlbum>[],
        artists: const <rust.UiArtist>[],
        hasScanned: false,
        error: null,
        scanStats: null,
      ),
    );
    await ref.read(sharedPreferencesProvider).setString(
          kMusicDirectoryKey,
          path,
        );
    await ref.read(librarySnapshotStoreProvider).clear();
  }

  //重新扫描当前目录
  Future<void> rescan() async {
    final current = state.value;
    final dir = current?.directory;
    if (dir == null) return;

    state = AsyncValue.data(
      current!.copyWith(isLoading: true, error: null, hasScanned: true),
    );
    try {
      // 把上次扫描结果作为增量缓存:未变化的文件由 Rust 直接复用
      final result = await rust.scanLocalMusicFolder(
        dirPath: dir,
        knownTracks: current.tracks,
      );
      final library = result.library_;
      final stats = LibraryScanStats(
        totalFiles: result.stats.totalFiles,
        parsedFiles: result.stats.parsedFiles,
        reusedFiles: result.stats.reusedFiles,
        removedFiles: result.stats.removedFiles,
        elapsed: Duration(milliseconds: result.stats.elapsedMs.toInt()),
        scannedAt: DateTime.now(),
      );
      final next = state.value!.copyWith(
        tracks: library.tracks,
        albums: library.albums,
        artists: library.artists,
        isLoading: false,
        error: null,
        scanStats: stats,
      );
      state = AsyncValue.data(next);

      // 扫描成功后写快照;写盘失败不影响本次扫描结果
      try {
        await ref.read(librarySnapshotStoreProvider).save(
              LibrarySnapshot(
                directory: dir,
                hasScanned: true,
                scannedAt: stats.scannedAt,
                scanStats: stats,
                tracks: next.tracks,
                albums: next.albums,
                artists: next.artists,
              ),
            );
      } catch (e) {
        debugPrint('保存音乐库快照失败: $e');
      }
    } catch (e) {
      state = AsyncValue.data(
        state.value!.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
    }
  }
}

//当前本地音乐库
final musicLibraryProvider =
    AsyncNotifierProvider<MusicLibraryNotifier, MusicLibraryState>(
  MusicLibraryNotifier.new,
);
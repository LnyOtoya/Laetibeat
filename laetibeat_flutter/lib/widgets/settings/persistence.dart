import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置项持久化键
const String kThemeModeKey = 'settings.theme_mode';
const String kMusicDirectoryKey = 'library.directory';

/// 由 main() 预加载后通过 overrideWithValue 注入。
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider 必须在 main() 中通过 overrideWithValue 注入',
  );
});

/// 音乐库快照读写器
final librarySnapshotStoreProvider = Provider<LibrarySnapshotStore>(
  (ref) => LibrarySnapshotStore(),
);

/// 播放队列/位置快照读写器
final playbackSnapshotStoreProvider = Provider<PlaybackSnapshotStore>(
  (ref) => PlaybackSnapshotStore(),
);

/// 启动时恢复的播放快照;由 main() 加载后注入,默认无快照。
final initialPlaybackSnapshotProvider = Provider<PlaybackSnapshot?>((ref) => null);

// ---------------------------------------------------------------------------
// 通用文件/JSON 工具
// ---------------------------------------------------------------------------

Future<File> _appDataFile(String name) async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return File('${dir.path}/$name');
}

/// 临时文件 + rename,避免写一半崩溃产生损坏文件
Future<void> _writeAtomically(File file, String text) async {
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(text, flush: true);
  if (await file.exists()) {
    await file.delete();
  }
  await tmp.rename(file.path);
}

Future<void> _deleteAtomically(File file) async {
  try {
    if (await file.exists()) await file.delete();
    final tmp = File('${file.path}.tmp');
    if (await tmp.exists()) await tmp.delete();
  } catch (e) {
    debugPrint('删除快照失败: $e');
  }
}

/// 曲目 JSON。音乐库快照与播放队列快照共用同一套字段。
Map<String, Object?> uiTrackToJson(rust.UiTrack t) => <String, Object?>{
      'id': t.id,
      'title': t.title,
      'artist': t.artist,
      'album': t.album,
      'albumArtist': t.albumArtist,
      'albumId': t.albumId,
      'artistId': t.artistId,
      'trackNumber': t.trackNumber,
      'discNumber': t.discNumber,
      'year': t.year,
      'genre': t.genre,
      'duration': t.duration,
      'path': t.path,
      'bitrate': t.bitrate,
      'sampleRate': t.sampleRate,
      'channels': t.channels,
    };

rust.UiTrack uiTrackFromJson(Map<String, dynamic> m) => rust.UiTrack(
      id: m['id'] as String,
      title: m['title'] as String,
      artist: m['artist'] as String,
      album: m['album'] as String,
      albumArtist: m['albumArtist'] as String,
      albumId: m['albumId'] as String,
      artistId: m['artistId'] as String,
      trackNumber: m['trackNumber'] as int?,
      discNumber: m['discNumber'] as int?,
      year: m['year'] as int?,
      genre: m['genre'] as String?,
      duration: m['duration'] as String,
      path: m['path'] as String,
      bitrate: m['bitrate'] as int?,
      sampleRate: m['sampleRate'] as int?,
      channels: m['channels'] as int?,
    );

// ---------------------------------------------------------------------------
// 音乐库快照
// ---------------------------------------------------------------------------

/// 一次扫描结果的磁盘快照
class LibrarySnapshot {
  const LibrarySnapshot({
    this.directory,
    this.hasScanned = false,
    this.scannedAt,
    this.tracks = const <rust.UiTrack>[],
    this.albums = const <rust.UiAlbum>[],
    this.artists = const <rust.UiArtist>[],
  });

  final String? directory;
  final bool hasScanned;
  final DateTime? scannedAt;
  final List<rust.UiTrack> tracks;
  final List<rust.UiAlbum> albums;
  final List<rust.UiArtist> artists;
}

/// 音乐库 JSON 快照存储。
///
/// 几万首以内无需数据库:编码/解码放后台 isolate,写入用临时文件 + rename,
/// 避免写一半崩溃导致快照损坏。文件位于应用数据目录,不随项目目录变化。
class LibrarySnapshotStore {
  /// 快照结构版本;不匹配时按无缓存处理,下次扫描会重新写入。
  static const int schemaVersion = 1;
  static const String _fileName = 'library_snapshot.json';

  Future<File> _file() => _appDataFile(_fileName);

  Future<LibrarySnapshot?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      // 解码几 MB 文本可能耗时,放到后台 isolate
      final decoded = await Isolate.run(() => jsonDecode(text));
      final map = decoded as Map<String, dynamic>;
      if (map['schemaVersion'] != schemaVersion) return null;
      return _fromJson(map);
    } catch (e) {
      debugPrint('读取音乐库快照失败: $e');
      return null; // 损坏/不兼容的快照按无缓存处理
    }
  }

  Future<void> save(LibrarySnapshot snapshot) async {
    final file = await _file();
    final payload = _toJson(snapshot);
    final text = await Isolate.run(() => jsonEncode(payload));
    await _writeAtomically(file, text);
  }

  Future<void> clear() async => _deleteAtomically(await _file());

  Map<String, Object?> _toJson(LibrarySnapshot snapshot) => <String, Object?>{
        'schemaVersion': schemaVersion,
        'directory': snapshot.directory,
        'hasScanned': snapshot.hasScanned,
        'scannedAt': snapshot.scannedAt?.millisecondsSinceEpoch,
        'tracks': [for (final t in snapshot.tracks) uiTrackToJson(t)],
        'albums': [for (final a in snapshot.albums) _albumToJson(a)],
        'artists': [for (final a in snapshot.artists) _artistToJson(a)],
      };

  LibrarySnapshot _fromJson(Map<String, dynamic> map) {
    return LibrarySnapshot(
      directory: map['directory'] as String?,
      hasScanned: map['hasScanned'] as bool? ?? false,
      scannedAt: map['scannedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['scannedAt'] as int)
          : null,
      tracks: <rust.UiTrack>[
        for (final item in map['tracks'] as List? ?? const <dynamic>[])
          uiTrackFromJson(item as Map<String, dynamic>),
      ],
      albums: <rust.UiAlbum>[
        for (final item in map['albums'] as List? ?? const <dynamic>[])
          _albumFromJson(item as Map<String, dynamic>),
      ],
      artists: <rust.UiArtist>[
        for (final item in map['artists'] as List? ?? const <dynamic>[])
          _artistFromJson(item as Map<String, dynamic>),
      ],
    );
  }

  Map<String, Object?> _albumToJson(rust.UiAlbum a) => <String, Object?>{
        'id': a.id,
        'title': a.title,
        'artist': a.artist,
        'year': a.year,
        'trackCount': a.trackCount,
        'coverTrackId': a.coverTrackId,
        'trackIds': a.trackIds,
      };

  rust.UiAlbum _albumFromJson(Map<String, dynamic> m) => rust.UiAlbum(
        id: m['id'] as String,
        title: m['title'] as String,
        artist: m['artist'] as String,
        year: m['year'] as int?,
        trackCount: m['trackCount'] as int,
        coverTrackId: m['coverTrackId'] as String,
        trackIds: (m['trackIds'] as List? ?? const <dynamic>[]).cast<String>(),
      );

  Map<String, Object?> _artistToJson(rust.UiArtist a) => <String, Object?>{
        'id': a.id,
        'name': a.name,
        'trackCount': a.trackCount,
        'coverTrackId': a.coverTrackId,
      };

  rust.UiArtist _artistFromJson(Map<String, dynamic> m) => rust.UiArtist(
        id: m['id'] as String,
        name: m['name'] as String,
        trackCount: m['trackCount'] as int,
        coverTrackId: m['coverTrackId'] as String,
      );
}

// ---------------------------------------------------------------------------
// 播放队列/位置快照
// ---------------------------------------------------------------------------

/// 播放状态快照(小文件,随播放进度更新)
class PlaybackStateSnapshot {
  const PlaybackStateSnapshot({
    required this.currentIndex,
    required this.currentTrackId,
    required this.position,
    required this.source,
    required this.shuffle,
    required this.repeatMode,
  });

  final int currentIndex;
  final String? currentTrackId;
  final Duration position;
  final String source;
  final bool shuffle;

  /// 与 PlaybackRepeatMode.name 对应,避免持久化层依赖播放状态层
  final String repeatMode;
}

/// 启动恢复用的完整播放快照(队列文件 + 状态文件合并结果)
class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.queue,
    required this.currentIndex,
    required this.position,
    required this.source,
    required this.shuffle,
    required this.repeatMode,
  });

  final List<rust.UiTrack> queue;
  final int currentIndex;
  final Duration position;
  final String source;
  final bool shuffle;
  final String repeatMode;
}

/// 播放队列/位置存储。
///
/// 队列文件只在队列内容变化时写(可能几 MB),状态文件很小,
/// 随播放进度每几秒写一次,避免反复序列化整个队列。
class PlaybackSnapshotStore {
  static const int schemaVersion = 1;
  static const String _queueFileName = 'playback_queue.json';
  static const String _stateFileName = 'playback_state.json';

  Future<File> _queueFile() => _appDataFile(_queueFileName);
  Future<File> _stateFile() => _appDataFile(_stateFileName);

  Future<PlaybackSnapshot?> load() async {
    try {
      final queueFile = await _queueFile();
      if (!await queueFile.exists()) return null;

      final queueText = await queueFile.readAsString();
      final queueDecoded = await Isolate.run(() => jsonDecode(queueText));
      final queueMap = queueDecoded as Map<String, dynamic>;
      if (queueMap['schemaVersion'] != schemaVersion) return null;

      final tracks = <rust.UiTrack>[
        for (final item in queueMap['tracks'] as List? ?? const <dynamic>[])
          uiTrackFromJson(item as Map<String, dynamic>),
      ];
      if (tracks.isEmpty) return null;

      var currentIndex = 0;
      var position = Duration.zero;
      var source = '曲目';
      var shuffle = false;
      var repeatMode = 'off';

      final stateFile = await _stateFile();
      if (await stateFile.exists()) {
        final stateMap =
            jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
        if (stateMap['schemaVersion'] == schemaVersion) {
          currentIndex = (stateMap['currentIndex'] as int? ?? 0)
              .clamp(0, tracks.length - 1);
          source = stateMap['source'] as String? ?? source;
          shuffle = stateMap['shuffle'] as bool? ?? false;
          repeatMode = stateMap['repeatMode'] as String? ?? repeatMode;

          final savedTrackId = stateMap['currentTrackId'] as String?;
          if (savedTrackId != null) {
            // 优先信任保存的索引(队列允许重复曲目);只有索引对不上时才按 id 查找
            if (tracks[currentIndex].id != savedTrackId) {
              final found = tracks.indexWhere((t) => t.id == savedTrackId);
              if (found >= 0) currentIndex = found;
            }
            // 只有状态文件与当前曲目一致时才恢复进度
            if (savedTrackId == tracks[currentIndex].id) {
              position = Duration(
                milliseconds: stateMap['positionMs'] as int? ?? 0,
              );
            }
          }
        }
      }

      return PlaybackSnapshot(
        queue: tracks,
        currentIndex: currentIndex,
        position: position,
        source: source,
        shuffle: shuffle,
        repeatMode: repeatMode,
      );
    } catch (e) {
      debugPrint('读取播放快照失败: $e');
      return null;
    }
  }

  Future<void> saveQueue(List<rust.UiTrack> tracks) async {
    try {
      final file = await _queueFile();
      final payload = <String, Object?>{
        'schemaVersion': schemaVersion,
        'tracks': [for (final t in tracks) uiTrackToJson(t)],
      };
      final text = await Isolate.run(() => jsonEncode(payload));
      await _writeAtomically(file, text);
    } catch (e) {
      debugPrint('保存播放队列失败: $e');
    }
  }

  Future<void> saveState(PlaybackStateSnapshot state) async {
    try {
      final file = await _stateFile();
      final payload = <String, Object?>{
        'schemaVersion': schemaVersion,
        'currentIndex': state.currentIndex,
        'currentTrackId': state.currentTrackId,
        'positionMs': state.position.inMilliseconds,
        'source': state.source,
        'shuffle': state.shuffle,
        'repeatMode': state.repeatMode,
      };
      // 状态文件很小,直接编码,不必开 isolate
      await _writeAtomically(file, jsonEncode(payload));
    } catch (e) {
      debugPrint('保存播放位置失败: $e');
    }
  }

  Future<void> clear() async {
    await _deleteAtomically(await _queueFile());
    await _deleteAtomically(await _stateFile());
  }
}

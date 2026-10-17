import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

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

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}/$_fileName');
  }

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
    } catch (_) {
      return null; // 损坏/不兼容的快照按无缓存处理
    }
  }

  Future<void> save(LibrarySnapshot snapshot) async {
    final file = await _file();
    final payload = _toJson(snapshot);
    final text = await Isolate.run(() => jsonEncode(payload));

    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
      final tmp = File('${file.path}.tmp');
      if (await tmp.exists()) await tmp.delete();
    } catch (_) {
      // 清理失败不影响应用
    }
  }

  Map<String, Object?> _toJson(LibrarySnapshot snapshot) => <String, Object?>{
        'schemaVersion': schemaVersion,
        'directory': snapshot.directory,
        'hasScanned': snapshot.hasScanned,
        'scannedAt': snapshot.scannedAt?.millisecondsSinceEpoch,
        'tracks': [for (final t in snapshot.tracks) _trackToJson(t)],
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
          _trackFromJson(item as Map<String, dynamic>),
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

  Map<String, Object?> _trackToJson(rust.UiTrack t) => <String, Object?>{
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

  rust.UiTrack _trackFromJson(Map<String, dynamic> m) => rust.UiTrack(
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

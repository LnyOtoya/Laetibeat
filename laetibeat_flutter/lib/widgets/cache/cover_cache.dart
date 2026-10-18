import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 远端封面磁盘缓存:按 sourceId 分目录,总容量 LRU 淘汰。
/// 文件名使用 base64Url,避免 coverId 里的特殊字符影响路径。
class RemoteCoverDiskCache {
  RemoteCoverDiskCache({this.maxBytes = 256 * 1024 * 1024});

  static const String _rootName = 'remote_covers';

  /// 磁盘缓存总上限,默认 256MB
  final int maxBytes;

  Directory? _root;
  final Map<String, _CacheEntry> _index = {};
  Future<void>? _initializing;
  bool _loaded = false;

  Future<Uint8List?> read(String sourceId, String coverId) async {
    try {
      await _ensureIndex();
      final file = await _file(sourceId, coverId);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final now = DateTime.now();
      try {
        await file.setLastModified(now);
      } catch (_) {}
      final entry = _index[file.path];
      if (entry != null) {
        entry.lastAccess = now.millisecondsSinceEpoch;
      }
      return bytes;
    } catch (e) {
      debugPrint('读取封面缓存失败: $e');
      return null;
    }
  }

  Future<void> write(String sourceId, String coverId, Uint8List bytes) async {
    if (bytes.isEmpty) return;
    try {
      await _ensureIndex();
      final file = await _file(sourceId, coverId);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
      _index[file.path] = _CacheEntry(
        size: bytes.length,
        lastAccess: DateTime.now().millisecondsSinceEpoch,
      );
      await _evictIfNeeded();
    } catch (e) {
      debugPrint('写入封面缓存失败: $e');
    }
  }

  /// 服务器地址变更或删除时清空该音源的封面
  Future<void> clearSource(String sourceId) async {
    try {
      final root = await _rootDir();
      final dir = Directory('${root.path}/${_sourceDirName(sourceId)}');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      final prefix = '${dir.path}${Platform.pathSeparator}';
      _index.removeWhere((path, _) => path.startsWith(prefix));
    } catch (e) {
      debugPrint('清理封面缓存失败: $e');
    }
  }

  Future<Directory> _rootDir() async {
    final existing = _root;
    if (existing != null) return existing;

    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/$_rootName');
    await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  Future<Directory> _sourceDir(String sourceId) async {
    final root = await _rootDir();
    final dir = Directory('${root.path}/${_sourceDirName(sourceId)}');
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String sourceId, String coverId) async {
    final dir = await _sourceDir(sourceId);
    return File('${dir.path}/${_fileName(coverId)}.img');
  }

  String _sourceDirName(String sourceId) => _encodeKey(sourceId);
  String _fileName(String coverId) => _encodeKey(coverId);

  String _encodeKey(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  Future<void> _ensureIndex() {
    if (_loaded) return Future<void>.value();
    return _initializing ??= _scan();
  }

  Future<void> _scan() async {
    final root = await _rootDir();
    final entries = <String, _CacheEntry>{};
    try {
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        // 清理上次写入中断留下的临时文件
        if (entity.path.endsWith('.tmp')) {
          try {
            await entity.delete();
          } catch (_) {}
          continue;
        }
        if (!entity.path.endsWith('.img')) continue;
        try {
          final stat = await entity.stat();
          entries[entity.path] = _CacheEntry(
            size: stat.size,
            lastAccess: stat.modified.millisecondsSinceEpoch,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('扫描封面缓存失败: $e');
    }
    _index
      ..clear()
      ..addAll(entries);
    _loaded = true;
  }

  Future<void> _evictIfNeeded() async {
    var total = _index.values.fold<int>(0, (sum, entry) => sum + entry.size);
    if (total <= maxBytes) return;

    final sorted = _index.entries.toList()
      ..sort((a, b) => a.value.lastAccess.compareTo(b.value.lastAccess));

    for (final entry in sorted) {
      if (total <= maxBytes) break;
      try {
        final file = File(entry.key);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      _index.remove(entry.key);
      total -= entry.value.size;
    }
  }
}

class _CacheEntry {
  _CacheEntry({required this.size, required this.lastAccess});

  final int size;
  int lastAccess;
}

/// 全局封面磁盘缓存
final RemoteCoverDiskCache remoteCoverDiskCache = RemoteCoverDiskCache();

/// 清理某个音源的封面缓存
Future<void> clearRemoteCoverCache(String sourceId) =>
    remoteCoverDiskCache.clearSource(sourceId);

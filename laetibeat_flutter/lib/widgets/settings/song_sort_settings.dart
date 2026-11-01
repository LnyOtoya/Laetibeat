import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

import 'persistence.dart';

/// 歌曲列表排序方式。
abstract final class SongSortModes {
  static const String defaultSort = '默认';
  static const String title = '标题';
  static const String artist = '艺术家';
  static const String album = '专辑';
  static const String addedTime = '添加时间';

  static const List<String> all = <String>[
    defaultSort,
    title,
    artist,
    album,
    addedTime,
  ];
}

const String kDefaultSongSortKey = 'mobile.defaultSongSort';

/// 歌曲列表默认排序。未设置时使用“默认”。
class DefaultSongSortNotifier extends Notifier<String> {
  @override
  String build() {
    final saved = ref
        .read(sharedPreferencesProvider)
        .getString(kDefaultSongSortKey);
    return SongSortModes.all.contains(saved)
        ? saved!
        : SongSortModes.defaultSort;
  }

  void setMode(String mode) {
    if (!SongSortModes.all.contains(mode) || mode == state) return;
    state = mode;
    unawaited(
      ref.read(sharedPreferencesProvider).setString(kDefaultSongSortKey, mode),
    );
  }
}

final defaultSongSortProvider =
    NotifierProvider<DefaultSongSortNotifier, String>(
      DefaultSongSortNotifier.new,
    );

/// 按当前排序方式返回新列表。
List<rust.UiTrack> sortTracksByMode(List<rust.UiTrack> tracks, String mode) {
  final sorted = List<rust.UiTrack>.of(tracks);
  sorted.sort((rust.UiTrack a, rust.UiTrack b) {
    final result = switch (mode) {
      SongSortModes.artist => _compareByArtist(a, b),
      SongSortModes.album => _compareByAlbum(a, b),
      SongSortModes.addedTime => _compareByAddedTime(a, b),
      _ => _compareTitle(a.title, b.title),
    };
    if (result != 0) return result;
    return a.id.compareTo(b.id);
  });
  return sorted;
}

int _compareByArtist(rust.UiTrack a, rust.UiTrack b) {
  final byArtist = _compareTitle(a.artist, b.artist);
  if (byArtist != 0) return byArtist;
  return _compareTitle(a.title, b.title);
}

int _compareByAlbum(rust.UiTrack a, rust.UiTrack b) {
  final byAlbum = _compareTitle(a.album, b.album);
  if (byAlbum != 0) return byAlbum;

  final discA = a.discNumber ?? 1;
  final discB = b.discNumber ?? 1;
  if (discA != discB) return discA.compareTo(discB);

  final trackA = a.trackNumber ?? 0;
  final trackB = b.trackNumber ?? 0;
  if (trackA != trackB) return trackA.compareTo(trackB);

  return _compareTitle(a.title, b.title);
}

int _compareByAddedTime(rust.UiTrack a, rust.UiTrack b) {
  final timeA = a.modifiedMs?.toInt() ?? 0;
  final timeB = b.modifiedMs?.toInt() ?? 0;
  if (timeA != timeB) return timeB.compareTo(timeA);
  return _compareTitle(a.title, b.title);
}

/// 数字/特殊字符 -> 英文字母 -> 中文 -> 其他。
int _compareTitle(String a, String b) {
  final rankA = _titleRank(a);
  final rankB = _titleRank(b);
  if (rankA != rankB) return rankA.compareTo(rankB);

  final normalizedA = a.trim().toLowerCase();
  final normalizedB = b.trim().toLowerCase();
  return normalizedA.compareTo(normalizedB);
}

int _titleRank(String value) {
  final text = value.trim();
  if (text.isEmpty) return 4;

  final code = text.codeUnitAt(0);
  final isAsciiLetter =
      (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
  if (isAsciiLetter) return 1;

  final isCjk = code >= 0x4E00 && code <= 0x9FFF;
  if (isCjk) return 2;

  if (_isDigitOrSymbol(code)) return 0;
  return 3;
}

bool _isDigitOrSymbol(int code) {
  return code <= 0x40 ||
      (code >= 0x5B && code <= 0x60) ||
      (code >= 0x7B && code <= 0x7E);
}

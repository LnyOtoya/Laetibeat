import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;

/// 远端艺术家列表
final remoteArtistsProvider =
    FutureProvider.family<List<rust_subsonic.UiRemoteArtist>, String>((
      ref,
      sourceId,
    ) {
      return rust_subsonic.subsonicGetArtists(sourceId: sourceId);
    });

typedef RemoteAlbumsKey = ({String sourceId, String artistId});

/// 某艺术家的专辑列表
final remoteAlbumsProvider =
    FutureProvider.family<List<rust_subsonic.UiRemoteAlbum>, RemoteAlbumsKey>((
      ref,
      key,
    ) async {
      final detail = await rust_subsonic.subsonicGetArtist(
        sourceId: key.sourceId,
        artistId: key.artistId,
      );
      return detail.albums;
    });

typedef RemoteTracksKey = ({String sourceId, String albumId});

/// 某专辑的曲目列表
final remoteTracksProvider =
    FutureProvider.family<List<rust_subsonic.UiRemoteTrack>, RemoteTracksKey>((
      ref,
      key,
    ) async {
      final detail = await rust_subsonic.subsonicGetAlbum(
        sourceId: key.sourceId,
        albumId: key.albumId,
      );
      return detail.tracks;
    });

typedef RemoteSearchKey = ({String sourceId, String query});

/// ID3 搜索(search3),一次取回艺术家/专辑/曲目三类结果
final remoteSearchProvider =
    FutureProvider.family<rust_subsonic.UiRemoteSearchResult, RemoteSearchKey>((
      ref,
      key,
    ) {
      return rust_subsonic.subsonicSearch3(
        sourceId: key.sourceId,
        query: key.query,
        artistCount: 50,
        albumCount: 50,
        songCount: 100,
      );
    });

/// 把远端曲目转成播放器/统计通用的 UiTrack
rust.UiTrack remoteTrackToUiTrack(
  rust_subsonic.UiRemoteTrack track,
  String sourceId,
) {
  final seconds = track.durationSeconds.toInt();
  return rust.UiTrack(
    id: track.id,
    relativePath: null,
    title: track.title,
    artist: track.artist,
    album: track.album,
    albumArtist: track.artist,
    albumId: track.albumId ?? '',
    artistId: track.artistId ?? '',
    trackNumber: track.trackNumber,
    discNumber: track.discNumber,
    year: track.year,
    genre: track.genre,
    duration: formatTrackDuration(seconds),
    durationSeconds: BigInt.from(seconds),
    path: '',
    source: 'opensubsonic',
    sourceId: sourceId,
    coverId: track.coverId,
    bitrate: track.bitRate,
    sampleRate: null,
    channels: null,
    modifiedMs: null,
    fileSize: track.size == null ? null : BigInt.from(track.size!.toInt()),
  );
}

/// 秒数格式化为 m:ss
String formatTrackDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

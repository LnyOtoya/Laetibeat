import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/library.dart' as rust_library;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;

/// 远端艺术家列表(读取已同步的本地 SQLite 快照)
final remoteArtistsProvider =
    FutureProvider.family<List<rust_subsonic.UiRemoteArtist>, String>((
      ref,
      sourceId,
    ) {
      return rust_library.queryRemoteArtists(sourceId: sourceId);
    });

typedef RemoteUserNameKey = ({String sourceId, String username});

/// 当前登录用户的服务器用户名(OpenSubsonic getUser)。
///
/// 失败时返回配置里的 username，避免首页欢迎语因为临时网络错误消失。
final remoteUserNameProvider =
    FutureProvider.family<String?, RemoteUserNameKey>((ref, key) async {
      try {
        return await rust_subsonic.subsonicGetUserName(
          sourceId: key.sourceId,
          username: key.username,
        );
      } catch (_) {
        return key.username;
      }
    });

typedef RemoteArtistBiographyKey = ({String sourceId, String artistId});

/// 艺术家简介(OpenSubsonic getArtistInfo2)
final remoteArtistBiographyProvider =
    FutureProvider.family<String?, RemoteArtistBiographyKey>((ref, key) {
      return rust_subsonic.subsonicGetArtistBiography(
        sourceId: key.sourceId,
        artistId: key.artistId,
      );
    });

typedef RemoteAlbumsKey = ({String sourceId, String artistId});

/// 某艺术家的专辑列表(读取本地 SQLite 快照)
final remoteAlbumsProvider =
    FutureProvider.family<List<rust_subsonic.UiRemoteAlbum>, RemoteAlbumsKey>((
      ref,
      key,
    ) {
      return rust_library.queryRemoteAlbums(
        sourceId: key.sourceId,
        artistId: key.artistId,
      );
    });

typedef RemoteTracksKey = ({String sourceId, String albumId});

/// 某专辑的曲目列表(读取本地 SQLite 快照)
final remoteTracksProvider =
    FutureProvider.family<List<rust_subsonic.UiRemoteTrack>, RemoteTracksKey>((
      ref,
      key,
    ) {
      return rust_library.queryRemoteTracks(
        sourceId: key.sourceId,
        albumId: key.albumId,
      );
    });

/// 已同步的全部远端专辑(首页推荐聚合使用)
final remoteAllAlbumsProvider =
    FutureProvider.family<List<rust_subsonic.UiRemoteAlbum>, String>((
      ref,
      sourceId,
    ) {
      return rust_library.queryRemoteAlbums(sourceId: sourceId);
    });

/// 远端歌单列表(OpenSubsonic getPlaylists,实时读取服务器)
final remotePlaylistsProvider =
    FutureProvider.family<List<rust_subsonic.UiRemotePlaylist>, String>((
      ref,
      sourceId,
    ) {
      return rust_subsonic.subsonicGetPlaylists(sourceId: sourceId);
    });

/// 已同步的全部远端曲目(首页推荐聚合使用)
final remoteAllTracksProvider =
    FutureProvider.family<List<rust_subsonic.UiRemoteTrack>, String>((
      ref,
      sourceId,
    ) {
      return rust_library.queryRemoteAllTracks(sourceId: sourceId);
    });

typedef RemoteSearchKey = ({String sourceId, String query});

/// 在已同步的本地快照中搜索,不再直连服务器。
/// 用 autoDispose 避免每次防抖后的查询都常驻缓存。
final remoteSearchProvider = FutureProvider.autoDispose
    .family<rust_subsonic.UiRemoteSearchResult, RemoteSearchKey>((ref, key) {
      return rust_library.searchRemoteLibrary(
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

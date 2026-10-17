import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;

/// 远端艺术家列表
final remoteArtistsProvider = FutureProvider.family<
    List<rust_subsonic.UiRemoteArtist>, String>((ref, sourceId) {
  return rust_subsonic.subsonicGetArtists(sourceId: sourceId);
});

typedef RemoteAlbumsKey = ({String sourceId, String artistId});

/// 某艺术家的专辑列表
final remoteAlbumsProvider = FutureProvider.family<
    List<rust_subsonic.UiRemoteAlbum>, RemoteAlbumsKey>((ref, key) async {
  final detail = await rust_subsonic.subsonicGetArtist(
    sourceId: key.sourceId,
    artistId: key.artistId,
  );
  return detail.albums;
});

typedef RemoteTracksKey = ({String sourceId, String albumId});

/// 某专辑的曲目列表
final remoteTracksProvider = FutureProvider.family<
    List<rust_subsonic.UiRemoteTrack>, RemoteTracksKey>((ref, key) async {
  final detail = await rust_subsonic.subsonicGetAlbum(
    sourceId: key.sourceId,
    albumId: key.albumId,
  );
  return detail.tracks;
});

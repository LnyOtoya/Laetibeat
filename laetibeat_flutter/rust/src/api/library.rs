use flutter_rust_bridge::frb;
use laetibeat_core::remote_library as core_lib;

use super::subsonic::{UiRemoteAlbum, UiRemoteArtist, UiRemoteSearchResult, UiRemoteTrack};

/// 远端音乐库同步摘要
#[frb(non_opaque)]
pub struct UiRemoteSyncMeta {
    pub source_id: String,
    pub base_url: String,
    pub generation: i64,
    /// Unix 毫秒
    pub synced_at: i64,
    pub artist_count: i64,
    pub album_count: i64,
    pub track_count: i64,
    pub elapsed_ms: i64,
}

/// 初始化远端音乐库数据库(Dart 启动时传入应用数据目录下的 db 路径)
pub fn init_library_db(path: String) -> Result<(), String> {
    core_lib::init_db(&path)
}

/// 读取上次同步摘要;从未同步时返回 None。
pub fn get_remote_sync_meta(source_id: String) -> Result<Option<UiRemoteSyncMeta>, String> {
    Ok(core_lib::get_sync_meta(&source_id)?.map(map_sync_meta))
}

/// 读取已同步的远端艺术家列表
pub fn query_remote_artists(source_id: String) -> Result<Vec<UiRemoteArtist>, String> {
    let artists = core_lib::query_artists(&source_id)?;
    Ok(artists.into_iter().map(map_artist).collect())
}

/// 读取已同步的远端专辑列表;传 artist_id 时只返回该艺术家的专辑。
pub fn query_remote_albums(
    source_id: String,
    artist_id: Option<String>,
) -> Result<Vec<UiRemoteAlbum>, String> {
    let albums = core_lib::query_albums(&source_id, artist_id.as_deref())?;
    Ok(albums.into_iter().map(map_album).collect())
}

/// 读取已同步的某张专辑曲目
pub fn query_remote_tracks(
    source_id: String,
    album_id: String,
) -> Result<Vec<UiRemoteTrack>, String> {
    let tracks = core_lib::query_tracks(&source_id, &album_id)?;
    Ok(tracks.into_iter().map(map_track).collect())
}

/// 读取已同步的全部远端曲目(供首页推荐聚合)
pub fn query_remote_all_tracks(source_id: String) -> Result<Vec<UiRemoteTrack>, String> {
    let tracks = core_lib::query_all_tracks(&source_id)?;
    Ok(tracks.into_iter().map(map_track).collect())
}

/// 在本地同步库中搜索艺术家/专辑/曲目
pub fn search_remote_library(
    source_id: String,
    query: String,
    artist_count: i32,
    album_count: i32,
    song_count: i32,
) -> Result<UiRemoteSearchResult, String> {
    let result = core_lib::search(
        &source_id,
        &query,
        artist_count,
        album_count,
        song_count,
    )?;
    Ok(UiRemoteSearchResult {
        artists: result.artists.into_iter().map(map_artist).collect(),
        albums: result.albums.into_iter().map(map_album).collect(),
        tracks: result.tracks.into_iter().map(map_track).collect(),
    })
}

/// 读取本地曲目歌词,优先使用带指纹校验的磁盘缓存。
pub fn resolve_local_lyrics_cached(path: String) -> Result<Option<String>, String> {
    core_lib::resolve_local_lyrics_cached(&path)
}

/// 清空某个音源的远端音乐库(服务器地址变更时使用)
pub fn clear_remote_library(source_id: String) -> Result<(), String> {
    core_lib::clear_library(&source_id)
}

/// 清空某个音源的远端歌词缓存
pub fn clear_remote_lyrics_cache(source_id: String) -> Result<(), String> {
    core_lib::clear_remote_lyrics_cache(&source_id)
}

fn map_sync_meta(meta: core_lib::SyncMeta) -> UiRemoteSyncMeta {
    UiRemoteSyncMeta {
        source_id: meta.source_id,
        base_url: meta.base_url,
        generation: meta.generation,
        synced_at: meta.synced_at,
        artist_count: meta.artist_count,
        album_count: meta.album_count,
        track_count: meta.track_count,
        elapsed_ms: meta.elapsed_ms,
    }
}

fn map_artist(artist: core_lib::RemoteArtistRow) -> UiRemoteArtist {
    UiRemoteArtist {
        id: artist.id,
        name: artist.name,
        cover_id: artist.cover_id,
        album_count: artist.album_count,
    }
}

fn map_album(album: core_lib::RemoteAlbumRow) -> UiRemoteAlbum {
    UiRemoteAlbum {
        id: album.id,
        title: album.title,
        artist: album.artist,
        artist_id: album.artist_id,
        cover_id: album.cover_id,
        song_count: album.song_count,
        duration_seconds: album.duration_seconds,
        year: album.year,
    }
}

fn map_track(track: core_lib::RemoteTrackRow) -> UiRemoteTrack {
    UiRemoteTrack {
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        album_id: track.album_id,
        artist_id: track.artist_id,
        cover_id: track.cover_id,
        duration_seconds: track.duration_seconds,
        track_number: track.track_number,
        disc_number: track.disc_number,
        year: track.year,
        genre: track.genre,
        bit_rate: track.bit_rate,
        suffix: track.suffix,
        size: track.size,
    }
}

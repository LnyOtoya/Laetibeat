//! OpenSubsonic / Subsonic 远端音源封装。

use opensubsonic::data::{
    AlbumId3, AlbumWithSongsId3, ArtistId3, ArtistWithAlbumsId3, Child, ServerInfo as OsServerInfo,
};
use opensubsonic::{Auth, Client, StreamOptions};
use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};
use tokio::runtime::{Builder, Runtime};

static RUNTIME: OnceLock<Runtime> = OnceLock::new();
static CLIENTS: OnceLock<Mutex<HashMap<String, Arc<Client>>>> = OnceLock::new();

/// 认证方式
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SubsonicAuthMode {
    /// OpenSubsonic API Key
    ApiKey,
    /// Subsonic token 鉴权 (username + password)
    Token,
}

/// 服务器配置。`secret` 为 API Key 或密码。
#[derive(Clone)]
pub struct SubsonicConfig {
    pub source_id: String,
    pub base_url: String,
    pub auth_mode: SubsonicAuthMode,
    pub username: Option<String>,
    pub secret: String,
    pub client_name: Option<String>,
}

#[derive(Debug, Clone)]
pub struct RemoteServerInfo {
    pub version: Option<String>,
    pub server_type: Option<String>,
    pub server_version: Option<String>,
    pub open_subsonic: bool,
}

#[derive(Debug, Clone)]
pub struct RemoteArtist {
    pub id: String,
    pub name: String,
    pub cover_id: Option<String>,
    pub album_count: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct RemoteAlbum {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub artist_id: Option<String>,
    pub cover_id: Option<String>,
    pub song_count: Option<i64>,
    pub duration_seconds: Option<i64>,
    pub year: Option<i32>,
}

#[derive(Debug, Clone)]
pub struct RemoteTrack {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub album_id: Option<String>,
    pub artist_id: Option<String>,
    pub cover_id: Option<String>,
    pub duration_seconds: i64,
    pub track_number: Option<i32>,
    pub disc_number: Option<i32>,
    pub year: Option<i32>,
    pub genre: Option<String>,
    pub bit_rate: Option<i32>,
    pub suffix: Option<String>,
    pub size: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct RemoteArtistDetail {
    pub artist: RemoteArtist,
    pub albums: Vec<RemoteAlbum>,
}

#[derive(Debug, Clone)]
pub struct RemoteAlbumDetail {
    pub album: RemoteAlbum,
    pub tracks: Vec<RemoteTrack>,
}

fn map_err<E: std::fmt::Display>(error: E) -> String {
    error.to_string()
}

fn runtime() -> Result<&'static Runtime, String> {
    if let Some(runtime) = RUNTIME.get() {
        return Ok(runtime);
    }
    let runtime = Builder::new_multi_thread()
        .worker_threads(2)
        .thread_name("laetibeat-remote")
        .enable_all()
        .build()
        .map_err(map_err)?;
    let _ = RUNTIME.set(runtime);
    RUNTIME.get().ok_or_else(|| "远端运行时初始化失败".to_string())
}

fn clients() -> &'static Mutex<HashMap<String, Arc<Client>>> {
    CLIENTS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn client(source_id: &str) -> Result<Arc<Client>, String> {
    clients()
        .lock()
        .map_err(map_err)?
        .get(source_id)
        .cloned()
        .ok_or_else(|| format!("服务器未配置或已删除: {source_id}"))
}

/// 配置并测试服务器;成功后把客户端放入注册表。
pub fn configure(config: SubsonicConfig) -> Result<RemoteServerInfo, String> {
    let auth = match config.auth_mode {
        SubsonicAuthMode::ApiKey => Auth::api_key(config.secret),
        SubsonicAuthMode::Token => {
            let username = config
                .username
                .ok_or_else(|| "token 鉴权需要用户名".to_string())?;
            Auth::token(username, config.secret)
        }
    };

    let base_url = config.base_url.trim_end_matches('/');
    let mut client = Client::new(base_url, auth).map_err(map_err)?;
    if let Some(name) = config.client_name.as_deref() {
        client = client.with_client_name(name);
    }

    let info = runtime()?
        .block_on(client.server_info())
        .map_err(map_err)?;

    clients()
        .lock()
        .map_err(map_err)?
        .insert(config.source_id, Arc::new(client));

    Ok(map_server_info(info))
}

/// 删除服务器配置
pub fn remove(source_id: &str) -> Result<(), String> {
    clients().lock().map_err(map_err)?.remove(source_id);
    Ok(())
}

/// 重新 ping 服务器
pub fn ping(source_id: &str) -> Result<RemoteServerInfo, String> {
    let client = client(source_id)?;
    let info = runtime()?
        .block_on(client.server_info())
        .map_err(map_err)?;
    Ok(map_server_info(info))
}

/// 生成带鉴权的播放地址。
/// URL 含凭据,不持久化,每次播放前重新生成。
pub fn stream_url(source_id: &str, track_id: &str) -> Result<String, String> {
    let client = client(source_id)?;
    let url = client
        .stream_url(track_id, &StreamOptions::default())
        .map_err(map_err)?;
    Ok(url.to_string())
}

/// 获取艺术家列表(懒加载浏览的入口)
pub fn get_artists(source_id: &str) -> Result<Vec<RemoteArtist>, String> {
    let client = client(source_id)?;
    let artists = runtime()?
        .block_on(client.get_artists(None))
        .map_err(map_err)?;

    let mut result: Vec<RemoteArtist> = artists
        .index
        .into_iter()
        .flat_map(|index| index.artist)
        .map(map_artist)
        .collect();
    result.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    Ok(result)
}

/// 获取艺术家详情与专辑列表
pub fn get_artist(source_id: &str, artist_id: &str) -> Result<RemoteArtistDetail, String> {
    let client = client(source_id)?;
    let artist = runtime()?
        .block_on(client.get_artist(artist_id))
        .map_err(map_err)?;
    Ok(map_artist_detail(artist))
}

/// 获取专辑详情与曲目列表
pub fn get_album(source_id: &str, album_id: &str) -> Result<RemoteAlbumDetail, String> {
    let client = client(source_id)?;
    let album = runtime()?
        .block_on(client.get_album(album_id))
        .map_err(map_err)?;
    Ok(map_album_detail(album))
}

fn map_server_info(info: OsServerInfo) -> RemoteServerInfo {
    RemoteServerInfo {
        version: info.version,
        server_type: info.server_type,
        server_version: info.server_version,
        open_subsonic: info.open_subsonic,
    }
}

fn map_artist(artist: ArtistId3) -> RemoteArtist {
    RemoteArtist {
        id: artist.id,
        name: artist.name,
        cover_id: artist.cover_art,
        album_count: artist.album_count,
    }
}

fn map_album(album: AlbumId3) -> RemoteAlbum {
    RemoteAlbum {
        id: album.id,
        title: album.name,
        artist: album.artist.unwrap_or_else(|| "未知艺术家".to_string()),
        artist_id: album.artist_id,
        cover_id: album.cover_art,
        song_count: album.song_count,
        duration_seconds: album.duration,
        year: album.year,
    }
}

fn map_track(track: Child) -> RemoteTrack {
    RemoteTrack {
        id: track.id,
        title: track.title,
        artist: track.artist.unwrap_or_else(|| "未知艺术家".to_string()),
        album: track.album.unwrap_or_else(|| "未知专辑".to_string()),
        album_id: track.album_id,
        artist_id: track.artist_id,
        cover_id: track.cover_art,
        duration_seconds: track.duration.unwrap_or(0),
        track_number: track.track,
        disc_number: track.disc_number,
        year: track.year,
        genre: track.genre,
        bit_rate: track.bit_rate,
        suffix: track.suffix,
        size: track.size,
    }
}

fn map_artist_detail(detail: ArtistWithAlbumsId3) -> RemoteArtistDetail {
    let artist = RemoteArtist {
        id: detail.id,
        name: detail.name,
        cover_id: detail.cover_art,
        album_count: detail.album_count,
    };
    let mut albums: Vec<RemoteAlbum> = detail.album.into_iter().map(map_album).collect();
    albums.sort_by(|a, b| b.year.cmp(&a.year).then_with(|| a.title.cmp(&b.title)));
    RemoteArtistDetail { artist, albums }
}

fn map_album_detail(detail: AlbumWithSongsId3) -> RemoteAlbumDetail {
    let album = RemoteAlbum {
        id: detail.id,
        title: detail.name,
        artist: detail.artist.unwrap_or_else(|| "未知艺术家".to_string()),
        artist_id: detail.artist_id,
        cover_id: detail.cover_art,
        song_count: detail.song_count,
        duration_seconds: detail.duration,
        year: detail.year,
    };
    let mut tracks: Vec<RemoteTrack> = detail.song.into_iter().map(map_track).collect();
    tracks.sort_by(|a, b| {
        a.disc_number
            .unwrap_or(0)
            .cmp(&b.disc_number.unwrap_or(0))
            .then_with(|| {
                a.track_number
                    .unwrap_or(0)
                    .cmp(&b.track_number.unwrap_or(0))
            })
            .then_with(|| a.title.cmp(&b.title))
    });
    RemoteAlbumDetail { album, tracks }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn invalid_base_url_fails_without_network() {
        let result = configure(SubsonicConfig {
            source_id: "test".to_string(),
            base_url: "not a url".to_string(),
            auth_mode: SubsonicAuthMode::ApiKey,
            username: None,
            secret: "key".to_string(),
            client_name: None,
        });
        assert!(result.is_err());
    }

    #[test]
    fn removing_unknown_source_is_ok() {
        remove("missing-source").unwrap();
    }
}

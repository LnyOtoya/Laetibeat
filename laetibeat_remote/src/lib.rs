//! OpenSubsonic / Subsonic 远端音源封装。

use opensubsonic::data::{
    AlbumId3, AlbumWithSongsId3, ArtistId3, ArtistWithAlbumsId3, Child, LyricsList,
    Playlist as OsPlaylist, ServerInfo as OsServerInfo, StructuredLyrics,
};
use opensubsonic::{
    AlbumListOptions, AlbumListType, Auth, Client, Search3Options, StreamOptions,
};
use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Duration;
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
    /// 服务器记录的添加时间(ISO 8601)。
    pub created: Option<String>,
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
pub struct RemotePlaylist {
    pub id: String,
    pub name: String,
    pub comment: Option<String>,
    pub owner: Option<String>,
    pub public: Option<bool>,
    pub song_count: Option<i64>,
    pub duration_seconds: Option<i64>,
    pub cover_id: Option<String>,
    pub created: Option<String>,
    pub changed: Option<String>,
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

#[derive(Debug, Clone, Default)]
pub struct RemoteSearchResult {
    pub artists: Vec<RemoteArtist>,
    pub albums: Vec<RemoteAlbum>,
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

fn build_client(config: &SubsonicConfig) -> Result<Client, String> {
    let auth = match config.auth_mode {
        SubsonicAuthMode::ApiKey => Auth::api_key(config.secret.clone()),
        SubsonicAuthMode::Token => {
            let username = config
                .username
                .clone()
                .ok_or_else(|| "token 鉴权需要用户名".to_string())?;
            Auth::token(username, config.secret.clone())
        }
    };

    let base_url = config.base_url.trim_end_matches('/');
    let mut client = Client::new(base_url, auth).map_err(map_err)?;
    if let Some(name) = config.client_name.as_deref() {
        client = client.with_client_name(name);
    }
    Ok(client)
}

/// 测试连接,但不注册客户端。
/// 用于设置页的"测试"按钮,避免测试成功后关闭弹层却留下未保存的客户端。
pub fn test(config: &SubsonicConfig) -> Result<RemoteServerInfo, String> {
    let client = build_client(config)?;
    let info = runtime()?
        .block_on(client.server_info())
        .map_err(map_err)?;
    Ok(map_server_info(info))
}

/// 注册一个已经测试通过的客户端,不发起网络请求。
pub fn register(config: &SubsonicConfig) -> Result<(), String> {
    let client = build_client(config)?;
    clients()
        .lock()
        .map_err(map_err)?
        .insert(config.source_id.clone(), Arc::new(client));
    Ok(())
}

/// 配置并测试服务器;成功后把客户端放入注册表。
pub fn configure(config: SubsonicConfig) -> Result<RemoteServerInfo, String> {
    let info = test(&config)?;
    register(&config)?;
    Ok(info)
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

/// 上报 scrobble。
/// submission=false 为 "now playing" 通知,true 为正式记录一次播放。
pub fn scrobble(
    source_id: &str,
    track_id: &str,
    time_ms: Option<i64>,
    submission: bool,
) -> Result<(), String> {
    let client = client(source_id)?;
    runtime()?
        .block_on(client.scrobble(track_id, time_ms, Some(submission)))
        .map_err(map_err)
}

/// 拉取封面字节。size 为服务端建议的最大边长。
pub fn get_cover_art(
    source_id: &str,
    cover_id: &str,
    size: Option<i32>,
) -> Result<Vec<u8>, String> {
    let client = client(source_id)?;
    let bytes = runtime()?
        .block_on(client.get_cover_art(cover_id, size))
        .map_err(map_err)?;
    Ok(bytes.to_vec())
}

/// 获取歌词:优先 OpenSubsonic 结构化歌词,失败/为空时回退旧版 getLyrics。
pub fn get_lyrics(
    source_id: &str,
    track_id: &str,
    artist: &str,
    title: &str,
) -> Result<Option<String>, String> {
    let client = client(source_id)?;
    let runtime = runtime()?;

    if let Ok(list) = runtime.block_on(client.get_lyrics_by_song_id(track_id, None)) {
        if let Some(text) = structured_lyrics_to_text(&list) {
            return Ok(Some(text));
        }
    }

    let legacy = runtime
        .block_on(client.get_lyrics(Some(artist), Some(title)))
        .map_err(map_err)?;
    let text = legacy.value.unwrap_or_default().trim().to_string();
    if text.is_empty() {
        Ok(None)
    } else {
        Ok(Some(text))
    }
}

/// 把结构化歌词转成 flutter_lyric 能解析的文本:
/// 有时间轴时输出 LRC,否则输出纯文本。
fn structured_lyrics_to_text(list: &LyricsList) -> Option<String> {
    let mut best: Option<&StructuredLyrics> = None;
    for entry in &list.structured_lyrics {
        if entry.line.is_empty() {
            continue;
        }
        // 只取主歌词;没有 kind 的旧服务端也视为主歌词
        let is_main = entry.kind.as_deref().map(|kind| kind == "main").unwrap_or(true);
        if !is_main {
            continue;
        }
        match best {
            None => best = Some(entry),
            Some(current) if entry.synced && !current.synced => best = Some(entry),
            _ => {}
        }
    }

    let entry = best?;
    if entry.synced {
        let offset = entry.offset.unwrap_or(0.0);
        let mut out = String::new();
        for line in &entry.line {
            match line.start {
                Some(start) => {
                    let ms = (start + offset).max(0.0).round() as i64;
                    let minutes = ms / 60_000;
                    let seconds = (ms % 60_000) as f64 / 1000.0;
                    out.push_str(&format!(
                        "[{:02}:{:05.2}]{}\n",
                        minutes, seconds, line.value
                    ));
                }
                None => {
                    out.push_str(&line.value);
                    out.push('\n');
                }
            }
        }
        let text = out.trim_end().to_string();
        if text.is_empty() {
            None
        } else {
            Some(text)
        }
    } else {
        let text = entry
            .line
            .iter()
            .map(|line| line.value.as_str())
            .collect::<Vec<_>>()
            .join("\n");
        if text.trim().is_empty() {
            None
        } else {
            Some(text)
        }
    }
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

/// 获取当前登录用户的信息(OpenSubsonic getUser)。
pub fn get_user_name(source_id: &str, username: &str) -> Result<String, String> {
    let client = client(source_id)?;
    let user = runtime()?
        .block_on(client.get_user(username))
        .map_err(map_err)?;
    Ok(user.username)
}

/// 获取当前用户可见的全部歌单。
pub fn get_playlists(source_id: &str) -> Result<Vec<RemotePlaylist>, String> {
    let client = client(source_id)?;
    let playlists = runtime()?
        .block_on(client.get_playlists(None))
        .map_err(map_err)?;
    Ok(playlists.into_iter().map(map_playlist).collect())
}

/// 分页获取专辑列表(ID3)。offset 从 0 开始,limit 为每页数量。
pub fn get_album_list2(
    source_id: &str,
    offset: i32,
    limit: i32,
) -> Result<Vec<RemoteAlbum>, String> {
    let client = client(source_id)?;
    let mut options = AlbumListOptions::new();
    options.size = Some(limit);
    options.offset = Some(offset);

    let albums = runtime()?
        .block_on(client.get_album_list2(AlbumListType::AlphabeticalByName, &options))
        .map_err(map_err)?;
    Ok(albums.into_iter().map(map_album).collect())
}

/// 获取艺术家详情与专辑列表
pub fn get_artist(source_id: &str, artist_id: &str) -> Result<RemoteArtistDetail, String> {
    let client = client(source_id)?;
    let artist = runtime()?
        .block_on(client.get_artist(artist_id))
        .map_err(map_err)?;
    Ok(map_artist_detail(artist))
}

/// 获取艺术家简介(ID3 getArtistInfo2)。
pub fn get_artist_biography(
    source_id: &str,
    artist_id: &str,
) -> Result<Option<String>, String> {
    let client = client(source_id)?;
    let info = runtime()?
        .block_on(client.get_artist_info2(artist_id, None, None))
        .map_err(map_err)?;
    Ok(info.biography)
}

/// 获取专辑详情与曲目列表
pub fn get_album(source_id: &str, album_id: &str) -> Result<RemoteAlbumDetail, String> {
    let client = client(source_id)?;
    let album = runtime()?
        .block_on(client.get_album(album_id))
        .map_err(map_err)?;
    Ok(map_album_detail(album))
}

/// ID3 搜索(search3):一次返回艺术家/专辑/曲目三类结果。
/// 空查询直接返回空结果,不发请求。
pub fn search3(
    source_id: &str,
    query: &str,
    artist_count: i32,
    album_count: i32,
    song_count: i32,
) -> Result<RemoteSearchResult, String> {
    let query = query.trim();
    if query.is_empty() {
        return Ok(RemoteSearchResult::default());
    }

    let client = client(source_id)?;
    let options = Search3Options::new()
        .artist_count(artist_count)
        .album_count(album_count)
        .song_count(song_count);
    let result = runtime()?
        .block_on(client.search3(query, &options))
        .map_err(map_err)?;

    Ok(RemoteSearchResult {
        artists: result.artist.into_iter().map(map_artist).collect(),
        albums: result.album.into_iter().map(map_album).collect(),
        tracks: result.song.into_iter().map(map_track).collect(),
    })
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
        created: album.created,
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

fn map_playlist(playlist: OsPlaylist) -> RemotePlaylist {
    RemotePlaylist {
        id: playlist.id,
        name: playlist.name,
        comment: playlist.comment,
        owner: playlist.owner,
        public: playlist.public,
        song_count: playlist.song_count,
        duration_seconds: playlist.duration,
        cover_id: playlist.cover_art,
        created: playlist.created,
        changed: playlist.changed,
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
        created: detail.created,
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

    #[test]
    fn empty_search_does_not_require_client() {
        let result = search3("missing-source", "   ", 10, 10, 10).unwrap();
        assert!(result.artists.is_empty());
        assert!(result.albums.is_empty());
        assert!(result.tracks.is_empty());
    }
}


// ---------------------------------------------------------------------------
// LRCLIB
// ---------------------------------------------------------------------------

static LRCLIB_CLIENT: OnceLock<reqwest::Client> = OnceLock::new();

#[derive(Debug, Clone, serde::Deserialize)]
struct LrclibLyrics {
    #[serde(default)]
    duration: Option<f64>,
    #[serde(rename = "plainLyrics", default)]
    plain_lyrics: Option<String>,
    #[serde(rename = "syncedLyrics", default)]
    synced_lyrics: Option<String>,
    #[serde(default)]
    instrumental: bool,
}

fn lrclib_client() -> Result<&'static reqwest::Client, String> {
    if let Some(client) = LRCLIB_CLIENT.get() {
        return Ok(client);
    }
    let client = reqwest::Client::builder()
        .user_agent("Laetibeat/0.1 (OpenSubsonic music player)")
        .timeout(Duration::from_secs(15))
        .build()
        .map_err(map_err)?;
    let _ = LRCLIB_CLIENT.set(client);
    LRCLIB_CLIENT
        .get()
        .ok_or_else(|| "LRCLIB 客户端初始化失败".to_string())
}

/// 从 LRCLIB 精确查询歌词；没有精确结果时做一次搜索兜底。
/// 返回同步歌词优先，其次纯文本歌词。
pub fn get_lrclib_lyrics(
    artist: &str,
    title: &str,
    album: &str,
    duration_seconds: i64,
) -> Result<Option<String>, String> {
    let client = lrclib_client()?;
    let runtime = runtime()?;

    runtime.block_on(async {
        let mut query = vec![
            ("artist_name", artist.to_string()),
            ("track_name", title.to_string()),
        ];
        if !album.trim().is_empty() {
            query.push(("album_name", album.to_string()));
        }
        if duration_seconds > 0 {
            query.push(("duration", duration_seconds.to_string()));
        }

        let response = client
            .get("https://lrclib.net/api/get")
            .query(&query)
            .send()
            .await
            .map_err(map_err)?;

        if response.status() == reqwest::StatusCode::NOT_FOUND {
            return search_lrclib(client, artist, title, duration_seconds).await;
        }
        if !response.status().is_success() {
            return Err(format!("LRCLIB 请求失败: {}", response.status()));
        }

        let item = response.json::<LrclibLyrics>().await.map_err(map_err)?;
        let text = lrclib_text(item);
        if text.is_some() {
            return Ok(text);
        }
        search_lrclib(client, artist, title, duration_seconds).await
    })
}

async fn search_lrclib(
    client: &reqwest::Client,
    artist: &str,
    title: &str,
    duration_seconds: i64,
) -> Result<Option<String>, String> {
    let response = client
        .get("https://lrclib.net/api/search")
        .query(&[
            ("artist_name", artist.to_string()),
            ("track_name", title.to_string()),
        ])
        .send()
        .await
        .map_err(map_err)?;
    if !response.status().is_success() {
        return Ok(None);
    }

    let items = response
        .json::<Vec<LrclibLyrics>>()
        .await
        .map_err(map_err)?;
    let best = items
        .into_iter()
        .filter(|item| !item.instrumental)
        .filter(|item| {
            item.synced_lyrics
                .as_deref()
                .map(|text| !text.trim().is_empty())
                .unwrap_or(false)
                || item
                    .plain_lyrics
                    .as_deref()
                    .map(|text| !text.trim().is_empty())
                    .unwrap_or(false)
        })
        .min_by_key(|item| {
            if duration_seconds <= 0 {
                0
            } else {
                item.duration
                    .map(|duration| (duration - duration_seconds as f64).abs() as i64)
                    .unwrap_or(i64::MAX)
            }
        });

    Ok(best.and_then(lrclib_text))
}

fn lrclib_text(item: LrclibLyrics) -> Option<String> {
    if item.instrumental {
        return None;
    }
    item.synced_lyrics
        .filter(|text| !text.trim().is_empty())
        .or_else(|| item.plain_lyrics.filter(|text| !text.trim().is_empty()))
        .map(|text| text.trim().to_string())
}

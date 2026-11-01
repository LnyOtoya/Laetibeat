use flutter_rust_bridge::frb;
use laetibeat_core::remote_library as core_lib;
use laetibeat_remote as remote;

/// 服务器信息
#[frb(non_opaque)]
pub struct UiSubsonicServerInfo {
    pub version: Option<String>,
    pub server_type: Option<String>,
    pub server_version: Option<String>,
    pub open_subsonic: bool,
}

/// 远端艺术家
#[frb(non_opaque)]
pub struct UiRemoteArtist {
    pub id: String,
    pub name: String,
    pub cover_id: Option<String>,
    pub album_count: Option<i64>,
}

/// 远端专辑
#[frb(non_opaque)]
pub struct UiRemoteAlbum {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub artist_id: Option<String>,
    pub cover_id: Option<String>,
    pub song_count: Option<i64>,
    pub duration_seconds: Option<i64>,
    pub year: Option<i32>,
    pub created: Option<String>,
}

/// 远端曲目
#[frb(non_opaque)]
pub struct UiRemoteTrack {
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

/// 远端歌单
#[frb(non_opaque)]
pub struct UiRemotePlaylist {
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

#[frb(non_opaque)]
pub struct UiRemoteArtistDetail {
    pub artist: UiRemoteArtist,
    pub albums: Vec<UiRemoteAlbum>,
}

#[frb(non_opaque)]
pub struct UiRemoteAlbumDetail {
    pub album: UiRemoteAlbum,
    pub tracks: Vec<UiRemoteTrack>,
}

/// 远端搜索结果(艺术家/专辑/曲目三类)
#[frb(non_opaque)]
pub struct UiRemoteSearchResult {
    pub artists: Vec<UiRemoteArtist>,
    pub albums: Vec<UiRemoteAlbum>,
    pub tracks: Vec<UiRemoteTrack>,
}

fn parse_auth_mode(auth_mode: &str) -> Result<remote::SubsonicAuthMode, String> {
    match auth_mode {
        "apiKey" | "api_key" => Ok(remote::SubsonicAuthMode::ApiKey),
        "token" => Ok(remote::SubsonicAuthMode::Token),
        other => Err(format!("未知认证方式: {other}")),
    }
}

/// 测试连接,只返回服务器信息,不注册客户端。
pub fn test_subsonic_connection(
    base_url: String,
    auth_mode: String,
    username: Option<String>,
    secret: String,
    client_name: Option<String>,
) -> Result<UiSubsonicServerInfo, String> {
    let info = remote::test(&remote::SubsonicConfig {
        // 测试不需要注册,source_id 仅作占位
        source_id: String::new(),
        base_url,
        auth_mode: parse_auth_mode(&auth_mode)?,
        username,
        secret,
        client_name,
    })?;
    Ok(map_server_info(info))
}

/// 注册一个已测试通过的客户端,不发起网络请求。
pub fn register_subsonic(
    source_id: String,
    base_url: String,
    auth_mode: String,
    username: Option<String>,
    secret: String,
    client_name: Option<String>,
) -> Result<(), String> {
    remote::register(&remote::SubsonicConfig {
        source_id,
        base_url,
        auth_mode: parse_auth_mode(&auth_mode)?,
        username,
        secret,
        client_name,
    })
}

/// 配置并测试 OpenSubsonic 服务器,成功后注册客户端。
/// auth_mode: "apiKey" 或 "token"。
pub fn configure_subsonic(
    source_id: String,
    base_url: String,
    auth_mode: String,
    username: Option<String>,
    secret: String,
    client_name: Option<String>,
) -> Result<UiSubsonicServerInfo, String> {
    let info = remote::configure(remote::SubsonicConfig {
        source_id,
        base_url,
        auth_mode: parse_auth_mode(&auth_mode)?,
        username,
        secret,
        client_name,
    })?;
    Ok(map_server_info(info))
}

/// 删除服务器配置
pub fn remove_subsonic(source_id: String) -> Result<(), String> {
    remote::remove(&source_id)
}

/// 重新 ping 服务器
pub fn ping_subsonic(source_id: String) -> Result<UiSubsonicServerInfo, String> {
    remote::ping(&source_id).map(map_server_info)
}

/// 生成远端曲目播放地址(含鉴权参数,不应持久化)
pub fn subsonic_stream_url(source_id: String, track_id: String) -> Result<String, String> {
    remote::stream_url(&source_id, &track_id)
}

/// 上报 scrobble。submission=false 为 now playing,true 为正式记录一次播放。
pub fn subsonic_scrobble(
    source_id: String,
    track_id: String,
    time_ms: Option<i64>,
    submission: bool,
) -> Result<(), String> {
    remote::scrobble(&source_id, &track_id, time_ms, submission)
}

/// 拉取远端封面字节
pub fn subsonic_get_cover_art(
    source_id: String,
    cover_id: String,
    size: Option<i32>,
) -> Result<Vec<u8>, String> {
    remote::get_cover_art(&source_id, &cover_id, size)
}

/// 拉取远端歌词文本;优先结构化歌词,回退旧版 getLyrics
pub fn subsonic_get_lyrics(
    source_id: String,
    track_id: String,
    artist: String,
    title: String,
) -> Result<Option<String>, String> {
    remote::get_lyrics(&source_id, &track_id, &artist, &title)
}

/// 远端歌词负缓存有效期(1 天)。服务器曲库可能变化,不宜太长。
const LYRICS_NEGATIVE_TTL_MS: i64 = 24 * 60 * 60 * 1000;

/// 读取远端歌词,带 SQLite 缓存与负缓存。
/// 网络/服务端错误不写负缓存,避免把临时故障当成"没有歌词"。
pub fn subsonic_get_lyrics_cached(
    source_id: String,
    track_id: String,
    artist: String,
    title: String,
) -> Result<Option<String>, String> {
    let cache_key = format!("opensubsonic:{source_id}:{track_id}");

    // 缓存不可用时不影响歌词请求
    if let Ok(Some(entry)) = core_lib::get_lyrics_cache(&cache_key) {
        return Ok(entry.raw_text);
    }

    match remote::get_lyrics(&source_id, &track_id, &artist, &title) {
        Ok(Some(text)) => {
            let now = now_ms();
            let _ = core_lib::put_lyrics_cache(
                &cache_key,
                "opensubsonic",
                Some(&text),
                false,
                None,
                now,
                None,
            );
            Ok(Some(text))
        }
        Ok(None) => {
            let now = now_ms();
            let _ = core_lib::put_lyrics_cache(
                &cache_key,
                "opensubsonic",
                None,
                false,
                None,
                now,
                Some(now + LYRICS_NEGATIVE_TTL_MS),
            );
            Ok(None)
        }
        Err(error) => Err(error),
    }
}

fn now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_millis() as i64)
        .unwrap_or(0)
}

/// 获取艺术家列表
pub fn subsonic_get_artists(source_id: String) -> Result<Vec<UiRemoteArtist>, String> {
    let artists = remote::get_artists(&source_id)?;
    Ok(artists.into_iter().map(map_artist).collect())
}

/// 获取当前登录用户的用户名(OpenSubsonic getUser)。
pub fn subsonic_get_user_name(
    source_id: String,
    username: String,
) -> Result<String, String> {
    remote::get_user_name(&source_id, &username)
}

/// 获取当前用户可见的全部歌单
pub fn subsonic_get_playlists(source_id: String) -> Result<Vec<UiRemotePlaylist>, String> {
    let playlists = remote::get_playlists(&source_id)?;
    Ok(playlists.into_iter().map(map_playlist).collect())
}

/// 获取艺术家详情与专辑列表
pub fn subsonic_get_artist(
    source_id: String,
    artist_id: String,
) -> Result<UiRemoteArtistDetail, String> {
    let detail = remote::get_artist(&source_id, &artist_id)?;
    Ok(UiRemoteArtistDetail {
        artist: map_artist(detail.artist),
        albums: detail.albums.into_iter().map(map_album).collect(),
    })
}

/// 获取艺术家简介
pub fn subsonic_get_artist_biography(
    source_id: String,
    artist_id: String,
) -> Result<Option<String>, String> {
    remote::get_artist_biography(&source_id, &artist_id)
}

/// 获取专辑详情与曲目列表
pub fn subsonic_get_album(
    source_id: String,
    album_id: String,
) -> Result<UiRemoteAlbumDetail, String> {
    let detail = remote::get_album(&source_id, &album_id)?;
    Ok(UiRemoteAlbumDetail {
        album: map_album(detail.album),
        tracks: detail.tracks.into_iter().map(map_track).collect(),
    })
}

/// ID3 搜索(search3)
pub fn subsonic_search3(
    source_id: String,
    query: String,
    artist_count: i32,
    album_count: i32,
    song_count: i32,
) -> Result<UiRemoteSearchResult, String> {
    let result = remote::search3(
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

fn map_playlist(playlist: remote::RemotePlaylist) -> UiRemotePlaylist {
    UiRemotePlaylist {
        id: playlist.id,
        name: playlist.name,
        comment: playlist.comment,
        owner: playlist.owner,
        public: playlist.public,
        song_count: playlist.song_count,
        duration_seconds: playlist.duration_seconds,
        cover_id: playlist.cover_id,
        created: playlist.created,
        changed: playlist.changed,
    }
}

fn map_server_info(info: remote::RemoteServerInfo) -> UiSubsonicServerInfo {
    UiSubsonicServerInfo {
        version: info.version,
        server_type: info.server_type,
        server_version: info.server_version,
        open_subsonic: info.open_subsonic,
    }
}

fn map_artist(artist: remote::RemoteArtist) -> UiRemoteArtist {
    UiRemoteArtist {
        id: artist.id,
        name: artist.name,
        cover_id: artist.cover_id,
        album_count: artist.album_count,
    }
}

fn map_album(album: remote::RemoteAlbum) -> UiRemoteAlbum {
    UiRemoteAlbum {
        id: album.id,
        title: album.title,
        artist: album.artist,
        artist_id: album.artist_id,
        cover_id: album.cover_id,
        song_count: album.song_count,
        duration_seconds: album.duration_seconds,
        year: album.year,
        created: album.created,
    }
}

fn map_track(track: remote::RemoteTrack) -> UiRemoteTrack {
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

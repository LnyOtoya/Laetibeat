use flutter_rust_bridge::frb;
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
    let mode = match auth_mode.as_str() {
        "apiKey" | "api_key" => remote::SubsonicAuthMode::ApiKey,
        "token" => remote::SubsonicAuthMode::Token,
        other => return Err(format!("未知认证方式: {other}")),
    };

    let info = remote::configure(remote::SubsonicConfig {
        source_id,
        base_url,
        auth_mode: mode,
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

/// 获取艺术家列表
pub fn subsonic_get_artists(source_id: String) -> Result<Vec<UiRemoteArtist>, String> {
    let artists = remote::get_artists(&source_id)?;
    Ok(artists.into_iter().map(map_artist).collect())
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

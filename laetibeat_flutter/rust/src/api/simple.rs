use flutter_rust_bridge::frb;
use laetibeat_core::model::{MusicLibrary, SourceType};
use laetibeat_core::scan_directory;

// 弹出系统原生文件夹选择框,选中返回其路径,取消返回None
pub fn pick_directory() -> Option<String> {
    let picked = rfd::FileDialog::new().pick_folder()?;
    Some(picked.to_string_lossy().to_string())
}

// 简化版单曲结构体
#[frb(non_opaque)]
pub struct  UiTrack {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    /// 专辑艺术家;缺失时为曲目艺术家
    pub album_artist: String,
    /// 专辑聚合 id
    pub album_id: String,
    /// 艺术家聚合 id
    pub artist_id: String,
    pub track_number: Option<u32>,
    pub disc_number: Option<u32>,
    pub year: Option<u32>,
    pub genre: Option<String>,
    pub duration: String,
    // 本地文件的原始绝对路径;非本地音源(如opensubsonic)为空串
    pub path: String,
    /// 音频码率(kbps)
    pub bitrate: Option<u32>,
    /// 采样率(Hz)
    pub sample_rate: Option<u32>,
    /// 声道数
    pub channels: Option<u8>,
}

// 简化版专辑结构体(由 Rust 侧聚合)
#[frb(non_opaque)]
pub struct UiAlbum {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub year: Option<u32>,
    pub track_count: u32,
    /// 封面代表曲目 id
    pub cover_track_id: String,
    /// 专辑内曲目 id,已按碟号/音轨号排序
    pub track_ids: Vec<String>,
}

// 简化版艺术家结构体(由 Rust 侧聚合)
#[frb(non_opaque)]
pub struct UiArtist {
    pub id: String,
    pub name: String,
    pub track_count: u32,
    /// 封面代表曲目 id
    pub cover_track_id: String,
}

// 一次扫描返回的完整音乐库
#[frb(non_opaque)]
pub struct UiLibrary {
    pub tracks: Vec<UiTrack>,
    pub albums: Vec<UiAlbum>,
    pub artists: Vec<UiArtist>,
}

// 扫描本地音乐文件夹,异步执行不阻塞UI
pub fn scan_local_music_folder(dir_path: String) -> Result<UiLibrary, String> {
    let mut library = MusicLibrary::new();

    scan_directory(&mut library, &dir_path)?;
    // 由 Rust 侧完成专辑/艺术家聚合与曲目排序
    library.rebuild_aggregates();

    let tracks = library.tracks.into_iter().map(|track| {
        // 从音源中取出真实本地路径;非本地音源暂时给空串
        let path = match &track.source_type {
            SourceType::LocalFile(p) => p.to_string_lossy().to_string(),
            SourceType::Opensubsonic { .. } => String::new(),
        };
        UiTrack {
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            album_artist: track.album_artist,
            album_id: track.album_id,
            artist_id: track.artist_id,
            track_number: track.track_number,
            disc_number: track.disc_number,
            year: track.year,
            genre: track.genre,
            duration: format_duration(track.duration),
            path,
            bitrate: track.bitrate,
            sample_rate: track.sample_rate,
            channels: track.channels,
        }
    }).collect();

    let albums = library.albums.into_iter().map(|album| UiAlbum {
        id: album.id,
        title: album.title,
        artist: album.artist,
        year: album.year,
        track_count: album.track_count,
        cover_track_id: album.cover_track_id,
        track_ids: album.track_ids,
    }).collect();

    let artists = library.artists.into_iter().map(|artist| UiArtist {
        id: artist.id,
        name: artist.name,
        track_count: artist.track_count,
        cover_track_id: artist.cover_track_id,
    }).collect();

    Ok(UiLibrary {
        tracks,
        albums,
        artists,
    })
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

// 歌曲时长格式化 mm:ss
fn format_duration(seconds: u64) -> String {
    let mins = seconds / 60;
    let secs = seconds % 60;
    format!("{:02}:{:02}", mins,secs)
}
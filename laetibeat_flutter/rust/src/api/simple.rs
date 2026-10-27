use flutter_rust_bridge::frb;
use std::path::PathBuf;
use laetibeat_core::model::{MusicLibrary, SourceType, Track};
use laetibeat_core::scanner::scan_directory_incremental;

// 桌面弹出系统原生文件夹选择框；移动端由 Flutter 原生选择器处理
pub fn pick_directory() -> Option<String> {
    #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
    {
        let picked = rfd::FileDialog::new().pick_folder()?;
        Some(picked.to_string_lossy().to_string())
    }

    #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
    {
        None
    }
}

// 简化版单曲结构体
#[frb(non_opaque)]
pub struct  UiTrack {
    pub id: String,
    /// 相对于音乐库根目录的路径,用作播放统计中的稳定 track_id
    pub relative_path: Option<String>,
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
    /// 原始时长(秒),用于增量扫描与快照重建
    pub duration_seconds: u64,
    // 本地文件的原始绝对路径;非本地音源(如opensubsonic)为空串
    pub path: String,
    /// 音源类型: local / opensubsonic
    pub source: String,
    /// 音源实例 id;远端为服务器配置 id
    pub source_id: String,
    /// 远端封面 id
    pub cover_id: Option<String>,
    /// 音频码率(kbps)
    pub bitrate: Option<u32>,
    /// 采样率(Hz)
    pub sample_rate: Option<u32>,
    /// 声道数
    pub channels: Option<u8>,
    /// 文件修改时间(Unix 毫秒),增量扫描判据
    pub modified_ms: Option<u64>,
    /// 文件大小(字节),增量扫描判据
    pub file_size: Option<u64>,
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

// 增量扫描统计
#[frb(non_opaque)]
pub struct UiScanStats {
    pub total_files: u32,
    pub parsed_files: u32,
    pub reused_files: u32,
    pub removed_files: u32,
    pub elapsed_ms: u64,
}

// 扫描结果:音乐库 + 统计
#[frb(non_opaque)]
pub struct UiScanResult {
    pub library: UiLibrary,
    pub stats: UiScanStats,
}

// 把上次返回给前端的 UiTrack 还原成 core Track,用于增量复用。
// 只处理本地文件;path 为空的(网络音源)不参与本地扫描缓存。
fn ui_track_to_track(track: UiTrack) -> Option<Track> {
    if track.path.is_empty() {
        return None;
    }
    let path = PathBuf::from(&track.path);
    Some(Track {
        id: track.id,
        relative_path: track.relative_path,
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
        duration: track.duration_seconds,
        bitrate: track.bitrate,
        sample_rate: track.sample_rate,
        channels: track.channels,
        modified_ms: track.modified_ms,
        file_size: track.file_size,
        source_type: SourceType::LocalFile(path),
    })
}

// 扫描本地音乐文件夹,异步执行不阻塞UI。
// known_tracks 传上次扫描结果,未变化的文件会直接复用,实现增量扫描。
pub fn scan_local_music_folder(
    dir_path: String,
    known_tracks: Vec<UiTrack>,
) -> Result<UiScanResult, String> {
    let known: Vec<Track> = known_tracks
        .into_iter()
        .filter_map(ui_track_to_track)
        .collect();

    let mut library = MusicLibrary::new();
    let stats = scan_directory_incremental(&mut library, &dir_path, &known)?;
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
            relative_path: track.relative_path,
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
            duration_seconds: track.duration,
            path,
            source: "local".to_string(),
            source_id: String::new(),
            cover_id: None,
            bitrate: track.bitrate,
            sample_rate: track.sample_rate,
            channels: track.channels,
            modified_ms: track.modified_ms,
            file_size: track.file_size,
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

    Ok(UiScanResult {
        library: UiLibrary {
            tracks,
            albums,
            artists,
        },
        stats: UiScanStats {
            total_files: stats.total_files,
            parsed_files: stats.parsed_files,
            reused_files: stats.reused_files,
            removed_files: stats.removed_files,
            elapsed_ms: stats.elapsed_ms,
        },
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
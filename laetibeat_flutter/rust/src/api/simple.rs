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
    pub duration: String,
    // 本地文件的原始绝对路径;非本地音源(如opensubsonic)为空串
    pub path: String,
}

// 扫描本地音乐文件夹,异步执行不阻塞UI
pub fn scan_local_music_folder(dir_path: String) -> Result<Vec<UiTrack>, String> {
    let mut library = MusicLibrary::new();

    scan_directory(&mut library, &dir_path)?;

    let ui_tracks = library.tracks.into_iter().map(|track| {
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
            duration: format_duration(track.duration),
            path,
        }
    }).collect();
    Ok(ui_tracks)
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
use crate::model::{make_album_id, make_artist_id, MusicLibrary, SourceType, Track};
use std::collections::{HashMap, HashSet};
use std::path::Path;
use std::time::{Instant, UNIX_EPOCH};
use lofty::tag::{Accessor, ItemKey};
use walkdir::WalkDir;
use lofty::read_from_path;
use lofty::file::{AudioFile, TaggedFileExt};

/// 一次扫描的统计结果
#[derive(Debug, Clone, Default)]
pub struct ScanStats {
    /// 本次目录中找到的音频文件总数
    pub total_files: u32,
    /// 实际解析标签的文件数(新增/修改)
    pub parsed_files: u32,
    /// 命中 mtime/size 缓存、直接复用的文件数
    pub reused_files: u32,
    /// 上次存在、本次目录中已不存在的文件数
    pub removed_files: u32,
    /// 扫描耗时(毫秒)
    pub elapsed_ms: u64,
}

/// 全量扫描(保留给命令行/测试使用)
pub fn scan_directory<P: AsRef<Path>>(library: &mut MusicLibrary, dir_path: P) -> Result<(), String> {
    scan_directory_incremental(library, dir_path, &[]).map(|_| ())
}

/// 增量扫描:对 mtime + 文件大小未变化的曲目直接复用 known_tracks 中的数据,
/// 只对新增/修改的文件重新读取 lofty 标签。
pub fn scan_directory_incremental<P: AsRef<Path>>(
    library: &mut MusicLibrary,
    dir_path: P,
    known_tracks: &[Track],
) -> Result<ScanStats, String> {
    let started = Instant::now();
    let path = dir_path.as_ref();
    if !path.is_dir() {
        return Err(format!("路径不存在或不是文件夹: {:?}", path));
    }

    // 以上次的曲目 id(本地文件即路径)为键,后续按路径复用
    let known: HashMap<String, &Track> = known_tracks
        .iter()
        .map(|track| (track.id.clone(), track))
        .collect();
    let mut seen: HashSet<String> = HashSet::new();
    let mut stats = ScanStats::default();

    // walkdir替代
    for entry in WalkDir::new(path).into_iter().filter_map(|e| e.ok()) {
        let file_path = entry.path();
        // 判断文件再查后缀
        if !file_path.is_file() {
            continue;
        }
        let Some(ext) = file_path.extension().and_then(|e| e.to_str()) else {
            continue;
        };
        let ext_lower = ext.to_lowercase();
        if ext_lower != "mp3" && ext_lower != "flac" && ext_lower != "m4a" && ext_lower != "wav" {
            continue;
        }

        let path_str = file_path.to_string_lossy().to_string();
        seen.insert(path_str.clone());
        stats.total_files += 1;

        // 文件时间戳与大小:作为"是否需要重新解析"的判据
        let metadata = std::fs::metadata(file_path).ok();
        let modified_ms = metadata
            .as_ref()
            .and_then(|m| m.modified().ok())
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map(|d| d.as_millis() as u64);
        let file_size = metadata.as_ref().map(|m| m.len());

        // 未变化则直接复用上次解析结果
        if let Some(cached) = known.get(&path_str) {
            if modified_ms.is_some()
                && cached.modified_ms == modified_ms
                && cached.file_size == file_size
            {
                library.add_track((**cached).clone());
                stats.reused_files += 1;
                continue;
            }
        }

        // 保底标题
        let fallback_title = file_path
            // 直接把读取到的路径的文件名剔除多余部分当成歌曲名存入title
            .file_stem()
            // 防止不同系统编码不同，所以转换为普通字符串
            .and_then(|s| s.to_str())
            // 保底
            .unwrap_or("未知歌曲")
            // 转换为真正的String
            .to_string();

        let mut title = fallback_title;
        let mut artist = "未知艺术家".to_string();
        let mut album = "本地音乐".to_string();
        let mut duration = 0;

        // 扩展标签字段
        let mut track_number = None;
        let mut disc_number = None;
        let mut album_artist: Option<String> = None;
        let mut year = None;
        let mut genre = None;
        let mut bitrate = None;
        let mut sample_rate = None;
        let mut channels = None;

        // 用lofty读取文件数据
        if let Ok(tagged_file) = read_from_path(file_path) {
            // 获取时长与音频属性
            let properties = tagged_file.properties();
            duration = properties.duration().as_secs();
            bitrate = properties.audio_bitrate();
            sample_rate = properties.sample_rate();
            channels = properties.channels();

            // 获取标签
            if let Some(tag) = tagged_file.primary_tag().or_else(|| tagged_file.first_tag()) {
                if let Some(track_title) = tag.title() {
                    title = track_title.to_string();
                }
                if let Some(track_artist) = tag.artist() {
                    artist = track_artist.to_string();
                }
                if let Some(track_album) = tag.album() {
                    album = track_album.to_string();
                }
                track_number = tag.track();
                disc_number = tag.disk();
                year = tag.date().map(|d| d.year as u32);
                genre = tag.genre().map(|g| g.to_string());
                album_artist = tag
                    .get_string(ItemKey::AlbumArtist)
                    .map(str::to_string);
            }
        }

        // 专辑艺术家缺失时回退到曲目艺术家,避免专辑因 feat. 被拆开
        let album_artist = album_artist.unwrap_or_else(|| artist.clone());
        // 聚合 id 需在字段移动前算好
        let album_id = make_album_id(&album_artist, &album);
        let artist_id = make_artist_id(&artist);
        // 相对音乐库根目录的路径,作为跨音源/跨目录的稳定 track_id
        let relative_path = file_path
            .strip_prefix(path)
            .ok()
            .map(|p| p.to_string_lossy().to_string());

        let track = Track {
            // 直接把路径转换强行为标准的文本字符串
            id: path_str,
            relative_path,
            //把刚才存入的title作为单曲的title
            title,
            artist,
            album,
            album_artist,
            album_id,
            artist_id,
            track_number,
            disc_number,
            year,
            genre,
            duration,
            bitrate,
            sample_rate,
            channels,
            modified_ms,
            file_size,
            source_type: SourceType::LocalFile(file_path.to_path_buf()),
        };

        library.add_track(track);
        stats.parsed_files += 1;
    }

    stats.removed_files = known.keys().filter(|id| !seen.contains(*id)).count() as u32;
    stats.elapsed_ms = started.elapsed().as_millis() as u64;
    Ok(stats)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::PathBuf;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temp_dir() -> PathBuf {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir = std::env::temp_dir().join(format!(
            "laetibeat_scan_{}_{}",
            std::process::id(),
            stamp
        ));
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn incremental_scan_reuses_unchanged_and_counts_removed() {
        let dir = temp_dir();
        let file = dir.join("song.wav");
        // 内容不重要:解析失败也会生成一条兜底曲目,足以验证增量复用逻辑
        fs::write(&file, b"not a real wav").unwrap();

        let mut first_library = MusicLibrary::new();
        let first = scan_directory_incremental(&mut first_library, &dir, &[]).unwrap();
        assert_eq!(first.total_files, 1);
        assert_eq!(first.parsed_files, 1);
        assert_eq!(first.reused_files, 0);
        assert_eq!(first.removed_files, 0);
        assert_eq!(first_library.tracks.len(), 1);
        assert!(first_library.tracks[0].modified_ms.is_some());

        // 第二次扫描:文件未变化,应直接复用
        let known = first_library.tracks.clone();
        let mut second_library = MusicLibrary::new();
        let second = scan_directory_incremental(&mut second_library, &dir, &known).unwrap();
        assert_eq!(second.total_files, 1);
        assert_eq!(second.parsed_files, 0);
        assert_eq!(second.reused_files, 1);
        assert_eq!(second_library.tracks.len(), 1);

        // 删除文件后:应统计为移除
        fs::remove_file(&file).unwrap();
        let mut third_library = MusicLibrary::new();
        let third = scan_directory_incremental(&mut third_library, &dir, &known).unwrap();
        assert_eq!(third.total_files, 0);
        assert_eq!(third.removed_files, 1);

        fs::remove_dir_all(&dir).unwrap();
    }
}

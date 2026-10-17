use crate::model::{make_album_id, make_artist_id, MusicLibrary, SourceType, Track};
use std::path::Path;
use lofty::tag::{Accessor, ItemKey};
// use std::fs;
use walkdir::WalkDir;
use lofty::read_from_path;
use lofty::file::{AudioFile, TaggedFileExt};

pub fn scan_directory<P: AsRef<Path>>(library: &mut MusicLibrary, dir_path: P) -> Result<(), String> {
    let path = dir_path.as_ref();
    if !path.is_dir() {
        return Err(format!("路径不存在或不是文件夹: {:?}", path));
    }

    // walkdir替代
    for entry in WalkDir::new(path).into_iter().filter_map(|e| e.ok()) {
        let file_path = entry.path();
        // 判断文件再查后缀
        if file_path.is_file() {
            // 不确定是否有后缀
            if let Some(ext) = file_path.extension().and_then(|e| e.to_str()) {
                let ext_lower = ext.to_lowercase();
                if ext_lower == "mp3" || ext_lower == "flac" || ext_lower == "m4a" || ext_lower == "wav" {
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

                    let track = Track {
                        // 直接把路径转换强行为标准的文本字符串
                        id: file_path.to_string_lossy().to_string(),
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
                        source_type: SourceType::LocalFile(file_path.to_path_buf()),
                    };

                    library.add_track(track);

                }
            }
            
        }
    }
    Ok(())

}
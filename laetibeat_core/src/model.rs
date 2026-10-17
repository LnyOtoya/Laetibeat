use serde::{Serialize, Deserialize};
use std::path::PathBuf;

// 总结构体
// Serialize, Deserialize对接前端时将结构体转换成json或字节流，传入后再解开
// 也即时所谓的序列化和反序列化
#[derive(Debug, Clone, Serialize, Deserialize)]

// Vec:动态数组/列表
pub struct MusicLibrary {
    pub tracks: Vec<Track>,
    pub albums: Vec<Album>,
    pub artists: Vec<Artist>,
}
// 定义结构体的行为方法
impl MusicLibrary {
    pub fn new() -> Self {
        Self {
            tracks: Vec::new(),
            albums: Vec::new(),
            artists: Vec::new(),
        }
    }

    pub fn add_track(&mut self, track: Track) {
        self.tracks.push(track);
    }

    /// 根据已扫描的曲目重建专辑/艺术家聚合。
    /// 扫描完成后调用一次;专辑内曲目按碟号/音轨号/标题排序。
    pub fn rebuild_aggregates(&mut self) {
        use std::collections::HashMap;

        let by_id: HashMap<String, &Track> =
            self.tracks.iter().map(|t| (t.id.clone(), t)).collect();

        let mut albums: HashMap<String, Album> = HashMap::new();
        let mut artists: HashMap<String, Artist> = HashMap::new();

        for track in &self.tracks {
            let album = albums
                .entry(track.album_id.clone())
                .or_insert_with(|| Album {
                    id: track.album_id.clone(),
                    title: track.album.clone(),
                    artist: track.album_artist.clone(),
                    year: track.year,
                    track_count: 0,
                    cover_track_id: track.id.clone(),
                    track_ids: Vec::new(),
                });
            album.track_count += 1;
            album.track_ids.push(track.id.clone());
            if album.year.is_none() {
                album.year = track.year;
            }

            let artist = artists
                .entry(track.artist_id.clone())
                .or_insert_with(|| Artist {
                    id: track.artist_id.clone(),
                    name: track.artist.clone(),
                    track_count: 0,
                    cover_track_id: track.id.clone(),
                });
            artist.track_count += 1;
        }

        // 专辑内排序:碟号 -> 音轨号 -> 标题(缺省按 0 处理,最后按标题兜底)
        for album in albums.values_mut() {
            album.track_ids.sort_by(|a, b| match (by_id.get(a), by_id.get(b)) {
                (Some(ta), Some(tb)) => ta
                    .disc_number
                    .unwrap_or(0)
                    .cmp(&tb.disc_number.unwrap_or(0))
                    .then_with(|| {
                        ta.track_number
                            .unwrap_or(0)
                            .cmp(&tb.track_number.unwrap_or(0))
                    })
                    .then_with(|| ta.title.to_lowercase().cmp(&tb.title.to_lowercase())),
                _ => std::cmp::Ordering::Equal,
            });
            if let Some(first) = album.track_ids.first() {
                album.cover_track_id = first.clone();
            }
        }

        let mut albums: Vec<Album> = albums.into_values().collect();
        albums.sort_by(|a, b| {
            a.title
                .to_lowercase()
                .cmp(&b.title.to_lowercase())
                .then_with(|| a.artist.to_lowercase().cmp(&b.artist.to_lowercase()))
        });

        let mut artists: Vec<Artist> = artists.into_values().collect();
        artists.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));

        self.albums = albums;
        self.artists = artists;
    }
}


// 单曲结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Track {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    /// 专辑艺术家;标签缺失时回退为 artist
    pub album_artist: String,
    /// 专辑聚合 id(由 album_artist + album 规范化生成)
    pub album_id: String,
    /// 艺术家聚合 id(由 artist 规范化生成)
    pub artist_id: String,
    pub track_number: Option<u32>,
    pub disc_number: Option<u32>,
    pub year: Option<u32>,
    pub genre: Option<String>,
    pub duration: u64,
    /// 音频码率(kbps)
    pub bitrate: Option<u32>,
    /// 采样率(Hz)
    pub sample_rate: Option<u32>,
    /// 声道数
    pub channels: Option<u8>,
    /// 文件修改时间(Unix 毫秒),用于增量扫描判断是否需要重新解析
    pub modified_ms: Option<u64>,
    /// 文件大小(字节),与 mtime 一起作为增量扫描的复用条件
    pub file_size: Option<u64>,
    pub source_type: SourceType,
}

// 专辑结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Album {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub year: Option<u32>,
    pub track_count: u32,
    /// 专辑封面代表曲目(排序后的第一首)
    pub cover_track_id: String,
    /// 专辑内曲目 id,按碟号/音轨号排序
    pub track_ids: Vec<String>,
}

// 艺术家结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Artist {
    pub id: String,
    pub name: String,
    pub track_count: u32,
    /// 艺术家封面代表曲目(第一首)
    pub cover_track_id: String,
}

/// 生成稳定、可比较的专辑聚合 id。
/// 以专辑艺术家+专辑名(忽略大小写/首尾空白)为键,避免同专辑因曲目 feat. 被拆开。
pub fn make_album_id(album_artist: &str, album: &str) -> String {
    format!(
        "album:{}|{}",
        normalize_key(album_artist),
        normalize_key(album)
    )
}

/// 生成稳定、可比较的艺术家聚合 id。
pub fn make_artist_id(artist: &str) -> String {
    format!("artist:{}", normalize_key(artist))
}

fn normalize_key(value: &str) -> String {
    value.trim().to_lowercase()
}


// 播放状态枚举
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PlayState {
    Stopped,
    Playing,
    Paused,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum SourceType {
    LocalFile(PathBuf),
    Opensubsonic { id: String},
}

// 统一音源抽象接口
pub trait AudioSource: Send + Sync {
    fn id(&self) -> String;
    fn get_stream_uri(&self) -> Result<String, String>;
    fn get_track_info(&self) -> Track;
}
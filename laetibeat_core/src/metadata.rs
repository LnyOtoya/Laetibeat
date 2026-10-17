use std::fs;
use std::path::Path;

use lofty::file::TaggedFileExt;
use lofty::picture::PictureType;
use lofty::tag::ItemKey;

/// 读取音频文件内嵌封面字节。
/// 优先前置封面(CoverFront),没有则取第一张;解析失败或无封面返回 None。
pub fn read_cover_bytes(path: &str) -> Option<Vec<u8>> {
    let tagged = lofty::read_from_path(path).ok()?;
    let tag = tagged.primary_tag().or_else(|| tagged.first_tag())?;
    let pictures = tag.pictures();
    let picture = pictures
        .iter()
        .find(|p| p.pic_type() == PictureType::CoverFront)
        .or_else(|| pictures.first())?;
    Some(picture.data().to_vec())
}

/// 读取歌词文本。
/// 优先内嵌标签(Lyrics/UnsyncLyrics),其次同目录同名 .lrc/.txt。
/// 解析失败或无歌词返回 None。
pub fn read_lyrics_text(path: &str) -> Option<String> {
    if let Ok(tagged) = lofty::read_from_path(path) {
        if let Some(tag) = tagged.primary_tag().or_else(|| tagged.first_tag()) {
            // ID3v2 的 USLT 映射到 UnsyncLyrics,其它格式多为 Lyrics
            for key in [ItemKey::Lyrics, ItemKey::UnsyncLyrics] {
                if let Some(text) = tag.get_string(key) {
                    let trimmed = text.trim();
                    if !trimmed.is_empty() {
                        return Some(trimmed.to_string());
                    }
                }
            }
        }
    }
    read_sidecar_lyrics(path)
}

/// 读取音频同目录的同名 .lrc / .txt sidecar 歌词
fn read_sidecar_lyrics(path: &str) -> Option<String> {
    let audio = Path::new(path);
    for ext in ["lrc", "txt"] {
        let candidate = audio.with_extension(ext);
        if let Ok(content) = fs::read_to_string(candidate) {
            let trimmed = content.trim();
            if !trimmed.is_empty() {
                return Some(trimmed.to_string());
            }
        }
    }
    None
}

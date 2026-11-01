use flutter_rust_bridge::frb;
use laetibeat_core::remote_library as core_lib;
use laetibeat_remote as remote;

/// LRCLIB 正缓存有效期：歌词更新不频繁，保留 30 天。
const LRCLIB_POSITIVE_TTL_MS: i64 = 30 * 24 * 60 * 60 * 1000;
/// 未命中负缓存有效期：避免反复请求同一首不存在的歌。
const LRCLIB_NEGATIVE_TTL_MS: i64 = 24 * 60 * 60 * 1000;

fn now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_millis() as i64)
        .unwrap_or(0)
}

fn cache_key(artist: &str, title: &str, album: &str, duration_seconds: i64) -> String {
    format!(
        "lrclib:v1:{}|{}|{}|{}",
        artist.trim().to_lowercase(),
        title.trim().to_lowercase(),
        album.trim().to_lowercase(),
        duration_seconds.max(0),
    )
}

/// 从 LRCLIB 获取歌词，带 SQLite 正/负缓存。
///
/// 网络错误不写负缓存，避免把临时故障当成没有歌词。
#[frb]
pub fn lrclib_get_lyrics(
    title: String,
    artist: String,
    album: String,
    duration_seconds: i64,
) -> Result<Option<String>, String> {
    let key = cache_key(&artist, &title, &album, duration_seconds);

    if let Ok(Some(entry)) = core_lib::get_lyrics_cache(&key) {
        return Ok(entry.raw_text);
    }

    match remote::get_lrclib_lyrics(&artist, &title, &album, duration_seconds) {
        Ok(Some(text)) => {
            let now = now_ms();
            let _ = core_lib::put_lyrics_cache(
                &key,
                "lrclib",
                Some(&text),
                false,
                None,
                now,
                Some(now + LRCLIB_POSITIVE_TTL_MS),
            );
            Ok(Some(text))
        }
        Ok(None) => {
            let now = now_ms();
            let _ = core_lib::put_lyrics_cache(
                &key,
                "lrclib",
                None,
                false,
                None,
                now,
                Some(now + LRCLIB_NEGATIVE_TTL_MS),
            );
            Ok(None)
        }
        Err(error) => Err(error),
    }
}

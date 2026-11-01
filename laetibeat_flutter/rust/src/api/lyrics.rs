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


/// LiriQo 正缓存有效期。
const LIRIQO_POSITIVE_TTL_MS: i64 = 7 * 24 * 60 * 60 * 1000;
/// LiriQo 未命中负缓存有效期。
const LIRIQO_NEGATIVE_TTL_MS: i64 = 24 * 60 * 60 * 1000;

fn liriqo_cache_key(artist: &str, title: &str, duration_seconds: i64) -> String {
    format!(
        "liriqo:v1:{}|{}|{}",
        artist.trim().to_lowercase(),
        title.trim().to_lowercase(),
        duration_seconds.max(0),
    )
}

/// 从 LiriQo 聚合 API 获取歌词，带 SQLite 正/负缓存。
#[frb]
pub fn liriqo_get_lyrics(
    title: String,
    artist: String,
    duration_seconds: i64,
) -> Result<Option<String>, String> {
    let key = liriqo_cache_key(&artist, &title, duration_seconds);

    if let Ok(Some(entry)) = core_lib::get_lyrics_cache(&key) {
        return Ok(entry.raw_text);
    }

    match remote::get_liriqo_lyrics(&artist, &title, duration_seconds) {
        Ok(Some(text)) => {
            let now = now_ms();
            let _ = core_lib::put_lyrics_cache(
                &key,
                "liriqo",
                Some(&text),
                false,
                None,
                now,
                Some(now + LIRIQO_POSITIVE_TTL_MS),
            );
            Ok(Some(text))
        }
        Ok(None) => {
            let now = now_ms();
            let _ = core_lib::put_lyrics_cache(
                &key,
                "liriqo",
                None,
                false,
                None,
                now,
                Some(now + LIRIQO_NEGATIVE_TTL_MS),
            );
            Ok(None)
        }
        Err(error) => Err(error),
    }
}


/// 歌词搜索结果，供“搜索歌词”对话框展示。
#[frb(non_opaque)]
pub struct UiLyricsSearchResult {
    pub id: String,
    pub source: String,
    pub provider: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_seconds: i64,
    pub synced: bool,
    pub sync_level: String,
    pub has_translation: bool,
    pub translation: Option<String>,
    pub text: String,
}

/// 同时搜索 LRCLIB 与 LiriQo，返回多个候选来源。
#[frb]
pub fn search_lyrics(
    title: String,
    artist: String,
    duration_seconds: i64,
) -> Result<Vec<UiLyricsSearchResult>, String> {
    let mut results = Vec::new();
    let mut errors = Vec::new();

    match remote::search_lrclib_lyrics(&artist, &title, duration_seconds) {
        Ok(items) => results.extend(items.into_iter().map(map_search_result)),
        Err(error) => errors.push(error),
    }
    match remote::search_liriqo_lyrics(&artist, &title, duration_seconds) {
        Ok(items) => results.extend(items.into_iter().map(map_search_result)),
        Err(error) => errors.push(error),
    }

    if results.is_empty() && !errors.is_empty() {
        return Err(errors.join("; "));
    }
    Ok(results)
}

fn map_search_result(item: remote::LyricsSearchResult) -> UiLyricsSearchResult {
    UiLyricsSearchResult {
        id: item.id,
        source: item.source,
        provider: item.provider,
        title: item.title,
        artist: item.artist,
        album: item.album,
        duration_seconds: item.duration_seconds,
        synced: item.synced,
        sync_level: item.sync_level,
        has_translation: item.has_translation,
        translation: item.translation,
        text: item.text,
    }
}

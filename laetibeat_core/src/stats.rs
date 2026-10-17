use rusqlite::{params, Connection, OptionalExtension};
use std::sync::{Mutex, OnceLock};

/// 统计库结构版本;后续变更通过 PRAGMA user_version 迁移
const SCHEMA_VERSION: i64 = 1;

static DB: OnceLock<Mutex<Connection>> = OnceLock::new();

const SCHEMA_V1: &str = r#"
CREATE TABLE IF NOT EXISTS play_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT NOT NULL,
    source_id TEXT NOT NULL,
    track_id TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    listened_ms INTEGER NOT NULL,
    track_duration_ms INTEGER,
    completed INTEGER NOT NULL,
    skipped INTEGER NOT NULL,
    queue_source TEXT,
    metadata_json TEXT
);

CREATE INDEX IF NOT EXISTS idx_play_events_track
    ON play_events(source, source_id, track_id);
CREATE INDEX IF NOT EXISTS idx_play_events_started
    ON play_events(started_at);

CREATE TABLE IF NOT EXISTS track_stats (
    source TEXT NOT NULL,
    source_id TEXT NOT NULL,
    track_id TEXT NOT NULL,
    play_count INTEGER NOT NULL DEFAULT 0,
    skip_count INTEGER NOT NULL DEFAULT 0,
    total_listened_ms INTEGER NOT NULL DEFAULT 0,
    first_played_at INTEGER NOT NULL,
    last_played_at INTEGER NOT NULL,
    completed_count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (source, source_id, track_id)
);
"#;

/// 一次播放会话事件(已通过记录阈值)
#[derive(Debug, Clone)]
pub struct PlayEvent {
    pub source: String,
    pub source_id: String,
    pub track_id: String,
    /// Unix 毫秒
    pub started_at: i64,
    pub listened_ms: i64,
    pub track_duration_ms: Option<i64>,
    pub completed: bool,
    pub skipped: bool,
    pub queue_source: Option<String>,
    /// 标题/艺术家/专辑等展示信息快照
    pub metadata_json: Option<String>,
}

/// 曲目聚合统计
#[derive(Debug, Clone)]
pub struct TrackStat {
    pub source: String,
    pub source_id: String,
    pub track_id: String,
    pub play_count: i64,
    pub skip_count: i64,
    pub total_listened_ms: i64,
    pub first_played_at: i64,
    pub last_played_at: i64,
    pub completion_rate: f64,
}

/// 某时间段内的播放汇总
#[derive(Debug, Clone, Default)]
pub struct HistorySummary {
    pub play_count: i64,
    pub track_count: i64,
    pub listened_ms: i64,
    pub top_artist: Option<String>,
    pub top_artist_plays: i64,
    pub top_album: Option<String>,
    pub top_album_artist: Option<String>,
    pub top_album_plays: i64,
}

fn map_err<E: std::fmt::Display>(error: E) -> String {
    error.to_string()
}

fn db() -> Result<std::sync::MutexGuard<'static, Connection>, String> {
    DB.get()
        .ok_or_else(|| "统计库尚未初始化".to_string())?
        .lock()
        .map_err(|_| "统计库锁失败".to_string())
}

/// 初始化统计库。应在应用启动时调用一次;重复调用直接返回。
pub fn init_db(path: &str) -> Result<(), String> {
    if DB.get().is_some() {
        return Ok(());
    }
    let conn = Connection::open(path).map_err(map_err)?;
    conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;")
        .map_err(map_err)?;
    migrate(&conn)?;
    DB.set(Mutex::new(conn))
        .map_err(|_| "统计库已初始化".to_string())?;
    Ok(())
}

fn migrate(conn: &Connection) -> Result<(), String> {
    let version: i64 = conn
        .query_row("PRAGMA user_version", [], |row| row.get(0))
        .map_err(map_err)?;
    if version < SCHEMA_VERSION {
        conn.execute_batch(SCHEMA_V1).map_err(map_err)?;
        conn.pragma_update(None, "user_version", SCHEMA_VERSION)
            .map_err(map_err)?;
    }
    Ok(())
}

/// 写入一条播放事件,并同步更新曲目聚合统计。
pub fn record_event(event: &PlayEvent) -> Result<(), String> {
    let mut conn = db()?;
    let tx = conn.transaction().map_err(map_err)?;
    record_event_on(&tx, event)?;
    tx.commit().map_err(map_err)
}

fn record_event_on(conn: &Connection, event: &PlayEvent) -> Result<(), String> {
    conn.execute(
        "INSERT INTO play_events (
            source, source_id, track_id, started_at, listened_ms,
            track_duration_ms, completed, skipped, queue_source, metadata_json
         ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
        params![
            event.source,
            event.source_id,
            event.track_id,
            event.started_at,
            event.listened_ms,
            event.track_duration_ms,
            if event.completed { 1 } else { 0 },
            if event.skipped { 1 } else { 0 },
            event.queue_source,
            event.metadata_json,
        ],
    )
    .map_err(map_err)?;

    conn.execute(
        "INSERT INTO track_stats (
            source, source_id, track_id, play_count, skip_count,
            total_listened_ms, first_played_at, last_played_at, completed_count
         ) VALUES (?1, ?2, ?3, 1, ?4, ?5, ?6, ?6, ?7)
         ON CONFLICT(source, source_id, track_id) DO UPDATE SET
            play_count = track_stats.play_count + 1,
            skip_count = track_stats.skip_count + excluded.skip_count,
            total_listened_ms = track_stats.total_listened_ms + excluded.total_listened_ms,
            first_played_at = MIN(track_stats.first_played_at, excluded.first_played_at),
            last_played_at = MAX(track_stats.last_played_at, excluded.last_played_at),
            completed_count = track_stats.completed_count + excluded.completed_count",
        params![
            event.source,
            event.source_id,
            event.track_id,
            if event.skipped { 1 } else { 0 },
            event.listened_ms,
            event.started_at,
            if event.completed { 1 } else { 0 },
        ],
    )
    .map_err(map_err)?;

    Ok(())
}

/// 查询某个音源实例下的全部曲目统计。
pub fn query_track_stats(source: &str, source_id: &str) -> Result<Vec<TrackStat>, String> {
    let conn = db()?;
    query_track_stats_on(&conn, source, source_id)
}

fn query_track_stats_on(
    conn: &Connection,
    source: &str,
    source_id: &str,
) -> Result<Vec<TrackStat>, String> {
    let mut stmt = conn
        .prepare(
            "SELECT source, source_id, track_id, play_count, skip_count,
                    total_listened_ms, first_played_at, last_played_at, completed_count
             FROM track_stats
             WHERE source = ?1 AND source_id = ?2",
        )
        .map_err(map_err)?;

    let rows = stmt
        .query_map(params![source, source_id], |row| {
            let play_count: i64 = row.get(3)?;
            let completed_count: i64 = row.get(8)?;
            Ok(TrackStat {
                source: row.get(0)?,
                source_id: row.get(1)?,
                track_id: row.get(2)?,
                play_count,
                skip_count: row.get(4)?,
                total_listened_ms: row.get(5)?,
                first_played_at: row.get(6)?,
                last_played_at: row.get(7)?,
                completion_rate: if play_count > 0 {
                    completed_count as f64 / play_count as f64
                } else {
                    0.0
                },
            })
        })
        .map_err(map_err)?;

    let mut stats = Vec::new();
    for row in rows {
        stats.push(row.map_err(map_err)?);
    }
    Ok(stats)
}

/// 最近播放事件(供首页 History 等后续功能使用)。
pub fn query_recent_events(limit: u32) -> Result<Vec<PlayEvent>, String> {
    let conn = db()?;
    query_recent_events_on(&conn, limit)
}

fn query_recent_events_on(conn: &Connection, limit: u32) -> Result<Vec<PlayEvent>, String> {
    let mut stmt = conn
        .prepare(
            "SELECT source, source_id, track_id, started_at, listened_ms,
                    track_duration_ms, completed, skipped, queue_source, metadata_json
             FROM play_events
             ORDER BY started_at DESC
             LIMIT ?1",
        )
        .map_err(map_err)?;

    let rows = stmt
        .query_map(params![limit as i64], |row| {
            Ok(PlayEvent {
                source: row.get(0)?,
                source_id: row.get(1)?,
                track_id: row.get(2)?,
                started_at: row.get(3)?,
                listened_ms: row.get(4)?,
                track_duration_ms: row.get(5)?,
                completed: row.get::<_, i64>(6)? != 0,
                skipped: row.get::<_, i64>(7)? != 0,
                queue_source: row.get(8)?,
                metadata_json: row.get(9)?,
            })
        })
        .map_err(map_err)?;

    let mut events = Vec::new();
    for row in rows {
        events.push(row.map_err(map_err)?);
    }
    Ok(events)
}

/// 统计某个时间段内的播放次数、去重曲目数和累计收听时长。
pub fn query_history_summary(
    source: &str,
    source_id: &str,
    start_ms: i64,
    end_ms: i64,
) -> Result<HistorySummary, String> {
    let conn = db()?;
    query_history_summary_on(&conn, source, source_id, start_ms, end_ms)
}

fn query_history_summary_on(
    conn: &Connection,
    source: &str,
    source_id: &str,
    start_ms: i64,
    end_ms: i64,
) -> Result<HistorySummary, String> {
    let mut summary = conn
        .query_row(
            "SELECT COUNT(*), COUNT(DISTINCT track_id), COALESCE(SUM(listened_ms), 0)
             FROM play_events
             WHERE source = ?1 AND source_id = ?2
               AND started_at >= ?3 AND started_at < ?4",
            params![source, source_id, start_ms, end_ms],
            |row| {
                Ok(HistorySummary {
                    play_count: row.get(0)?,
                    track_count: row.get(1)?,
                    listened_ms: row.get(2)?,
                    ..HistorySummary::default()
                })
            },
        )
        .map_err(map_err)?;

    // 播放最多的艺术家(按事件次数)
    let top_artist: Option<(String, i64)> = conn
        .query_row(
            "SELECT json_extract(metadata_json, '$.artist') AS name, COUNT(*) AS plays
             FROM play_events
             WHERE source = ?1 AND source_id = ?2
               AND started_at >= ?3 AND started_at < ?4
               AND metadata_json IS NOT NULL
               AND json_valid(metadata_json)
               AND json_extract(metadata_json, '$.artist') IS NOT NULL
               AND json_extract(metadata_json, '$.artist') <> ''
             GROUP BY name
             ORDER BY plays DESC
             LIMIT 1",
            params![source, source_id, start_ms, end_ms],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )
        .optional()
        .map_err(map_err)?;

    // 播放最多的专辑(按 albumId + 专辑名 + 艺术家分组,避免同名专辑合并)
    let top_album: Option<(String, Option<String>, i64)> = conn
        .query_row(
            "SELECT json_extract(metadata_json, '$.album') AS album,
                    json_extract(metadata_json, '$.artist') AS artist,
                    COUNT(*) AS plays
             FROM play_events
             WHERE source = ?1 AND source_id = ?2
               AND started_at >= ?3 AND started_at < ?4
               AND metadata_json IS NOT NULL
               AND json_valid(metadata_json)
               AND json_extract(metadata_json, '$.album') IS NOT NULL
               AND json_extract(metadata_json, '$.album') <> ''
             GROUP BY json_extract(metadata_json, '$.albumId'), album, artist
             ORDER BY plays DESC
             LIMIT 1",
            params![source, source_id, start_ms, end_ms],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
        )
        .optional()
        .map_err(map_err)?;

    if let Some((artist, plays)) = top_artist {
        summary.top_artist = Some(artist);
        summary.top_artist_plays = plays;
    }
    if let Some((album, artist, plays)) = top_album {
        summary.top_album = Some(album);
        summary.top_album_artist = artist;
        summary.top_album_plays = plays;
    }

    Ok(summary)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stats_upsert_and_query() {
        let conn = Connection::open_in_memory().unwrap();
        migrate(&conn).unwrap();

        let event = PlayEvent {
            source: "local".to_string(),
            source_id: "/music".to_string(),
            track_id: "album/song.flac".to_string(),
            started_at: 1_000,
            listened_ms: 30_000,
            track_duration_ms: Some(120_000),
            completed: false,
            skipped: true,
            queue_source: Some("搜索".to_string()),
            metadata_json: Some(
                r#"{"artist":"A","album":"Alb","albumId":"aid"}"#.to_string(),
            ),
        };
        record_event_on(&conn, &event).unwrap();

        let stats = query_track_stats_on(&conn, "local", "/music").unwrap();
        assert_eq!(stats.len(), 1);
        assert_eq!(stats[0].play_count, 1);
        assert_eq!(stats[0].skip_count, 1);
        assert_eq!(stats[0].completion_rate, 0.0);

        let completed = PlayEvent {
            completed: true,
            skipped: false,
            started_at: 2_000,
            ..event.clone()
        };
        record_event_on(&conn, &completed).unwrap();
        let stats = query_track_stats_on(&conn, "local", "/music").unwrap();
        assert_eq!(stats[0].play_count, 2);
        assert_eq!(stats[0].completion_rate, 0.5);
        assert_eq!(stats[0].last_played_at, 2_000);

        let summary = query_history_summary_on(&conn, "local", "/music", 0, 10_000).unwrap();
        assert_eq!(summary.play_count, 2);
        assert_eq!(summary.track_count, 1);
        assert_eq!(summary.listened_ms, 60_000);
        assert_eq!(summary.top_artist.as_deref(), Some("A"));
        assert_eq!(summary.top_artist_plays, 2);
        assert_eq!(summary.top_album.as_deref(), Some("Alb"));
        assert_eq!(summary.top_album_artist.as_deref(), Some("A"));
    }
}

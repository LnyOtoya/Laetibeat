use rusqlite::{params, Connection, OptionalExtension};
use std::sync::{Mutex, MutexGuard, OnceLock};

/// 远端音乐库结构版本;后续变更通过 PRAGMA user_version 迁移。
/// v1: 艺术家/专辑/曲目 + 同步元数据。
const SCHEMA_VERSION: i64 = 1;

static DB: OnceLock<Mutex<Connection>> = OnceLock::new();

const SCHEMA_V1: &str = r#"
CREATE TABLE IF NOT EXISTS remote_sync_meta (
    source_id TEXT PRIMARY KEY,
    base_url TEXT NOT NULL,
    generation INTEGER NOT NULL,
    synced_at INTEGER NOT NULL,
    artist_count INTEGER NOT NULL,
    album_count INTEGER NOT NULL,
    track_count INTEGER NOT NULL,
    elapsed_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS remote_artists (
    source_id TEXT NOT NULL,
    generation INTEGER NOT NULL,
    id TEXT NOT NULL,
    name TEXT NOT NULL,
    name_lower TEXT NOT NULL,
    cover_id TEXT,
    album_count INTEGER,
    PRIMARY KEY (source_id, generation, id)
);
CREATE INDEX IF NOT EXISTS idx_remote_artists_name
    ON remote_artists(source_id, generation, name_lower);

CREATE TABLE IF NOT EXISTS remote_albums (
    source_id TEXT NOT NULL,
    generation INTEGER NOT NULL,
    id TEXT NOT NULL,
    title TEXT NOT NULL,
    title_lower TEXT NOT NULL,
    artist TEXT NOT NULL,
    artist_lower TEXT NOT NULL,
    artist_id TEXT,
    cover_id TEXT,
    song_count INTEGER,
    duration_seconds INTEGER,
    year INTEGER,
    PRIMARY KEY (source_id, generation, id)
);
CREATE INDEX IF NOT EXISTS idx_remote_albums_artist
    ON remote_albums(source_id, generation, artist_id);
CREATE INDEX IF NOT EXISTS idx_remote_albums_title
    ON remote_albums(source_id, generation, title_lower);

CREATE TABLE IF NOT EXISTS remote_tracks (
    source_id TEXT NOT NULL,
    generation INTEGER NOT NULL,
    id TEXT NOT NULL,
    album_id TEXT,
    artist_id TEXT,
    title TEXT NOT NULL,
    title_lower TEXT NOT NULL,
    artist TEXT NOT NULL,
    artist_lower TEXT NOT NULL,
    album TEXT NOT NULL,
    album_lower TEXT NOT NULL,
    cover_id TEXT,
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    track_number INTEGER,
    disc_number INTEGER,
    year INTEGER,
    genre TEXT,
    bit_rate INTEGER,
    suffix TEXT,
    size INTEGER,
    PRIMARY KEY (source_id, generation, id)
);
CREATE INDEX IF NOT EXISTS idx_remote_tracks_album
    ON remote_tracks(source_id, generation, album_id, disc_number, track_number);
CREATE INDEX IF NOT EXISTS idx_remote_tracks_artist
    ON remote_tracks(source_id, generation, artist_id);
CREATE INDEX IF NOT EXISTS idx_remote_tracks_title
    ON remote_tracks(source_id, generation, title_lower);
CREATE INDEX IF NOT EXISTS idx_remote_tracks_artist_lower
    ON remote_tracks(source_id, generation, artist_lower);
CREATE INDEX IF NOT EXISTS idx_remote_tracks_album_lower
    ON remote_tracks(source_id, generation, album_lower);
"#;

/// 一次成功同步的元数据摘要
#[derive(Debug, Clone)]
pub struct SyncMeta {
    pub source_id: String,
    pub base_url: String,
    pub generation: i64,
    pub synced_at: i64,
    pub artist_count: i64,
    pub album_count: i64,
    pub track_count: i64,
    pub elapsed_ms: i64,
}

/// 远端艺术家行
#[derive(Debug, Clone)]
pub struct RemoteArtistRow {
    pub id: String,
    pub name: String,
    pub cover_id: Option<String>,
    pub album_count: Option<i64>,
}

/// 远端专辑行
#[derive(Debug, Clone)]
pub struct RemoteAlbumRow {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub artist_id: Option<String>,
    pub cover_id: Option<String>,
    pub song_count: Option<i64>,
    pub duration_seconds: Option<i64>,
    pub year: Option<i32>,
}

/// 远端曲目行
#[derive(Debug, Clone)]
pub struct RemoteTrackRow {
    pub id: String,
    pub album_id: Option<String>,
    pub artist_id: Option<String>,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub cover_id: Option<String>,
    pub duration_seconds: i64,
    pub track_number: Option<i32>,
    pub disc_number: Option<i32>,
    pub year: Option<i32>,
    pub genre: Option<String>,
    pub bit_rate: Option<i32>,
    pub suffix: Option<String>,
    pub size: Option<i64>,
}

/// 远端搜索的三类结果
#[derive(Debug, Clone, Default)]
pub struct RemoteSearchRows {
    pub artists: Vec<RemoteArtistRow>,
    pub albums: Vec<RemoteAlbumRow>,
    pub tracks: Vec<RemoteTrackRow>,
}

fn map_err<E: std::fmt::Display>(error: E) -> String {
    error.to_string()
}

fn db() -> Result<MutexGuard<'static, Connection>, String> {
    DB.get()
        .ok_or_else(|| "音乐库数据库尚未初始化".to_string())?
        .lock()
        .map_err(|_| "音乐库数据库锁失败".to_string())
}

/// 初始化远端音乐库数据库。应在应用启动时调用一次;重复调用直接返回。
pub fn init_db(path: &str) -> Result<(), String> {
    if DB.get().is_some() {
        return Ok(());
    }
    let conn = Connection::open(path).map_err(map_err)?;
    conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;")
        .map_err(map_err)?;
    migrate(&conn)?;
    DB.set(Mutex::new(conn))
        .map_err(|_| "音乐库数据库已初始化".to_string())?;
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

fn current_generation_on(conn: &Connection, source_id: &str) -> Result<Option<i64>, String> {
    conn.query_row(
        "SELECT generation FROM remote_sync_meta WHERE source_id = ?1",
        params![source_id],
        |row| row.get(0),
    )
    .optional()
    .map_err(map_err)
}

/// 开始一轮同步,返回新的 generation。
/// 旧的或上次崩溃遗留的代际数据会在真正提交前继续保留/清理:
/// - 已有 meta:删除非当前代的孤儿行
/// - 没有 meta:删除该 source 的所有残留行,从 1 开始
pub fn begin_sync(source_id: &str) -> Result<i64, String> {
    let conn = db()?;
    begin_sync_on(&conn, source_id)
}

fn begin_sync_on(conn: &Connection, source_id: &str) -> Result<i64, String> {
    let current = current_generation_on(conn, source_id)?;
    match current {
        Some(generation) => {
            for table in ["remote_artists", "remote_albums", "remote_tracks"] {
                conn.execute(
                    &format!(
                        "DELETE FROM {table} WHERE source_id = ?1 AND generation <> ?2"
                    ),
                    params![source_id, generation],
                )
                .map_err(map_err)?;
            }
            Ok(generation + 1)
        }
        None => {
            for table in ["remote_artists", "remote_albums", "remote_tracks"] {
                conn.execute(
                    &format!("DELETE FROM {table} WHERE source_id = ?1"),
                    params![source_id],
                )
                .map_err(map_err)?;
            }
            Ok(1)
        }
    }
}

/// 批量写入艺术家(使用新 generation)
pub fn insert_artists(
    source_id: &str,
    generation: i64,
    artists: &[RemoteArtistRow],
) -> Result<(), String> {
    let conn = db()?;
    insert_artists_on(&conn, source_id, generation, artists)
}

fn insert_artists_on(
    conn: &Connection,
    source_id: &str,
    generation: i64,
    artists: &[RemoteArtistRow],
) -> Result<(), String> {
    if artists.is_empty() {
        return Ok(());
    }
    let tx = conn.unchecked_transaction().map_err(map_err)?;
    {
        let mut stmt = tx
            .prepare(
                "INSERT OR REPLACE INTO remote_artists (
                    source_id, generation, id, name, name_lower, cover_id, album_count
                 ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            )
            .map_err(map_err)?;
        for artist in artists {
            stmt.execute(params![
                source_id,
                generation,
                artist.id,
                artist.name,
                artist.name.to_lowercase(),
                artist.cover_id,
                artist.album_count,
            ])
            .map_err(map_err)?;
        }
    }
    tx.commit().map_err(map_err)
}

/// 批量写入专辑(使用新 generation)
pub fn insert_albums(
    source_id: &str,
    generation: i64,
    albums: &[RemoteAlbumRow],
) -> Result<(), String> {
    let conn = db()?;
    insert_albums_on(&conn, source_id, generation, albums)
}

fn insert_albums_on(
    conn: &Connection,
    source_id: &str,
    generation: i64,
    albums: &[RemoteAlbumRow],
) -> Result<(), String> {
    if albums.is_empty() {
        return Ok(());
    }
    let tx = conn.unchecked_transaction().map_err(map_err)?;
    {
        let mut stmt = tx
            .prepare(
                "INSERT OR REPLACE INTO remote_albums (
                    source_id, generation, id, title, title_lower, artist, artist_lower,
                    artist_id, cover_id, song_count, duration_seconds, year
                 ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)",
            )
            .map_err(map_err)?;
        for album in albums {
            stmt.execute(params![
                source_id,
                generation,
                album.id,
                album.title,
                album.title.to_lowercase(),
                album.artist,
                album.artist.to_lowercase(),
                album.artist_id,
                album.cover_id,
                album.song_count,
                album.duration_seconds,
                album.year,
            ])
            .map_err(map_err)?;
        }
    }
    tx.commit().map_err(map_err)
}

/// 批量写入曲目(使用新 generation)
pub fn insert_tracks(
    source_id: &str,
    generation: i64,
    tracks: &[RemoteTrackRow],
) -> Result<(), String> {
    let conn = db()?;
    insert_tracks_on(&conn, source_id, generation, tracks)
}

fn insert_tracks_on(
    conn: &Connection,
    source_id: &str,
    generation: i64,
    tracks: &[RemoteTrackRow],
) -> Result<(), String> {
    if tracks.is_empty() {
        return Ok(());
    }
    let tx = conn.unchecked_transaction().map_err(map_err)?;
    {
        let mut stmt = tx
            .prepare(
                "INSERT OR REPLACE INTO remote_tracks (
                    source_id, generation, id, album_id, artist_id,
                    title, title_lower, artist, artist_lower, album, album_lower,
                    cover_id, duration_seconds, track_number, disc_number,
                    year, genre, bit_rate, suffix, size
                 ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11,
                           ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20)",
            )
            .map_err(map_err)?;
        for track in tracks {
            stmt.execute(params![
                source_id,
                generation,
                track.id,
                track.album_id,
                track.artist_id,
                track.title,
                track.title.to_lowercase(),
                track.artist,
                track.artist.to_lowercase(),
                track.album,
                track.album.to_lowercase(),
                track.cover_id,
                track.duration_seconds,
                track.track_number,
                track.disc_number,
                track.year,
                track.genre,
                track.bit_rate,
                track.suffix,
                track.size,
            ])
            .map_err(map_err)?;
        }
    }
    tx.commit().map_err(map_err)
}

/// 提交一轮同步:删除旧代数据、写入 meta,并返回统计摘要。
pub fn commit_sync(
    source_id: &str,
    generation: i64,
    base_url: &str,
    synced_at: i64,
    elapsed_ms: i64,
) -> Result<SyncMeta, String> {
    let conn = db()?;
    commit_sync_on(
        &conn,
        source_id,
        generation,
        base_url,
        synced_at,
        elapsed_ms,
    )
}

fn commit_sync_on(
    conn: &Connection,
    source_id: &str,
    generation: i64,
    base_url: &str,
    synced_at: i64,
    elapsed_ms: i64,
) -> Result<SyncMeta, String> {
    let tx = conn.unchecked_transaction().map_err(map_err)?;
    for table in ["remote_artists", "remote_albums", "remote_tracks"] {
        tx.execute(
            &format!("DELETE FROM {table} WHERE source_id = ?1 AND generation <> ?2"),
            params![source_id, generation],
        )
        .map_err(map_err)?;
    }

    let artist_count = count_generation(&tx, "remote_artists", source_id, generation)?;
    let album_count = count_generation(&tx, "remote_albums", source_id, generation)?;
    let track_count = count_generation(&tx, "remote_tracks", source_id, generation)?;

    tx.execute(
        "INSERT INTO remote_sync_meta (
            source_id, base_url, generation, synced_at,
            artist_count, album_count, track_count, elapsed_ms
         ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
         ON CONFLICT(source_id) DO UPDATE SET
            base_url = excluded.base_url,
            generation = excluded.generation,
            synced_at = excluded.synced_at,
            artist_count = excluded.artist_count,
            album_count = excluded.album_count,
            track_count = excluded.track_count,
            elapsed_ms = excluded.elapsed_ms",
        params![
            source_id,
            base_url,
            generation,
            synced_at,
            artist_count,
            album_count,
            track_count,
            elapsed_ms,
        ],
    )
    .map_err(map_err)?;
    tx.commit().map_err(map_err)?;

    Ok(SyncMeta {
        source_id: source_id.to_string(),
        base_url: base_url.to_string(),
        generation,
        synced_at,
        artist_count,
        album_count,
        track_count,
        elapsed_ms,
    })
}

fn count_generation(
    conn: &Connection,
    table: &str,
    source_id: &str,
    generation: i64,
) -> Result<i64, String> {
    conn.query_row(
        &format!("SELECT COUNT(*) FROM {table} WHERE source_id = ?1 AND generation = ?2"),
        params![source_id, generation],
        |row| row.get(0),
    )
    .map_err(map_err)
}

/// 放弃一轮同步,删除该代数据;旧代数据保持不变。
pub fn abort_sync(source_id: &str, generation: i64) -> Result<(), String> {
    let conn = db()?;
    abort_sync_on(&conn, source_id, generation)
}

fn abort_sync_on(conn: &Connection, source_id: &str, generation: i64) -> Result<(), String> {
    for table in ["remote_artists", "remote_albums", "remote_tracks"] {
        conn.execute(
            &format!("DELETE FROM {table} WHERE source_id = ?1 AND generation = ?2"),
            params![source_id, generation],
        )
        .map_err(map_err)?;
    }
    Ok(())
}

/// 清空某个音源的全部远端库数据(服务器地址变更时使用)。
pub fn clear_library(source_id: &str) -> Result<(), String> {
    let conn = db()?;
    clear_library_on(&conn, source_id)
}

fn clear_library_on(conn: &Connection, source_id: &str) -> Result<(), String> {
    let tx = conn.unchecked_transaction().map_err(map_err)?;
    for table in ["remote_artists", "remote_albums", "remote_tracks"] {
        tx.execute(
            &format!("DELETE FROM {table} WHERE source_id = ?1"),
            params![source_id],
        )
        .map_err(map_err)?;
    }
    tx.execute(
        "DELETE FROM remote_sync_meta WHERE source_id = ?1",
        params![source_id],
    )
    .map_err(map_err)?;
    tx.commit().map_err(map_err)
}

/// 读取同步摘要;从未同步时返回 None。
pub fn get_sync_meta(source_id: &str) -> Result<Option<SyncMeta>, String> {
    let conn = db()?;
    get_sync_meta_on(&conn, source_id)
}

fn get_sync_meta_on(conn: &Connection, source_id: &str) -> Result<Option<SyncMeta>, String> {
    conn.query_row(
        "SELECT source_id, base_url, generation, synced_at,
                artist_count, album_count, track_count, elapsed_ms
         FROM remote_sync_meta WHERE source_id = ?1",
        params![source_id],
        |row| {
            Ok(SyncMeta {
                source_id: row.get(0)?,
                base_url: row.get(1)?,
                generation: row.get(2)?,
                synced_at: row.get(3)?,
                artist_count: row.get(4)?,
                album_count: row.get(5)?,
                track_count: row.get(6)?,
                elapsed_ms: row.get(7)?,
            })
        },
    )
    .optional()
    .map_err(map_err)
}

/// 读取当前代的全部艺术家。
pub fn query_artists(source_id: &str) -> Result<Vec<RemoteArtistRow>, String> {
    let conn = db()?;
    query_artists_on(&conn, source_id)
}

fn query_artists_on(
    conn: &Connection,
    source_id: &str,
) -> Result<Vec<RemoteArtistRow>, String> {
    let mut stmt = conn
        .prepare(
            "SELECT a.id, a.name, a.cover_id, a.album_count
             FROM remote_artists a
             JOIN remote_sync_meta m
               ON m.source_id = a.source_id AND m.generation = a.generation
             WHERE a.source_id = ?1
             ORDER BY a.name_lower",
        )
        .map_err(map_err)?;
    let rows = stmt
        .query_map(params![source_id], |row| {
            Ok(RemoteArtistRow {
                id: row.get(0)?,
                name: row.get(1)?,
                cover_id: row.get(2)?,
                album_count: row.get(3)?,
            })
        })
        .map_err(map_err)?;
    collect_rows(rows)
}

/// 读取当前代的专辑;artist_id 为 None 时返回全部。
pub fn query_albums(
    source_id: &str,
    artist_id: Option<&str>,
) -> Result<Vec<RemoteAlbumRow>, String> {
    let conn = db()?;
    query_albums_on(&conn, source_id, artist_id)
}

fn query_albums_on(
    conn: &Connection,
    source_id: &str,
    artist_id: Option<&str>,
) -> Result<Vec<RemoteAlbumRow>, String> {
    let select = "SELECT a.id, a.title, a.artist, a.artist_id, a.cover_id,
                         a.song_count, a.duration_seconds, a.year
                  FROM remote_albums a
                  JOIN remote_sync_meta m
                    ON m.source_id = a.source_id AND m.generation = a.generation
                  WHERE a.source_id = ?1";

    if let Some(artist_id) = artist_id {
        let mut stmt = conn
            .prepare(&format!(
                "{select} AND a.artist_id = ?2
                 ORDER BY a.year IS NULL, a.year DESC, a.title_lower"
            ))
            .map_err(map_err)?;
        let rows = stmt
            .query_map(params![source_id, artist_id], map_album_row)
            .map_err(map_err)?;
        collect_rows(rows)
    } else {
        let mut stmt = conn
            .prepare(&format!("{select} ORDER BY a.title_lower"))
            .map_err(map_err)?;
        let rows = stmt
            .query_map(params![source_id], map_album_row)
            .map_err(map_err)?;
        collect_rows(rows)
    }
}

fn map_album_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<RemoteAlbumRow> {
    Ok(RemoteAlbumRow {
        id: row.get(0)?,
        title: row.get(1)?,
        artist: row.get(2)?,
        artist_id: row.get(3)?,
        cover_id: row.get(4)?,
        song_count: row.get(5)?,
        duration_seconds: row.get(6)?,
        year: row.get(7)?,
    })
}

/// 读取当前代中某张专辑的曲目,按碟号/音轨号排序。
pub fn query_tracks(source_id: &str, album_id: &str) -> Result<Vec<RemoteTrackRow>, String> {
    let conn = db()?;
    query_tracks_on(&conn, source_id, album_id)
}

fn query_tracks_on(
    conn: &Connection,
    source_id: &str,
    album_id: &str,
) -> Result<Vec<RemoteTrackRow>, String> {
    let mut stmt = conn
        .prepare(
            "SELECT t.id, t.album_id, t.artist_id, t.title, t.artist, t.album,
                    t.cover_id, t.duration_seconds, t.track_number, t.disc_number,
                    t.year, t.genre, t.bit_rate, t.suffix, t.size
             FROM remote_tracks t
             JOIN remote_sync_meta m
               ON m.source_id = t.source_id AND m.generation = t.generation
             WHERE t.source_id = ?1 AND t.album_id = ?2
             ORDER BY t.disc_number IS NULL, t.disc_number,
                      t.track_number IS NULL, t.track_number, t.title_lower",
        )
        .map_err(map_err)?;
    let rows = stmt
        .query_map(params![source_id, album_id], map_track_row)
        .map_err(map_err)?;
    collect_rows(rows)
}

fn map_track_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<RemoteTrackRow> {
    Ok(RemoteTrackRow {
        id: row.get(0)?,
        album_id: row.get(1)?,
        artist_id: row.get(2)?,
        title: row.get(3)?,
        artist: row.get(4)?,
        album: row.get(5)?,
        cover_id: row.get(6)?,
        duration_seconds: row.get(7)?,
        track_number: row.get(8)?,
        disc_number: row.get(9)?,
        year: row.get(10)?,
        genre: row.get(11)?,
        bit_rate: row.get(12)?,
        suffix: row.get(13)?,
        size: row.get(14)?,
    })
}

/// 在本地同步库中搜索艺术家/专辑/曲目。
pub fn search(
    source_id: &str,
    query: &str,
    artist_count: i32,
    album_count: i32,
    song_count: i32,
) -> Result<RemoteSearchRows, String> {
    let conn = db()?;
    search_on(
        &conn,
        source_id,
        query,
        artist_count,
        album_count,
        song_count,
    )
}

fn search_on(
    conn: &Connection,
    source_id: &str,
    query: &str,
    artist_count: i32,
    album_count: i32,
    song_count: i32,
) -> Result<RemoteSearchRows, String> {
    let trimmed = query.trim();
    if trimmed.is_empty() {
        return Ok(RemoteSearchRows::default());
    }
    let pattern = format!("%{}%", trimmed.to_lowercase());

    let artists = if artist_count > 0 {
        let mut stmt = conn
            .prepare(
                "SELECT a.id, a.name, a.cover_id, a.album_count
                 FROM remote_artists a
                 JOIN remote_sync_meta m
                   ON m.source_id = a.source_id AND m.generation = a.generation
                 WHERE a.source_id = ?1 AND a.name_lower LIKE ?2
                 ORDER BY a.name_lower LIMIT ?3",
            )
            .map_err(map_err)?;
        let rows = stmt
            .query_map(
                params![source_id, &pattern, artist_count as i64],
                |row| {
                    Ok(RemoteArtistRow {
                        id: row.get(0)?,
                        name: row.get(1)?,
                        cover_id: row.get(2)?,
                        album_count: row.get(3)?,
                    })
                },
            )
            .map_err(map_err)?;
        collect_rows(rows)?
    } else {
        Vec::new()
    };

    let albums = if album_count > 0 {
        let mut stmt = conn
            .prepare(
                "SELECT a.id, a.title, a.artist, a.artist_id, a.cover_id,
                        a.song_count, a.duration_seconds, a.year
                 FROM remote_albums a
                 JOIN remote_sync_meta m
                   ON m.source_id = a.source_id AND m.generation = a.generation
                 WHERE a.source_id = ?1
                   AND (a.title_lower LIKE ?2 OR a.artist_lower LIKE ?2)
                 ORDER BY a.title_lower LIMIT ?3",
            )
            .map_err(map_err)?;
        let rows = stmt
            .query_map(
                params![source_id, &pattern, album_count as i64],
                map_album_row,
            )
            .map_err(map_err)?;
        collect_rows(rows)?
    } else {
        Vec::new()
    };

    let tracks = if song_count > 0 {
        let mut stmt = conn
            .prepare(
                "SELECT t.id, t.album_id, t.artist_id, t.title, t.artist, t.album,
                        t.cover_id, t.duration_seconds, t.track_number, t.disc_number,
                        t.year, t.genre, t.bit_rate, t.suffix, t.size
                 FROM remote_tracks t
                 JOIN remote_sync_meta m
                   ON m.source_id = t.source_id AND m.generation = t.generation
                 WHERE t.source_id = ?1
                   AND (t.title_lower LIKE ?2
                        OR t.artist_lower LIKE ?2
                        OR t.album_lower LIKE ?2)
                 ORDER BY t.title_lower LIMIT ?3",
            )
            .map_err(map_err)?;
        let rows = stmt
            .query_map(
                params![source_id, &pattern, song_count as i64],
                map_track_row,
            )
            .map_err(map_err)?;
        collect_rows(rows)?
    } else {
        Vec::new()
    };

    Ok(RemoteSearchRows {
        artists,
        albums,
        tracks,
    })
}

fn collect_rows<T>(rows: impl Iterator<Item = rusqlite::Result<T>>) -> Result<Vec<T>, String> {
    let mut out = Vec::new();
    for row in rows {
        out.push(row.map_err(map_err)?);
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn artist(id: &str, name: &str) -> RemoteArtistRow {
        RemoteArtistRow {
            id: id.to_string(),
            name: name.to_string(),
            cover_id: Some(format!("cover-{id}")),
            album_count: Some(1),
        }
    }

    fn album(id: &str, title: &str, artist_id: &str) -> RemoteAlbumRow {
        RemoteAlbumRow {
            id: id.to_string(),
            title: title.to_string(),
            artist: "Artist".to_string(),
            artist_id: Some(artist_id.to_string()),
            cover_id: Some(format!("cover-{id}")),
            song_count: Some(1),
            duration_seconds: Some(200),
            year: Some(2024),
        }
    }

    fn track(id: &str, title: &str, album_id: &str, artist_id: &str) -> RemoteTrackRow {
        RemoteTrackRow {
            id: id.to_string(),
            album_id: Some(album_id.to_string()),
            artist_id: Some(artist_id.to_string()),
            title: title.to_string(),
            artist: "Artist".to_string(),
            album: "Album".to_string(),
            cover_id: Some(format!("cover-{album_id}")),
            duration_seconds: 200,
            track_number: Some(1),
            disc_number: Some(1),
            year: Some(2024),
            genre: Some("Rock".to_string()),
            bit_rate: Some(320),
            suffix: Some("flac".to_string()),
            size: Some(1024),
        }
    }

    #[test]
    fn generation_switch_queries_and_rollback() {
        let conn = Connection::open_in_memory().unwrap();
        migrate(&conn).unwrap();

        // 第一代同步
        let gen1 = begin_sync_on(&conn, "default").unwrap();
        assert_eq!(gen1, 1);
        insert_artists_on(&conn, "default", gen1, &[artist("a1", "Alpha")]).unwrap();
        insert_albums_on(&conn, "default", gen1, &[album("al1", "First", "a1")]).unwrap();
        insert_tracks_on(
            &conn,
            "default",
            gen1,
            &[track("t1", "Song One", "al1", "a1")],
        )
        .unwrap();

        let meta = commit_sync_on(&conn, "default", gen1, "https://a", 1_000, 42).unwrap();
        assert_eq!(meta.artist_count, 1);
        assert_eq!(meta.album_count, 1);
        assert_eq!(meta.track_count, 1);

        assert_eq!(query_artists_on(&conn, "default").unwrap().len(), 1);
        assert_eq!(
            query_albums_on(&conn, "default", Some("a1")).unwrap().len(),
            1
        );
        assert_eq!(
            query_tracks_on(&conn, "default", "al1").unwrap()[0].title,
            "Song One"
        );

        // 搜索命中艺术家、专辑与曲目
        let result = search_on(&conn, "default", "alpha", 10, 10, 10).unwrap();
        assert_eq!(result.artists.len(), 1);
        assert!(result.albums.is_empty());
        let result = search_on(&conn, "default", "song", 10, 10, 10).unwrap();
        assert_eq!(result.tracks.len(), 1);

        // 第二代同步:提交前仍读旧代
        let gen2 = begin_sync_on(&conn, "default").unwrap();
        assert_eq!(gen2, 2);
        insert_tracks_on(
            &conn,
            "default",
            gen2,
            &[track("t1", "Song Two", "al1", "a1")],
        )
        .unwrap();
        assert_eq!(
            query_tracks_on(&conn, "default", "al1").unwrap()[0].title,
            "Song One"
        );

        let meta = commit_sync_on(&conn, "default", gen2, "https://a", 2_000, 10).unwrap();
        assert_eq!(meta.generation, 2);
        assert_eq!(
            query_tracks_on(&conn, "default", "al1").unwrap()[0].title,
            "Song Two"
        );

        // 旧代应在提交后删除
        let old_rows: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM remote_tracks WHERE source_id = ?1 AND generation = ?2",
                params!["default", gen1],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(old_rows, 0);

        // 第三代同步被放弃:旧数据完整保留
        let gen3 = begin_sync_on(&conn, "default").unwrap();
        insert_tracks_on(
            &conn,
            "default",
            gen3,
            &[track("t1", "Song Three", "al1", "a1")],
        )
        .unwrap();
        abort_sync_on(&conn, "default", gen3).unwrap();
        assert_eq!(
            query_tracks_on(&conn, "default", "al1").unwrap()[0].title,
            "Song Two"
        );
        assert_eq!(
            get_sync_meta_on(&conn, "default")
                .unwrap()
                .unwrap()
                .generation,
            2
        );

        clear_library_on(&conn, "default").unwrap();
        assert!(get_sync_meta_on(&conn, "default").unwrap().is_none());
        assert!(query_artists_on(&conn, "default").unwrap().is_empty());
    }
}

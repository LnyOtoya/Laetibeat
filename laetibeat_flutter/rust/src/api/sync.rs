use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{mpsc, Arc};
use std::time::{Instant, SystemTime, UNIX_EPOCH};

use flutter_rust_bridge::frb;
use laetibeat_core::remote_library as core_lib;
use laetibeat_remote as remote;

use crate::frb_generated::StreamSink;

/// 同一时间只允许一个同步任务,避免两轮同步写同一个 generation。
static SYNCING: AtomicBool = AtomicBool::new(false);

struct SyncFlagGuard;

impl Drop for SyncFlagGuard {
    fn drop(&mut self) {
        SYNCING.store(false, Ordering::SeqCst);
    }
}

/// 远端音乐同步进度。
/// phase: artists / albums / tracks / done / failed
#[frb(non_opaque)]
#[derive(Default)]
pub struct UiRemoteSyncProgress {
    pub phase: String,
    pub completed: i64,
    /// 0 表示当前阶段总数未知
    pub total: i64,
    pub artist_count: i64,
    pub album_count: i64,
    pub track_count: i64,
    pub elapsed_ms: i64,
    pub message: Option<String>,
}

/// 同步 Navidrome 音乐库:拉取艺术家、专辑与曲目,写入本地 library.db。
/// 失败时通过 failed 事件返回错误,并回滚本次 generation。
pub fn sync_subsonic_library(
    source_id: String,
    base_url: String,
    sink: StreamSink<UiRemoteSyncProgress>,
) {
    if SYNCING
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_err()
    {
        let _ = sink.add(UiRemoteSyncProgress {
            phase: "failed".to_string(),
            message: Some("同步已在进行中".to_string()),
            ..Default::default()
        });
        return;
    }
    let _guard = SyncFlagGuard;

    if let Err(error) = run_sync(&source_id, &base_url, &sink) {
        let _ = sink.add(UiRemoteSyncProgress {
            phase: "failed".to_string(),
            message: Some(error),
            ..Default::default()
        });
    }
}

fn run_sync(
    source_id: &str,
    base_url: &str,
    sink: &StreamSink<UiRemoteSyncProgress>,
) -> Result<(), String> {
    let generation = core_lib::begin_sync(source_id)?;
    let started = Instant::now();
    let result = sync_inner(source_id, base_url, sink, generation, started);
    if result.is_err() {
        let _ = core_lib::abort_sync(source_id, generation);
    }
    result
}

fn sync_inner(
    source_id: &str,
    base_url: &str,
    sink: &StreamSink<UiRemoteSyncProgress>,
    generation: i64,
    started: Instant,
) -> Result<(), String> {
    // 1. 艺术家
    let artists = remote::get_artists(source_id)?;
    let artist_rows: Vec<core_lib::RemoteArtistRow> = artists
        .iter()
        .map(|artist| core_lib::RemoteArtistRow {
            id: artist.id.clone(),
            name: artist.name.clone(),
            cover_id: artist.cover_id.clone(),
            album_count: artist.album_count,
        })
        .collect();
    core_lib::insert_artists(source_id, generation, &artist_rows)?;

    let artist_count = artist_rows.len() as i64;
    emit(
        sink,
        UiRemoteSyncProgress {
            phase: "artists".to_string(),
            completed: artist_count,
            total: artist_count,
            artist_count,
            elapsed_ms: elapsed_ms(started),
            ..Default::default()
        },
    )?;

    // 2. 专辑:分页拉取
    let page_size: i32 = 500;
    let mut albums: Vec<remote::RemoteAlbum> = Vec::new();
    let mut offset: i32 = 0;
    let mut pages: usize = 0;
    loop {
        let page = remote::get_album_list2(source_id, offset, page_size)?;
        if page.is_empty() {
            break;
        }
        let page_len = page.len();
        albums.extend(page);
        pages += 1;

        emit(
            sink,
            UiRemoteSyncProgress {
                phase: "albums".to_string(),
                completed: albums.len() as i64,
                total: 0,
                artist_count,
                album_count: albums.len() as i64,
                elapsed_ms: elapsed_ms(started),
                message: Some(format!("已获取 {} 张专辑", albums.len())),
                ..Default::default()
            },
        )?;

        if page_len < page_size as usize {
            break;
        }
        offset = offset.saturating_add(page_len as i32);
        if pages > 10_000 {
            return Err("专辑分页数量异常,已停止同步".to_string());
        }
    }

    let album_rows: Vec<core_lib::RemoteAlbumRow> = albums
        .iter()
        .map(|album| core_lib::RemoteAlbumRow {
            id: album.id.clone(),
            title: album.title.clone(),
            artist: album.artist.clone(),
            artist_id: album.artist_id.clone(),
            cover_id: album.cover_id.clone(),
            song_count: album.song_count,
            duration_seconds: album.duration_seconds,
            year: album.year,
        })
        .collect();
    core_lib::insert_albums(source_id, generation, &album_rows)?;

    emit(
        sink,
        UiRemoteSyncProgress {
            phase: "albums".to_string(),
            completed: album_rows.len() as i64,
            total: album_rows.len() as i64,
            artist_count,
            album_count: album_rows.len() as i64,
            elapsed_ms: elapsed_ms(started),
            ..Default::default()
        },
    )?;

    // 3. 曲目:按专辑并发拉取
    let total_tracks: i64 = albums.iter().filter_map(|album| album.song_count).sum();
    let (fetched_tracks, failed_albums) = fetch_tracks_concurrently(
        source_id,
        &albums,
        sink,
        generation,
        artist_count,
        total_tracks,
        started,
    )?;

    // 4. 提交并切换 generation
    let meta = core_lib::commit_sync(
        source_id,
        generation,
        base_url,
        now_ms(),
        elapsed_ms(started),
    )?;

    let message = if failed_albums > 0 {
        Some(format!(
            "已同步 {} 首,{} 张专辑获取失败",
            fetched_tracks, failed_albums
        ))
    } else {
        None
    };
    // 提交成功后即使进度发送失败也不能回滚已提交的新 generation
    let _ = emit(
        sink,
        UiRemoteSyncProgress {
            phase: "done".to_string(),
            completed: meta.track_count,
            total: meta.track_count,
            artist_count: meta.artist_count,
            album_count: meta.album_count,
            track_count: meta.track_count,
            elapsed_ms: meta.elapsed_ms,
            message,
        },
    );

    Ok(())
}

/// 逐专辑并发拉取曲目。结果由主线程写入数据库,避免并发持有 SQLite 锁。
fn fetch_tracks_concurrently(
    source_id: &str,
    albums: &[remote::RemoteAlbum],
    sink: &StreamSink<UiRemoteSyncProgress>,
    generation: i64,
    artist_count: i64,
    total_tracks: i64,
    started: Instant,
) -> Result<(i64, i64), String> {
    if albums.is_empty() {
        return Ok((0, 0));
    }

    let album_list = Arc::new(albums.to_vec());
    let next = Arc::new(AtomicUsize::new(0));
    let (tx, rx) = mpsc::channel::<(usize, Result<remote::RemoteAlbumDetail, String>)>();

    let worker_count = albums.len().min(4).max(1);
    let mut handles = Vec::with_capacity(worker_count);
    for _ in 0..worker_count {
        let album_list = Arc::clone(&album_list);
        let next = Arc::clone(&next);
        let tx = tx.clone();
        let source_id = source_id.to_string();
        handles.push(std::thread::spawn(move || {
            loop {
                let index = next.fetch_add(1, Ordering::Relaxed);
                if index >= album_list.len() {
                    break;
                }
                let result = remote::get_album(&source_id, &album_list[index].id);
                if tx.send((index, result)).is_err() {
                    break;
                }
            }
        }));
    }
    drop(tx);

    let mut completed_albums: usize = 0;
    let mut fetched_tracks: i64 = 0;
    let mut failed_albums: i64 = 0;
    let mut emit_error: Option<String> = None;

    loop {
        let (index, result) = match rx.recv() {
            Ok(item) => item,
            Err(_) => break,
        };
        let album = &album_list[index];
        match result {
            Ok(detail) => {
                let rows: Vec<core_lib::RemoteTrackRow> = detail
                    .tracks
                    .iter()
                    .map(|track| core_lib::RemoteTrackRow {
                        id: track.id.clone(),
                        album_id: track
                            .album_id
                            .clone()
                            .or_else(|| Some(album.id.clone())),
                        artist_id: track
                            .artist_id
                            .clone()
                            .or_else(|| album.artist_id.clone()),
                        title: track.title.clone(),
                        artist: track.artist.clone(),
                        album: track.album.clone(),
                        cover_id: track
                            .cover_id
                            .clone()
                            .or_else(|| album.cover_id.clone()),
                        duration_seconds: track.duration_seconds,
                        track_number: track.track_number,
                        disc_number: track.disc_number,
                        year: track.year.or(album.year),
                        genre: track.genre.clone(),
                        bit_rate: track.bit_rate,
                        suffix: track.suffix.clone(),
                        size: track.size,
                    })
                    .collect();

                core_lib::insert_tracks(source_id, generation, &rows)?;
                fetched_tracks += rows.len() as i64;
            }
            Err(error) => {
                failed_albums += 1;
                eprintln!("同步专辑 {} 失败: {error}", album.id);
            }
        }

        completed_albums += 1;
        if let Err(error) = emit(
            sink,
            UiRemoteSyncProgress {
                phase: "tracks".to_string(),
                completed: fetched_tracks,
                total: total_tracks,
                artist_count,
                album_count: albums.len() as i64,
                track_count: fetched_tracks,
                elapsed_ms: elapsed_ms(started),
                message: Some(format!(
                    "已处理 {completed_albums}/{} 张专辑",
                    albums.len()
                )),
            },
        ) {
            // 订阅端已取消:停止后续写入,由上层回滚本次 generation
            emit_error = Some(error);
            break;
        }
    }

    drop(rx);
    for handle in handles {
        let _ = handle.join();
    }
    if let Some(error) = emit_error {
        return Err(error);
    }
    Ok((fetched_tracks, failed_albums))
}

fn emit(
    sink: &StreamSink<UiRemoteSyncProgress>,
    progress: UiRemoteSyncProgress,
) -> Result<(), String> {
    sink.add(progress)
        .map_err(|_| "同步进度发送失败".to_string())
}

fn elapsed_ms(started: Instant) -> i64 {
    started.elapsed().as_millis() as i64
}

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis() as i64)
        .unwrap_or(0)
}

use flutter_rust_bridge::frb;
use laetibeat_core::stats as core_stats;

/// 播放事件(已通过记录阈值)
#[frb(non_opaque)]
pub struct UiPlayEvent {
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
#[frb(non_opaque)]
pub struct UiTrackStat {
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

/// 初始化统计库(Dart 启动时传入应用数据目录下的 db 路径)
pub fn init_stats_db(path: String) -> Result<(), String> {
    core_stats::init_db(&path)
}

/// 记录一次播放会话,并更新曲目聚合统计
pub fn record_play_event(event: UiPlayEvent) -> Result<(), String> {
    core_stats::record_event(&core_stats::PlayEvent {
        source: event.source,
        source_id: event.source_id,
        track_id: event.track_id,
        started_at: event.started_at,
        listened_ms: event.listened_ms,
        track_duration_ms: event.track_duration_ms,
        completed: event.completed,
        skipped: event.skipped,
        queue_source: event.queue_source,
        metadata_json: event.metadata_json,
    })
}

/// 查询某个音源实例下的曲目统计
pub fn query_track_stats(
    source: String,
    source_id: String,
) -> Result<Vec<UiTrackStat>, String> {
    let stats = core_stats::query_track_stats(&source, &source_id)?;
    Ok(stats
        .into_iter()
        .map(|stat| UiTrackStat {
            source: stat.source,
            source_id: stat.source_id,
            track_id: stat.track_id,
            play_count: stat.play_count,
            skip_count: stat.skip_count,
            total_listened_ms: stat.total_listened_ms,
            first_played_at: stat.first_played_at,
            last_played_at: stat.last_played_at,
            completion_rate: stat.completion_rate,
        })
        .collect())
}

/// 最近播放事件
pub fn query_recent_play_events(limit: u32) -> Result<Vec<UiPlayEvent>, String> {
    let events = core_stats::query_recent_events(limit)?;
    Ok(events
        .into_iter()
        .map(|event| UiPlayEvent {
            source: event.source,
            source_id: event.source_id,
            track_id: event.track_id,
            started_at: event.started_at,
            listened_ms: event.listened_ms,
            track_duration_ms: event.track_duration_ms,
            completed: event.completed,
            skipped: event.skipped,
            queue_source: event.queue_source,
            metadata_json: event.metadata_json,
        })
        .collect())
}

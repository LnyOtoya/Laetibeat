pub mod metadata;
pub mod model;
pub mod scanner;
pub mod stats;
pub use metadata::{read_cover_bytes, read_lyrics_text};
pub use model::{Album, Artist, MusicLibrary, PlayState, Track};
pub use scanner::{scan_directory, scan_directory_incremental, ScanStats};
pub use stats::{HistorySummary, PlayEvent, TrackStat};


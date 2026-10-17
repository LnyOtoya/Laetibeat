import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import '../settings/persistence.dart';
import 'playback_backend.dart';
import 'playback_session_tracker.dart';
import 'playback_stats.dart';

//播放状态:当前曲目/播放中/进度/来源/队列
//三页右侧播放面板 + 全屏页都读同一份,保证"相互联系"
class PlayerState {
  final List<rust.UiTrack> queue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String source; //播放来源(如'曲目'/'recently add'),由启动播放处设置

  /// 当前音频输出设备
  final AudioDeviceInfo? audioDevice;

  /// 当前可用音频设备列表
  final List<AudioDeviceInfo> audioDevices;

  /// 当前媒体音频参数(声道/采样率)
  final AudioParamsInfo? audioParams;

  /// 当前媒体音频码率(Kbps)
  final double? audioBitrate;

  /// 是否随机播放(打乱队列顺序切下一首)
  final bool shuffle;

  /// 当前重复模式(顺序/单曲/列表)
  final PlaybackRepeatMode repeatMode;

  const PlayerState({
    this.queue = const <rust.UiTrack>[],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.source = '曲目',
    this.audioDevice,
    this.audioDevices = const <AudioDeviceInfo>[],
    this.audioParams,
    this.audioBitrate,
    this.shuffle = false,
    this.repeatMode = PlaybackRepeatMode.off,
  });

  rust.UiTrack? get current => queue.isEmpty ? null : queue[currentIndex];

  /// copyWith 的"未传参"哨兵:用于区分"没传这个参数"与"显式传入 null"。
  /// audioDevice / audioParams / audioBitrate 允许为 null,引擎清空时
  /// 必须能把旧值清掉,否则会继续显示上一首的码率/参数。
  static const Object _unset = Object();

  PlayerState copyWith({
    List<rust.UiTrack>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    String? source,
    Object? audioDevice = _unset,
    List<AudioDeviceInfo>? audioDevices,
    Object? audioParams = _unset,
    Object? audioBitrate = _unset,
    bool? shuffle,
    PlaybackRepeatMode? repeatMode,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      source: source ?? this.source,
      audioDevice: identical(audioDevice, _unset)
          ? this.audioDevice
          : audioDevice as AudioDeviceInfo?,
      audioDevices: audioDevices ?? this.audioDevices,
      audioParams: identical(audioParams, _unset)
          ? this.audioParams
          : audioParams as AudioParamsInfo?,
      audioBitrate: identical(audioBitrate, _unset)
          ? this.audioBitrate
          : audioBitrate as double?,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}

/// 重复模式:off=顺序播完即停, single=单曲循环, all=列表循环
enum PlaybackRepeatMode { off, single, all }

class PlayerNotifier extends Notifier<PlayerState> {
  //真实播放后端(Linux 首发为 media_kit)。只通过这一层拼口驱动,不直接碰引擎。
  late final PlaybackBackend _backend;

  /// 播放会话统计
  late final PlaybackSessionTracker _sessionTracker;
  final List<StreamSubscription> _subs = [];

  /// 随机播放选曲用
  final Random _random = Random();

  /// 引擎里是否已装载当前曲目。启动恢复时只恢复队列与进度,
  /// 首次播放/seek 时再懒加载,避免启动就占用音频设备。
  bool _mediaLoaded = false;

  /// 尚未交给引擎的恢复进度
  Duration _pendingPosition = Duration.zero;

  /// 防止恢复时连点播放触发多次装载
  bool _loadingMedia = false;

  bool _savingQueue = false;
  bool _queueSavePending = false;
  bool _savingState = false;
  bool _stateSavePending = false;

  /// 最近一次落盘的队列指纹,避免同一队列(如整库)每次点歌都重写大文件
  int? _lastSavedQueueSignature;

  @override
  PlayerState build() {
    _backend = createPlaybackBackend();
    _sessionTracker = PlaybackSessionTracker(
      // 直接从持久化设置读取当前音乐库目录,启动恢复时也不会拿到空 sourceId
      sourceId: () =>
          ref.read(sharedPreferencesProvider).getString(kMusicDirectoryKey) ??
          '',
      queueSource: () => state.source,
      onEvent: _recordPlayEvent,
    );

    // 订阅真实引擎的状态/进度流,彻底取代之前每秒跳一次的假 Timer
    _subs.add(_backend.positionStream.listen(_onPosition));
    _subs.add(_backend.durationStream.listen(_onDuration));
    _subs.add(_backend.playingStream.listen(_onPlaying));
    // 播完按重复模式处理:单曲循环重播当前曲,列表循环回到开头,
    // 顺序播放到最后一首则停在末尾,不再无条件 next(否则永远停不下来)。
    _subs.add(_backend.completedStream.listen((_) => _onCompleted()));
    // 设备/输出:当前渲染器、可用设备、声道参数
    _subs.add(
      _backend.audioDeviceStream.listen((d) {
        state = state.copyWith(audioDevice: d);
      }),
    );
    _subs.add(
      _backend.audioDevicesStream.listen((l) {
        state = state.copyWith(audioDevices: l);
      }),
    );
    _subs.add(
      _backend.audioParamsStream.listen((p) {
        state = state.copyWith(audioParams: p);
      }),
    );
    _subs.add(
      _backend.audioBitrateStream.listen((b) {
        state = state.copyWith(audioBitrate: b);
      }),
    );

    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
      _subs.clear();
      _backend.dispose();
    });

    // 启动恢复:有上次播放快照则恢复队列/当前曲/进度/模式,但保持暂停。
    // 引擎先不装载,首次播放时再由 _loadPendingAndPlay 懒加载。
    final snapshot = ref.read(initialPlaybackSnapshotProvider);
    if (snapshot != null && snapshot.queue.isNotEmpty) {
      final idx = snapshot.currentIndex.clamp(0, snapshot.queue.length - 1);
      final track = snapshot.queue[idx];
      _mediaLoaded = false;
      _pendingPosition = Duration.zero;
      _lastSavedQueueSignature = _queueSignature(snapshot.queue);
      return PlayerState(
        queue: snapshot.queue,
        currentIndex: idx,
        isPlaying: false,
        duration: _durationOf(track),
        source: snapshot.source,
        shuffle: snapshot.shuffle,
        repeatMode: _repeatModeFromName(snapshot.repeatMode),
      );
    }

    return const PlayerState(queue: [], isPlaying: false);
  }

  void _onPosition(Duration p) {
    if (state.queue.isEmpty) return; //空态不推进展示
    final total = state.duration;
    final clamped = (total > Duration.zero && p > total) ? total : p;
    state = state.copyWith(position: clamped);
    _sessionTracker.onPosition(clamped);
  }

  void _onDuration(Duration d) {
    state = state.copyWith(duration: d);
  }

  void _onPlaying(bool on) {
    state = state.copyWith(isPlaying: on);
    _sessionTracker.onPlaying(on);
  }

  /// 播放会话达到阈值后写入 Rust 统计库
  void _recordPlayEvent(PlaySessionEvent event) {
    unawaited(() async {
      try {
        await ref.read(playbackStatsServiceProvider).record(event);
        ref.read(statsRevisionProvider.notifier).bump();
      } catch (e) {
        debugPrint('记录播放事件失败: $e');
      }
    }());
  }

  //播放/暂停切换:由真实引擎的实际状态决定,不再本地假翻
  Future<void> toggle() async {
    if (state.queue.isEmpty) return;
    if (state.isPlaying) {
      await _backend.pause();
      return;
    }
    // 启动恢复的队列尚未装载:先懒加载到上次进度再播放
    if (!_mediaLoaded) {
      await _loadPendingAndPlay();
      return;
    }
    // 顺序播完停在末尾后再次点播放:从头开始,而不是原地停在 EOF
    if (state.duration > Duration.zero && state.position >= state.duration) {
      await _backend.seek(Duration.zero);
      _pendingPosition = Duration.zero;
    }
    await _backend.play();
  }

  //供外部(如 MPRIS)强制暂停
  Future<void> pause() async {
    if (state.queue.isEmpty || !_mediaLoaded) return;
    await _backend.pause();
  }

  //切换音频输出设备
  Future<void> setAudioDevice(String id) => _backend.setAudioDevice(id);

  //供外部恢复播放(已播放则为空操作)
  Future<void> resume() async {
    if (state.queue.isEmpty) return;
    if (!_mediaLoaded) {
      await _loadPendingAndPlay();
      return;
    }
    await _backend.play();
  }

  /// 恢复后首次播放:先把当前曲目以暂停状态装载,seek 到首次播放位置后再播放。
  /// 先 open(play:false) 再 seek,避免从曲首先响一下再跳转。
  Future<void> _loadPendingAndPlay() async {
    if (_loadingMedia) return;
    final track = state.current;
    if (track == null) return;

    _loadingMedia = true;
    try {
      final savedPosition = _pendingPosition;
      await _backend.open(_trackOf(track), play: false);
      _mediaLoaded = true;

      // 上次停在结尾(顺序播完)时,本次播放从头开始
      var resumeAt = savedPosition;
      final total = state.duration;
      if (total > Duration.zero && resumeAt >= total) {
        resumeAt = Duration.zero;
      }

      if (resumeAt > Duration.zero) {
        await _backend.seek(resumeAt);
      }
      state = state.copyWith(
        position: resumeAt,
        duration: state.duration > Duration.zero
            ? state.duration
            : _durationOf(track),
      );
      // 真正开始播放时才开启统计会话(懒加载恢复不算播放)
      _sessionTracker.onTrackChanged(track);
      _sessionTracker.onSeek(resumeAt);
      await _backend.play();
      _pendingPosition = Duration.zero;
    } finally {
      _loadingMedia = false;
    }
  }

  //播放队列中指定曲目,同时记录来源
  void play(int index, {String? source}) {
    final queue = state.queue;
    if (queue.isEmpty) return;
    final idx = (index + queue.length) % queue.length;
    _openAndPlay(idx, source ?? state.source);
  }

  //用真实扫描到的曲目整体替换队列并从 startIndex 开始播放
  //shuffle 传 null 时保持当前随机状态,传值则同时切换随机模式
  void load(
    List<rust.UiTrack> tracks,
    int startIndex, {
    String? source,
    bool? shuffle,
  }) {
    if (tracks.isEmpty) return;
    final idx = (startIndex + tracks.length) % tracks.length;
    state = state.copyWith(
      queue: List<rust.UiTrack>.of(tracks),
      currentIndex: idx,
      isPlaying: true,
      position: Duration.zero,
      duration: _durationOf(tracks[idx]),
      source: source ?? state.source,
      shuffle: shuffle,
      // 换曲先清空上一首的音频参数/码率,等新曲的引擎数据到达再填充,
      // 避免面板短暂显示上一首的信息。
      audioParams: null,
      audioBitrate: null,
    );
    _mediaLoaded = true;
    _pendingPosition = Duration.zero;
    _sessionTracker.onTrackChanged(tracks[idx]);
    _backend.open(_trackOf(tracks[idx]));
    // 队列内容变化才写队列文件;状态文件另写
    unawaited(_saveQueue());
    unawaited(_saveState());
  }

  //以给定曲目为队列顺序播放(重置随机模式)
  void playSequential(List<rust.UiTrack> tracks, {String? source}) {
    if (tracks.isEmpty) return;
    load(tracks, 0, source: source, shuffle: false);
  }

  //以给定曲目为队列随机播放:随机起点,之后 next/播完都随机选曲
  void playShuffled(List<rust.UiTrack> tracks, {String? source}) {
    if (tracks.isEmpty) return;
    load(tracks, _random.nextInt(tracks.length), source: source, shuffle: true);
  }

  void _openAndPlay(int idx, String source) {
    final track = state.queue[idx];
    state = state.copyWith(
      currentIndex: idx,
      isPlaying: true,
      position: Duration.zero,
      duration: _durationOf(track),
      source: source,
      // 同上:换曲时清掉旧曲的音频参数/码率
      audioParams: null,
      audioBitrate: null,
    );
    _mediaLoaded = true;
    _pendingPosition = Duration.zero;
    _sessionTracker.onTrackChanged(track);
    _backend.open(_trackOf(track));
    unawaited(_saveState());
  }

  //由曲目拼出 PlaybackTrack:path 转 file:// URI,时长先用元数据粗值兜底
  PlaybackTrack _trackOf(rust.UiTrack t) {
    final uri = t.path.isEmpty ? t.id : Uri.file(t.path).toString();
    return PlaybackTrack(uri: uri, fallbackDuration: _durationOf(t));
  }

  //从解析的'03:24'时长文本转成 Duration,失败则用整曲默认值
  static Duration _durationOf(rust.UiTrack t) {
    final parts = t.duration.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]);
      final s = int.tryParse(parts[1]);
      if (m != null && s != null) return Duration(minutes: m, seconds: s);
    }
    return const Duration(seconds: 0);
  }

  //拖拽进度条定位:只改位置并同步给真实引擎 seek,不改变播放状态。
  //isPlaying 完全由引擎的 playingStream 驱动,避免"暂停时拖条被误判为播放"导致按钮状态失真。
  void seek(Duration position) {
    final total = state.duration.inMilliseconds;
    final ms = position.inMilliseconds.clamp(0, total > 0 ? total : 0);
    final target = Duration(milliseconds: ms);
    state = state.copyWith(position: target);
    _sessionTracker.onSeek(target);

    if (!_mediaLoaded) {
      // 引擎尚未装载:只记录首次播放时的起播位置
      _pendingPosition = target;
      return;
    }
    _backend.seek(target);
  }

  //手动"下一首":随机模式下随机选曲(避开当前曲),否则顺序下一首并首尾循环。
  //手动切歌不受 repeatMode 影响,始终有下一首。
  void next() {
    if (state.queue.isEmpty) return;
    if (state.shuffle && state.queue.length > 1) {
      play(_randomIndexExcludingCurrent());
      return;
    }
    play(state.currentIndex + 1);
  }

  //单曲播放完成:按 repeatMode 决定重播当前曲 / 下一首 / 停在末尾
  void _onCompleted() {
    if (state.queue.isEmpty) return;
    // 先结算本次播放(完成态),后面若继续切歌会重新开会话
    _sessionTracker.onCompleted();

    // 单曲循环:原位从头重播,不重新装载文件
    if (state.repeatMode == PlaybackRepeatMode.single) {
      _replayCurrent();
      return;
    }

    // 随机模式:继续随机选下一首
    if (state.shuffle && state.queue.length > 1) {
      play(_randomIndexExcludingCurrent());
      return;
    }

    // 顺序模式:还没到最后一首就继续往后
    if (state.currentIndex < state.queue.length - 1) {
      play(state.currentIndex + 1);
      return;
    }

    // 已到最后一首:列表循环回到开头;off 则停在末尾(引擎已停止)
    if (state.repeatMode == PlaybackRepeatMode.all) {
      play(0);
      return;
    }
    state = state.copyWith(position: state.duration);
  }

  //随机选一个不同于当前曲目的索引
  int _randomIndexExcludingCurrent() {
    var idx = _random.nextInt(state.queue.length);
    if (idx == state.currentIndex) {
      idx = (idx + 1) % state.queue.length;
    }
    return idx;
  }

  //单曲循环:seek 回 0 再播,避免重新 open 整个文件
  void _replayCurrent() {
    _sessionTracker.onTrackChanged(state.current);
    state = state.copyWith(position: Duration.zero, isPlaying: true);
    _backend.seek(Duration.zero);
    _backend.play();
  }

  //上一首
  void prev() => play(state.currentIndex - 1);

  //随机播放开关
  void toggleShuffle() {
    state = state.copyWith(shuffle: !state.shuffle);
    unawaited(_saveState());
  }

  //重复模式轮换: 顺序 -> 单曲 -> 列表 -> 顺序
  void cycleRepeat() {
    final next = switch (state.repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.single,
      PlaybackRepeatMode.single => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
    unawaited(_saveState());
  }

  /// 从持久化的 name 还原重复模式
  static PlaybackRepeatMode _repeatModeFromName(String name) {
    return PlaybackRepeatMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => PlaybackRepeatMode.off,
    );
  }

  /// 只写小状态文件(索引/当前曲 id/来源/模式),不记录播放进度
  Future<void> _saveState() async {
    if (state.queue.isEmpty) return;
    if (_savingState) {
      _stateSavePending = true;
      return;
    }
    final current = state.current;
    final snapshot = PlaybackStateSnapshot(
      currentIndex: state.currentIndex,
      currentTrackId: current?.id,
      source: state.source,
      shuffle: state.shuffle,
      repeatMode: state.repeatMode.name,
    );
    _savingState = true;
    try {
      await ref.read(playbackSnapshotStoreProvider).saveState(snapshot);
    } finally {
      _savingState = false;
      // 写入期间状态又变了:补写一次最新状态
      if (_stateSavePending) {
        _stateSavePending = false;
        unawaited(_saveState());
      }
    }
  }

  /// 队列文件可能较大,只在队列内容变化时写
  Future<void> _saveQueue() async {
    if (state.queue.isEmpty) return;
    if (_savingQueue) {
      _queueSavePending = true;
      return;
    }
    final queue = state.queue;
    final signature = _queueSignature(queue);
    if (signature == _lastSavedQueueSignature) return;

    _savingQueue = true;
    try {
      await ref.read(playbackSnapshotStoreProvider).saveQueue(queue);
      _lastSavedQueueSignature = signature;
    } finally {
      _savingQueue = false;
      // 写入期间队列又变了:补写最新队列
      if (_queueSavePending) {
        _queueSavePending = false;
        unawaited(_saveQueue());
      }
    }
  }

  /// 队列指纹:按曲目 id 顺序哈希。整库点歌时队列不变,可跳过重复写盘。
  static int _queueSignature(List<rust.UiTrack> queue) =>
      Object.hashAll(queue.map((t) => t.id));
}

//全局播放状态
final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

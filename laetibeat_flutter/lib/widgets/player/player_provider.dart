import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'playback_backend.dart';

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

  PlayerState copyWith({
    List<rust.UiTrack>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    String? source,
    AudioDeviceInfo? audioDevice,
    List<AudioDeviceInfo>? audioDevices,
    AudioParamsInfo? audioParams,
    double? audioBitrate,
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
      audioDevice: audioDevice ?? this.audioDevice,
      audioDevices: audioDevices ?? this.audioDevices,
      audioParams: audioParams ?? this.audioParams,
      audioBitrate: audioBitrate ?? this.audioBitrate,
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
  final List<StreamSubscription> _subs = [];

  @override
  PlayerState build() {
    _backend = createPlaybackBackend();

    // 订阅真实引擎的状态/进度流,彻底取代之前每秒跳一次的假 Timer
    _subs.add(_backend.positionStream.listen(_onPosition));
    _subs.add(_backend.durationStream.listen(_onDuration));
    _subs.add(_backend.playingStream.listen(_onPlaying));
    _subs.add(_backend.completedStream.listen((_) => next())); //播完自动切下一首
    // 设备/输出:当前渲染器、可用设备、声道参数
    _subs.add(_backend.audioDeviceStream.listen((d) {
      state = state.copyWith(audioDevice: d);
    }));
    _subs.add(_backend.audioDevicesStream.listen((l) {
      state = state.copyWith(audioDevices: l);
    }));
    _subs.add(_backend.audioParamsStream.listen((p) {
      state = state.copyWith(audioParams: p);
    }));
    _subs.add(_backend.audioBitrateStream.listen((b) {
      state = state.copyWith(audioBitrate: b);
    }));

    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
      _subs.clear();
      _backend.dispose();
    });

    return const PlayerState(queue: [], isPlaying: false);
  }

  void _onPosition(Duration p) {
    if (state.queue.isEmpty) return; //空态不推进展示
    final total = state.duration;
    final clamped = (total > Duration.zero && p > total) ? total : p;
    state = state.copyWith(position: clamped);
  }

  void _onDuration(Duration d) {
    state = state.copyWith(duration: d);
  }

  void _onPlaying(bool on) {
    state = state.copyWith(isPlaying: on);
  }

  //播放/暂停切换:由真实引擎的实际状态决定,不再本地假翻
  Future<void> toggle() async {
    if (state.queue.isEmpty) return;
    if (state.isPlaying) {
      await _backend.pause();
    } else {
      await _backend.play();
    }
  }

  //供外部(如 MPRIS)强制暂停
  Future<void> pause() async {
    if (state.queue.isEmpty) return;
    await _backend.pause();
  }

  //切换音频输出设备
  Future<void> setAudioDevice(String id) => _backend.setAudioDevice(id);

  //供外部恢复播放(已播放则为空操作)
  Future<void> resume() async {
    if (state.queue.isEmpty) return;
    await _backend.play();
  }

  //播放队列中指定曲目,同时记录来源
  void play(int index, {String? source}) {
    final queue = state.queue;
    if (queue.isEmpty) return;
    final idx = (index + queue.length) % queue.length;
    _openAndPlay(idx, source ?? state.source);
  }

  //用真实扫描到的曲目整体替换队列并从 startIndex 开始播放
  void load(List<rust.UiTrack> tracks, int startIndex, {String? source}) {
    if (tracks.isEmpty) return;
    final idx = (startIndex + tracks.length) % tracks.length;
    state = state.copyWith(
      queue: List<rust.UiTrack>.of(tracks),
      currentIndex: idx,
      isPlaying: true,
      position: Duration.zero,
      duration: _durationOf(tracks[idx]),
      source: source ?? state.source,
    );
    _backend.open(_trackOf(tracks[idx]));
  }

  void _openAndPlay(int idx, String source) {
    final track = state.queue[idx];
    state = state.copyWith(
      currentIndex: idx,
      isPlaying: true,
      position: Duration.zero,
      duration: _durationOf(track),
      source: source,
    );
    _backend.open(_trackOf(track));
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
    state = state.copyWith(position: Duration(milliseconds: ms));
    _backend.seek(Duration(milliseconds: ms));
  }

  //下一首
  void next() => play(state.currentIndex + 1);

  //上一首
  void prev() => play(state.currentIndex - 1);

  //随机播放开关
  void toggleShuffle() =>
      state = state.copyWith(shuffle: !state.shuffle);

  //重复模式轮换: 顺序 -> 单曲 -> 列表 -> 顺序
  void cycleRepeat() {
    final next = switch (state.repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.single,
      PlaybackRepeatMode.single => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
  }
}

//全局播放状态
final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);
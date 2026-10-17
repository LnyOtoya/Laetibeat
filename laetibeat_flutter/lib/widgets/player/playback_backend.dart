import 'dart:async';

import 'package:media_kit/media_kit.dart' as mk;

// ---------------------------------------------------------------------------
// 播放后端抽象
// ---------------------------------------------------------------------------
// 上层 player_provider / UI 只依赖 PlaybackBackend 这个拼口,不与具体引擎耦合。
// 这样"按平台各插各的后端"就能成立:
//   * Linux/桌面  -> MediaKitBackend(libmpv+FFmpeg, 本次首发)
//   * Android     -> 未来各自平插(Media3/just_audio+audio_service 等)
// 新增平台=新增一个 backend 实现,不动上层。

/// 交给后端播放的单条曲目
class PlaybackTrack {
  /// 可直接交给播放器加载的 URI(本地文件为 file:// 形式)
  final String uri;

  /// 从元数据粗读出的时长,用于引擎给出真实时长前的兜底展示
  final Duration fallbackDuration;

  const PlaybackTrack({required this.uri, this.fallbackDuration = Duration.zero});
}

/// 音频输出设备。id 为设备的唯一标识(name),name 为可读名称。
/// 独立于具体引擎(id/name),避免上层耦合 media_kit。
class AudioDeviceInfo {
  final String id;
  final String name;
  const AudioDeviceInfo(this.id, this.name);
}

/// 当前媒体的音频参数(声道/采样率/格式)。全部可空,引擎未给时上层自行兜底。
class AudioParamsInfo {
  final String? format;
  final int? sampleRate;
  final int? channelCount;
  const AudioParamsInfo({this.format, this.sampleRate, this.channelCount});
}

/// 播放后端最低能力集合
abstract class PlaybackBackend {
  /// 播放进度流(毫秒级实时)
  Stream<Duration> get positionStream;

  /// 真实时长流(引擎解析媒体后发出)
  Stream<Duration> get durationStream;

  /// 播放/暂停状态流
  Stream<bool> get playingStream;

  /// 单曲播完事件流(用于自动切下一首)
  Stream<void> get completedStream;

  /// 当前音频输出设备流(切换/被系统改用时通知)
  Stream<AudioDeviceInfo> get audioDeviceStream;

  /// 当前可用音频设备列表流(插拔/后端起播后更新)
  Stream<List<AudioDeviceInfo>> get audioDevicesStream;

  /// 当前媒体音频参数流(声道/采样率/格式)
  Stream<AudioParamsInfo> get audioParamsStream;

  /// 当前媒体音频码率流(Kbps,引擎未解析时为 null)
  Stream<double?> get audioBitrateStream;

  /// 切换音频输出设备(id 即设备的唯一标识)
  Future<void> setAudioDevice(String id);

  /// 装载一首曲目。[play] 为 false 时只加载不播放(用于恢复上次进度)。
  Future<void> open(PlaybackTrack track, {bool play = true});

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> stop();

  Future<void> dispose();
}

/// 选择当前平台要用的后端。这是"换后端"的唯一入口。
PlaybackBackend createPlaybackBackend() => MediaKitBackend();

// ---------------------------------------------------------------------------
// media_kit 实现(Linux/桌面首发)
// ---------------------------------------------------------------------------

/// media_kit(libmpv + FFmpeg)后端
class MediaKitBackend implements PlaybackBackend {
  MediaKitBackend() {
    // 幂等:只在首次真正初始化原生引擎
    mk.MediaKit.ensureInitialized();
  }

  late final mk.Player _player = mk.Player();

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get durationStream =>
      _player.stream.duration.where((d) => d > Duration.zero);

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<void> get completedStream =>
      _player.stream.completed.where((done) => done).map((_) {});

  @override
  Stream<AudioDeviceInfo> get audioDeviceStream => _player.stream.audioDevice
      .map((d) => AudioDeviceInfo(d.name, d.description));

  @override
  Stream<List<AudioDeviceInfo>> get audioDevicesStream => _player.stream
      .audioDevices
      .map((list) => list.map((d) => AudioDeviceInfo(d.name, d.description)).toList());

  @override
  Stream<AudioParamsInfo> get audioParamsStream =>
      _player.stream.audioParams.map(
        (p) => AudioParamsInfo(
          format: p.format,
          sampleRate: p.sampleRate,
          channelCount: p.channelCount,
        ),
      );

  @override
  Stream<double?> get audioBitrateStream => _player.stream.audioBitrate;

  @override
  Future<void> setAudioDevice(String id) =>
      _player.setAudioDevice(mk.AudioDevice(id, ''));

  @override
  Future<void> open(PlaybackTrack track, {bool play = true}) async {
    await _player.open(mk.Media(track.uri), play: play);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
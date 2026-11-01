import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';

/// 把现有 PlayerNotifier 桥接到 Android 媒体服务和常驻通知。
class LaetibeatAudioHandler extends BaseAudioHandler {
  LaetibeatAudioHandler(this._container) {
    _subscription = _container.listen<PlayerState>(
      playerProvider,
      (PlayerState? previous, PlayerState next) => _sync(next),
      fireImmediately: true,
    );
  }

  final ProviderContainer _container;
  ProviderSubscription<PlayerState>? _subscription;

  String? _lastTrackId;
  String? _lastQueueSignature;
  String? _lastPlaybackKey;
  DateTime _lastPositionBroadcast = DateTime.fromMillisecondsSinceEpoch(0);

  PlayerNotifier get _player => _container.read(playerProvider.notifier);

  void _sync(PlayerState state) {
    final track = state.current;

    if (track?.id != _lastTrackId) {
      _lastTrackId = track?.id;
      if (track == null) {
        mediaItem.add(null);
      } else {
        mediaItem.add(_mediaItemFor(track, state.duration));
        unawaited(_updateArtwork(track, state.duration));
      }
    }

    final queueSignature = state.queue
        .map((rust.UiTrack track) => track.id)
        .join('\u0000');
    if (queueSignature != _lastQueueSignature) {
      _lastQueueSignature = queueSignature;
      queue.add(
        state.queue
            .map(
              (rust.UiTrack track) => _mediaItemFor(
                track,
                track.id == state.current?.id ? state.duration : null,
              ),
            )
            .toList(growable: false),
      );
    }

    final playbackKey = [
      track?.id ?? '',
      state.isPlaying,
      state.duration.inMilliseconds,
      state.currentIndex,
      state.shuffle,
      state.repeatMode.name,
    ].join('\u0000');
    final now = DateTime.now();
    final positionChanged =
        now.difference(_lastPositionBroadcast) >= const Duration(seconds: 1);
    if (playbackKey != _lastPlaybackKey || positionChanged) {
      _lastPlaybackKey = playbackKey;
      _lastPositionBroadcast = now;
      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.skipToPrevious,
            state.isPlaying ? MediaControl.pause : MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const <MediaAction>{
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const <int>[0, 1, 2],
          processingState: track == null
              ? AudioProcessingState.idle
              : AudioProcessingState.ready,
          playing: state.isPlaying,
          updatePosition: state.position,
          bufferedPosition: state.position,
          speed: 1.0,
          queueIndex: state.queue.isEmpty ? null : state.currentIndex,
          repeatMode: _repeatMode(state.repeatMode),
          shuffleMode: state.shuffle
              ? AudioServiceShuffleMode.all
              : AudioServiceShuffleMode.none,
        ),
      );
    }
  }

  MediaItem _mediaItemFor(
    rust.UiTrack track,
    Duration? engineDuration, {
    Uri? artUri,
  }) {
    final fallback = _durationOf(track);
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: engineDuration != null && engineDuration > Duration.zero
          ? engineDuration
          : fallback,
      artUri: artUri,
      extras: <String, Object?>{
        'source': track.source,
        'sourceId': track.sourceId,
      },
    );
  }

  Future<void> _updateArtwork(rust.UiTrack track, Duration duration) async {
    try {
      final bytes = await _container.read(trackCoverProvider(track).future);
      if (bytes == null || bytes.isEmpty) return;

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/laetibeat_audio_art_${track.id.hashCode}.img',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (_lastTrackId != track.id) return;
      mediaItem.add(_mediaItemFor(track, duration, artUri: file.uri));
    } catch (_) {
      // 封面失败不影响播放与通知。
    }
  }

  static Duration _durationOf(rust.UiTrack track) {
    final parts = track.duration.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]);
      final seconds = int.tryParse(parts[1]);
      if (minutes != null && seconds != null) {
        return Duration(minutes: minutes, seconds: seconds);
      }
    }
    return Duration.zero;
  }

  static AudioServiceRepeatMode _repeatMode(PlaybackRepeatMode mode) {
    return switch (mode) {
      PlaybackRepeatMode.off => AudioServiceRepeatMode.none,
      PlaybackRepeatMode.single => AudioServiceRepeatMode.one,
      PlaybackRepeatMode.all => AudioServiceRepeatMode.all,
    };
  }

  @override
  Future<void> play() async {
    await _player.resume();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    _player.next();
  }

  @override
  Future<void> skipToPrevious() async {
    _player.prev();
  }

  @override
  Future<void> fastForward() async {
    final position = _container.read(playerProvider).position;
    _player.seek(position + const Duration(seconds: 10));
  }

  @override
  Future<void> rewind() async {
    final position = _container.read(playerProvider).position;
    _player.seek(position - const Duration(seconds: 10));
  }

  Future<void> disposeHandler() async {
    _subscription?.close();
  }
}

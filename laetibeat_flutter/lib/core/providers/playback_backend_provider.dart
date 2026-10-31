import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/player/playback_backend.dart';

/// 播放后端由 bootstrap 按平台注入，播放状态层不再直接 new 具体引擎。
final playbackBackendProvider = Provider<PlaybackBackend>((ref) {
  throw UnimplementedError(
    'playbackBackendProvider 必须在 bootstrap 中注入',
  );
});

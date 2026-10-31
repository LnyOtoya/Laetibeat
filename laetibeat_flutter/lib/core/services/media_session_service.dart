import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 系统媒体集成（桌面 MPRIS / Android MediaSession）的统一抽象。
///
/// 当前 MPRIS 仍处于停用状态，因此默认使用 Noop 实现。
/// 后续接入 audio_service 或修复 MPRIS 时，只需在 bootstrap 中替换实现。
abstract interface class MediaSessionService {
  void sync();

  Future<void> dispose();
}

class NoopMediaSessionService implements MediaSessionService {
  const NoopMediaSessionService();

  @override
  void sync() {}

  @override
  Future<void> dispose() async {}
}

final mediaSessionServiceProvider = Provider<MediaSessionService>((ref) {
  return const NoopMediaSessionService();
});

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/core/services/media_session_service.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';

/// 把全局播放状态桥接到系统媒体集成。
///
/// 具体集成由 bootstrap 注入的 [MediaSessionService] 决定：
/// 桌面端可以是 MPRIS，移动端可以是 audio_service / MediaSession。
/// 这里不再出现任何平台判断。
class MediaIntegrationHost extends ConsumerWidget {
  const MediaIntegrationHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(mediaSessionServiceProvider);

    // 只在真正关心的字段变化时同步，避免 position 每 tick 触发高频刷新。
    ref.listen(
      playerProvider.select((s) => (s.current?.id, s.isPlaying, s.duration)),
      (prev, next) => service.sync(),
    );

    return child;
  }
}

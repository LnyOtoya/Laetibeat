import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/widgets/integration/linux_mpris.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';

/// 把全局播放状态桥接到各平台"媒体集成"。
///
/// 当前实现 Linux MPRIS;Windows/Android 的 SMTC / MediaSession 未来
/// 在此平挂即可,互不影响。作为包裹在 ProviderScope 内的常驻宿主使用。
class MediaIntegrationHost extends ConsumerStatefulWidget {
  final Widget child;

  const MediaIntegrationHost({super.key, required this.child});

  @override
  ConsumerState<MediaIntegrationHost> createState() =>
      _MediaIntegrationHostState();
}

class _MediaIntegrationHostState extends ConsumerState<MediaIntegrationHost> {
  LinuxMprisIntegration? _mpris;
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    // 播放状态一旦变化就向 MPRIS 推送(合并信号,不逐帧高频推送)
    ref.listen(playerProvider, (prev, next) {
      _mpris?.push();
    });
    _maybeStart();
    return widget.child;
  }

  void _maybeStart() {
    if (_started) return;
    _started = true;
    _mpris = LinuxMprisIntegration(
      readState: () => ref.read(playerProvider),
      onPlay: () => ref.read(playerProvider.notifier).resume(),
      onPause: () => ref.read(playerProvider.notifier).pause(),
      onNext: () => ref.read(playerProvider.notifier).next(),
      onPrevious: () => ref.read(playerProvider.notifier).prev(),
      onSeek: (d) => ref.read(playerProvider.notifier).seek(d),
    );
    // 无 D-Bus 会话时内部静默降级,不炸应用
    _mpris!.start();
  }

  @override
  void dispose() {
    _mpris?.stop();
    super.dispose();
  }
}
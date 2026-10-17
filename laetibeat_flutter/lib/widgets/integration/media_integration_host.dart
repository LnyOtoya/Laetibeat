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

  @override
  Widget build(BuildContext context) {
    // 仅在 MPRIS 真正关心的字段(当前曲目/播放状态/时长)变化时才推送,
    // 避免播放进度 position 每次 tick(~12 次/秒)都触发 PropertiesChanged
    // 高频信号风暴:position 属轮询型,由客户端自行查询,不作变更信号。
    ref.listen(
      playerProvider.select((s) => (s.current?.id, s.isPlaying, s.duration)),
      (prev, next) => _mpris?.push(),
    );
    _maybeStart();
    return widget.child;
  }

  void _maybeStart() {
    // TODO(mpris): 自研 D-Bus 服务端(linux_mpris.dart)在启动时会卡死 waybar,
    // 且已证明难以修复。临时停用;待接入移动端后台播放时,统一改用
    // audio_service + audio_service_mpris 替换整层后再启用。
    return;
    // if (_started) return;
    // _mpris = LinuxMprisIntegration(
    //   readState: () => ref.read(playerProvider),
    //   onPlay: () => ref.read(playerProvider.notifier).resume(),
    //   onPause: () => ref.read(playerProvider.notifier).pause(),
    //   onNext: () => ref.read(playerProvider.notifier).next(),
    //   onPrevious: () => ref.read(playerProvider.notifier).prev(),
    //   onSeek: (d) => ref.read(playerProvider.notifier).seek(d),
    // );
    // // 无 D-Bus 会话时内部静默降级,不炸应用
    // _mpris!.start();
  }

  @override
  void dispose() {
    _mpris?.stop();
    super.dispose();
  }
}
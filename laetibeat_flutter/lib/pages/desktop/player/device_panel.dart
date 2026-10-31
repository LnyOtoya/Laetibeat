import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../../../animations.dart';
import '../../../widgets/player/playback_backend.dart';
import '../../../widgets/player/player_provider.dart';

/// 设备 / 输出面板 —— 挂在右侧内容区底部、播放面板之下。
///
/// 保持小清单样式:标题 + 右上角"当前输出设备"按钮,点按钮用 bottom sheet 弹出
/// 可用设备列表选择;下方内容区只展示当前媒体的声道 / 采样率 / 码率等信息。
class DevicePanel extends ConsumerWidget {
  const DevicePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final current = player.audioDevice;

    return AnimatedContainer(
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      // 固定高度(而非 minHeight):内部 Expanded 需要有界的竖直约束,
      // 若只设 min 会在一段无界高度的父级里崩掉(184..∞)
      height: 216,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(theme.spacing.md),
      ),
      padding: EdgeInsets.all(theme.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题行:标题(左上,放大) + 输出设备按钮(右侧同排)
          Row(
            children: [
              Expanded(
                child: Text(
                  '设备 / 输出',
                  style: theme.typeScale.titleLarge.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              M3EButton(
                style: M3EButtonStyle.tonal,
                size: M3EButtonSize.md,
                icon: const Icon(Icons.speaker, size: 20),
                label: Text(current?.name ?? '自动'),
                onPressed: () => _pickDevice(context, ref),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          // 信息行:垂直铺满面板余下空间,控件放大匹配面板
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _infoRows(theme, scheme, player),
            ),
          ),
        ],
      ),
    );
  }

  // 音频信息行。只用 media_kit 暴露的字段;某行无数据则跳过,不占位。
  List<Widget> _infoRows(
    M3EThemeData theme,
    M3EColorScheme scheme,
    PlayerState player,
  ) {
    final rows = <(IconData, String)>[];
    final p = player.audioParams;

    // 行1:采样率 · 声道
    final rate = p?.sampleRate;
    final ch = p?.channelCount;
    if (rate != null && rate > 0) {
      final rateTxt =
          rate >= 1000 ? '${(rate / 1000).toStringAsFixed(1)} kHz' : '$rate Hz';
      rows.add((
        Icons.tune,
        ch != null && ch > 0 ? '$rateTxt · $ch 声道' : rateTxt,
      ));
    }
    // 行2:码率 · 输出采样格式(位深近似)
    final br = player.audioBitrate;
    final fmt = p?.format;
    if (br != null && br > 0) {
      final bitTxt = '${br.round()} kbps';
      rows.add((
        Icons.graphic_eq,
        fmt != null && fmt.isNotEmpty ? '$bitTxt · ${_bitDepth(fmt)}' : bitTxt,
      ));
    } else if (fmt != null && fmt.isNotEmpty) {
      rows.add((Icons.graphic_eq, _bitDepth(fmt)));
    }

    // 行间留缝 + 每行 icon+文字(放大)
    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i == 0) SizedBox(height: theme.spacing.sm),
        _infoRow(theme, scheme, rows[i].$1, rows[i].$2),
        if (i < rows.length - 1) SizedBox(height: theme.spacing.sm),
      ],
    ];
  }

  Widget _infoRow(
    M3EThemeData theme,
    M3EColorScheme scheme,
    IconData icon,
    String text,
  ) {
    return Row(
      children: [
        Icon(icon, size: 24, color: scheme.onSurfaceVariant),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.typeScale.bodyLarge.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // 输出采样格式字符串 → 更可读的位深/类型。mpv 的 audio-params.format 名。
  String _bitDepth(String format) {
    final f = format.toLowerCase();
    if (f.contains('float') || f.contains('floatingpoint')) return '浮点';
    if (f.contains('24')) return '24 位';
    if (f.contains('32')) return '32 位';
    if (f.contains('16')) return '16 位';
    if (f.contains('8')) return '8 位';
    return format.toUpperCase();
  }

  // 弹出可用设备列表的 bottom sheet,选中即切换并关闭。紧凑高度,不占整屏。
  void _pickDevice(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerProvider);
    final devices = _physicalDevices(player.audioDevices);
    final theme = M3ETheme.of(context);
    if (devices.isEmpty) return;
    M3EBottomSheet.show<void>(
      context,
      builder: (sheetContext) {
        final scheme = M3ETheme.of(sheetContext).colorScheme;
        const double compactMax = 420.0;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: compactMax),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final d in devices)
                  M3EListItem(
                    selected: player.audioDevice?.id == d.id,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      ref.read(playerProvider.notifier).setAudioDevice(d.id);
                    },
                    leading: M3EShapeContainer.square(
                      width: theme.spacing.xxl,
                      height: theme.spacing.xxl,
                      color: player.audioDevice?.id == d.id
                          ? scheme.primaryContainer
                          : scheme.secondaryContainer,
                      child: Icon(
                        player.audioDevice?.id == d.id
                            ? Icons.volume_up
                            : Icons.volume_down,
                        size: 20,
                        color: player.audioDevice?.id == d.id
                            ? scheme.onPrimaryContainer
                            : null,
                      ),
                    ),
                    headline: d.name,
                    supportingText: d.id == 'auto' ? '自动选择' : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 收拢成"物理设备":避免 mpv 把声卡按声道布局/多命名空间重复列成几十条。
  // 优先取当前声音服务器(pipewire/pulse)的真实 sink;纯 ALSA 时按声卡(CARD)去重只留一个代表。
  List<AudioDeviceInfo> _physicalDevices(List<AudioDeviceInfo> all) {
    if (all.isEmpty) return all;
    final out = <AudioDeviceInfo>[];
    // 1. 默认项 "auto" 保留在最前
    for (final d in all) {
      if (d.id == 'auto') out.add(d);
    }
    // 2. 选真实 sink 集合,并去掉与"命名服务器"重复的条目
    final List<AudioDeviceInfo> server;
    if (all.any((d) => d.id.startsWith('pipewire/'))) {
      server = all.where((d) => d.id.startsWith('pipewire/')).toList();
    } else if (all.any((d) => d.id.startsWith('pulse/'))) {
      server = all.where((d) => d.id.startsWith('pulse/')).toList();
    } else {
      // 纯 ALSA:只收物理声卡条目(front/IEC958/HDMI 等含 CARD=),按 CARD 去重
      final alsa = all
          .where((d) => d.id.startsWith('alsa/') && d.id.contains('CARD='))
          .toList();
      final seen = <String>{};
      for (final d in alsa) {
        if (seen.add(_cardKey(d.id))) out.add(d);
      }
      return out;
    }
    out.addAll(server);
    return out;
  }

  // 提取 ALSA 设备名里的 CARD 身份,用于按声卡去重。
  // 形如 alsa/front:CARD=Amplif,DEV=0 -> 'Amplif'
  String _cardKey(String id) {
    final m = RegExp(r'CARD=([^,]+)').firstMatch(id);
    return m?.group(1) ?? id;
  }
}
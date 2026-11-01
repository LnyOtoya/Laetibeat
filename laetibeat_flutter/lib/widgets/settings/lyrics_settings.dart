import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistence.dart';

/// 歌词来源的稳定 ID。界面文案不要写进持久化值。
enum LyricsSourceId {
  /// 本地内嵌标签 / 外挂歌词，或远端服务器自己的默认歌词。
  tags,

  /// LRCLIB 网络歌词。
  lrclib,

  /// LiriQo 聚合歌词服务。
  liriqo,
}

const String kLyricsEnabledSourcesKey = 'lyrics.enabled_sources';
const String kLyricsSourceOrderKey = 'lyrics.source_order';

const Set<LyricsSourceId> _defaultEnabledLyricsSources = <LyricsSourceId>{
  LyricsSourceId.tags,
  LyricsSourceId.lrclib,
};

const List<LyricsSourceId> _defaultLyricsSourceOrder = <LyricsSourceId>[
  LyricsSourceId.tags,
  LyricsSourceId.lrclib,
  LyricsSourceId.liriqo,
];

class LyricsSettings {
  const LyricsSettings({required this.enabled, required this.order});

  final Set<LyricsSourceId> enabled;
  final List<LyricsSourceId> order;

  bool isEnabled(LyricsSourceId source) => enabled.contains(source);
}

LyricsSourceId? _sourceFromName(String? name) {
  if (name == null) return null;
  for (final source in LyricsSourceId.values) {
    if (source.name == name) return source;
  }
  return null;
}

List<LyricsSourceId> _normalizeOrder(Iterable<String>? values) {
  final result = <LyricsSourceId>[];
  for (final value in values ?? const <String>[]) {
    final source = _sourceFromName(value);
    if (source != null && !result.contains(source)) {
      result.add(source);
    }
  }
  for (final source in _defaultLyricsSourceOrder) {
    if (!result.contains(source)) result.add(source);
  }
  return result;
}

class LyricsSettingsNotifier extends Notifier<LyricsSettings> {
  @override
  LyricsSettings build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedEnabled = prefs.getStringList(kLyricsEnabledSourcesKey);
    final enabled = <LyricsSourceId>{};
    for (final value in savedEnabled ?? const <String>[]) {
      final source = _sourceFromName(value);
      if (source != null) enabled.add(source);
    }
    // LiriQo 作为可选源默认关闭；只有用户明确开启才参与回退链。
    if (enabled.isEmpty) {
      enabled.addAll(_defaultEnabledLyricsSources);
    }

    return LyricsSettings(
      enabled: enabled,
      order: _normalizeOrder(prefs.getStringList(kLyricsSourceOrderKey)),
    );
  }

  Future<void> setEnabled(Set<LyricsSourceId> enabled) async {
    if (enabled.isEmpty) return;
    final next = Set<LyricsSourceId>.of(enabled);
    if (next.length == state.enabled.length &&
        next.containsAll(state.enabled)) {
      return;
    }
    state = LyricsSettings(enabled: next, order: state.order);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(
          kLyricsEnabledSourcesKey,
          next.map((source) => source.name).toList(growable: false),
        );
  }

  Future<void> setOrder(List<LyricsSourceId> order) async {
    final next = _normalizeOrder(order.map((source) => source.name));
    if (_sameOrder(next, state.order)) return;
    state = LyricsSettings(enabled: state.enabled, order: next);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(
          kLyricsSourceOrderKey,
          next.map((source) => source.name).toList(growable: false),
        );
  }
}

bool _sameOrder(List<LyricsSourceId> a, List<LyricsSourceId> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

final lyricsSettingsProvider =
    NotifierProvider<LyricsSettingsNotifier, LyricsSettings>(
      LyricsSettingsNotifier.new,
    );

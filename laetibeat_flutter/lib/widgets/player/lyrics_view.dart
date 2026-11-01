import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../l10n/generated/app_localizations.dart';

import 'lyric_provider.dart';
import 'player_provider.dart';

/// 歌词渲染视图(可复用):供播放面板内联展示使用。
/// 同步歌词由 flutter_lyric 的 [LyricView] 渲染(Apple Music 预设);
/// 纯文本歌词保留静态滚动展示;加载/无歌词沿用原有占位。
/// 只负责"画歌词",不负责容器外壳与配色(由调用方提供)。
class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key});

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  late final LyricController _controller;
  late final _PlayerProgressSource _progress;

  /// 最近一次解析的原始文本/翻译与结果(结果为空表示按纯文本展示)。
  String? _parsedRaw;
  String? _parsedTranslation;
  LyricDocument? _parsedDoc;

  /// 已同步进 controller 的原始文本与翻译。
  String? _loadedRaw;
  String? _loadedTranslation;

  @override
  void initState() {
    super.initState();
    _progress = _PlayerProgressSource(() => ref.read(playerProvider));
    _controller = LyricController(progressSource: _progress);
  }

  @override
  void dispose() {
    _controller.dispose();
    _progress.dispose();
    super.dispose();
  }

  /// 同一份文本/翻译只解析一次;解析异常按纯文本处理。
  LyricDocument? _documentFor(String raw, String? translation) {
    if (_parsedRaw == raw && _parsedTranslation == translation) {
      return _parsedDoc;
    }
    _parsedRaw = raw;
    _parsedTranslation = translation;
    try {
      final translationLrc = _translationLrc(raw, translation);
      return _parsedDoc = LyricDocument.parse(raw, translation: translationLrc);
    } catch (_) {
      return _parsedDoc = null;
    }
  }

  /// LiriQo 等来源的翻译通常是无时间戳文本，按主歌词行时间生成翻译 LRC。
  String? _translationLrc(String raw, String? translation) {
    final translated = translation?.trim();
    if (translated == null || translated.isEmpty) return null;

    // 已经是带时间戳的翻译 LRC，直接使用。
    if (RegExp(r'^\[\d{1,}:\d{2}', multiLine: true).hasMatch(translated)) {
      return translated;
    }

    final main = LyricDocument.parse(raw);
    final lines = translated
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return null;

    final buffer = StringBuffer();
    for (var i = 0; i < main.lines.length && i < lines.length; i++) {
      final start = main.lines[i].start;
      final minutes = start.inMinutes;
      final seconds = start.inSeconds.remainder(60).toString().padLeft(2, '0');
      final millis = start.inMilliseconds
          .remainder(1000)
          .toString()
          .padLeft(3, '0');
      buffer.writeln('[$minutes:$seconds.$millis]${lines[i]}');
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? null : result;
  }

  /// 把文档同步进 controller。放在帧后调用,避免 build 期间触发视图通知。
  void _syncDocument(String? raw, String? translation) {
    if (raw == _loadedRaw && translation == _loadedTranslation) return;
    _loadedRaw = raw;
    _loadedTranslation = translation;
    final doc = raw == null ? null : _documentFor(raw, translation);
    if (doc == null || doc.lines.isEmpty) {
      _controller.clear();
    } else {
      _controller.loadDocument(doc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final track = ref.watch(playerProvider.select((s) => s.current));
    if (track == null) {
      return _empty(
        theme,
        l10n.lyricsNotPlayingTitle,
        l10n.lyricsNotPlayingSubtitle,
      );
    }

    // 只在播放位置/播放状态变化时通知控制器，避免队列、设备等
    // 无关状态更新也触歌词采样。
    ref.listen(
      playerProvider.select((state) => (state.position, state.isPlaying)),
      (_, _) => _progress.notify(),
    );

    final lyricsAsync = ref.watch(lyricsProvider);
    final raw = lyricsAsync.value?.rawText;
    final translation = lyricsAsync.value?.translation;

    // 文档同步放到帧后:loadDocument/clear 会通知各视图,不能发生在 build 中。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncDocument(raw, translation);
    });

    return lyricsAsync.when(
      loading: () => Center(
        child: M3ELoadingIndicator(
          variant: M3ELoadingIndicatorVariant.contained,
          color: theme.colorScheme.tertiary,
          containerColor: theme.colorScheme.tertiaryContainer,
          semanticLabel: l10n.lyricsLoading,
        ),
      ),
      error: (e, _) => _empty(theme, l10n.lyricsLoadFailed, e.toString()),
      data: (lyrics) {
        final text = lyrics?.rawText ?? '';
        if (text.trim().isEmpty) {
          return _empty(theme, l10n.lyricsEmptyTitle, l10n.lyricsEmptySubtitle);
        }
        final doc = _documentFor(text, lyrics?.translation);
        if (doc == null || doc.lines.isEmpty) {
          return _plainLyrics(theme, text.trim());
        }
        final hasWordTiming = doc.lines.any(
          (LyricLine line) =>
              line.words?.any(
                (LyricWord word) => word.text.trim().isNotEmpty,
              ) ??
              false,
        );
        return LyricView(
          controller: _controller,
          preset: _preset(theme, hasWordTiming: hasWordTiming),
          onLineTap: (details) =>
              ref.read(playerProvider.notifier).seek(details.seekPosition),
        );
      },
    );
  }

  /// Apple Music 预设的紧凑版:多行滚动 + 小字号,并映射到播放页封面配色。
  /// 内置预设使用深色背景的浅色文字;这里改用 secondaryContainer 上的
  /// onSecondaryContainer,保证浅色/深色主题下都可读。
  LyricPreset _preset(M3EThemeData theme, {required bool hasWordTiming}) {
    final scheme = theme.colorScheme;
    final base = LyricPresets.appleMusic;
    final onBg = scheme.onSecondaryContainer;

    // fixed 布局会强制走 LyricWordPainter，对逐字 QRC 的每个字符做
    // 字形裁切和浮动绘制，容易掉帧。逐字歌词改用 dualStyle + 无
    // word effects，仍由 solid highlight 按词推进高亮。
    final timedBase = hasWordTiming
        ? base.copyWith(
            layoutMode: LyricLayoutMode.dualStyle,
            wordEffects: const LyricWordEffects(),
          )
        : base;

    return timedBase.copyWith(
      textStyle: TextStyle(
        fontSize: 32,
        height: 1.45,
        fontWeight: FontWeight.w700,
        color: onBg.withValues(alpha: 0.5),
      ),
      activeTextStyle: TextStyle(
        fontSize: 32,
        height: 1.45,
        fontWeight: FontWeight.w700,
        color: hasWordTiming ? onBg.withValues(alpha: 0.5) : onBg,
      ),
      translationTextStyle: TextStyle(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: onBg.withValues(alpha: 0.42),
      ),
      activeTranslationTextStyle: TextStyle(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: onBg.withValues(alpha: 0.72),
      ),
      highlight: hasWordTiming
          ? LyricHighlight.solid(onBg, tailFadeWidth: 12)
          : const LyricHighlight.none(),
      wordEffects: hasWordTiming ? base.wordEffects : const LyricWordEffects(),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      lineSpacing: 12,
      translationSpacing: 8,
      activeAnchor: const LyricAnchor.fraction(
        .45,
        target: LyricAnchorTarget.mainText,
      ),
      selectionAnchor: const LyricAnchor.fraction(
        .45,
        target: LyricAnchorTarget.mainText,
      ),
      edgeFade: const LyricEdgeFade.fraction(top: .12, bottom: .16),
      // 前奏/间奏圆点:沿用预设默认配置,颜色跟随主题主色。
      countdown: base.countdown.copyWith(color: scheme.primary),
    );
  }

  // 占位提示(居中,沿用全局配色)
  Widget _empty(M3EThemeData theme, String title, String subtitle) {
    final scheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lyrics_outlined,
            size: 64,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          SizedBox(height: theme.spacing.lg),
          Text(title, style: theme.typeScale.titleMedium),
          SizedBox(height: theme.spacing.xs),
          Text(
            subtitle,
            style: theme.typeScale.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 纯文本歌词:整段展示,可滚动
  Widget _plainLyrics(M3EThemeData theme, String text) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.xl,
        vertical: theme.spacing.lg,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.typeScale.bodyLarge.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.8,
        ),
      ),
    );
  }
}

/// 把 PlayerNotifier 的播放状态适配成 flutter_lyric 的进度源。
/// position 由控制器在播放中逐帧读取;changes 用于播放/暂停/seek 事件。
class _PlayerProgressSource implements LyricProgressSource {
  _PlayerProgressSource(this._read);

  final PlayerState Function() _read;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  bool _disposed = false;

  @override
  Duration get position => _read().position;

  @override
  bool get isAdvancing => _read().isPlaying;

  @override
  Stream<void> get changes => _changes.stream;

  void notify() {
    if (!_disposed) _changes.add(null);
  }

  void dispose() {
    _disposed = true;
    _changes.close();
  }
}

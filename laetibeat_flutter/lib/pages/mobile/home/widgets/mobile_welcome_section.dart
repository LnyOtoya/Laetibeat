import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../widgets/remote_browser_provider.dart';
import '../../../../widgets/settings/subsonic_provider.dart';

import 'mobile_home_constants.dart';
import '../../../../widgets/player/cover_provider.dart';
import '../../../../widgets/player/player_provider.dart';

//首页欢迎
class MobileWelcomeSection extends ConsumerStatefulWidget {
  const MobileWelcomeSection({super.key});

  @override
  ConsumerState<MobileWelcomeSection> createState() =>
      _MobileWelcomeSectionState();
}

//播放的阶段
enum _PlaybackPhase { greeting, playing, ending }

class _MobileWelcomeSectionState extends ConsumerState<MobileWelcomeSection> {
  //无限循环：page = index % [_pageCount]。
  static const int _pageCount = 3;
  static const int _itemCount = 900000;

  //自动轮播间隔。
  static const Duration _autoAdvanceInterval = Duration(seconds: 5);

  final PageController _controller = PageController();
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(_autoAdvanceInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_controller.page?.round() ?? 0) + 1;
      _controller.animateToPage(
        next,
        duration: kMobileHomeAnimDuration,
        curve: kMobileHomeAnimCurve,
      );
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    // 只订阅当前曲目与下一首,避免播放进度每 tick 触发轮播重建
    final current = ref.watch(playerProvider.select((s) => s.current));
    final next = ref.watch(
      playerProvider.select((s) {
        if (s.queue.length < 2) return null;
        return s.queue[(s.currentIndex + 1) % s.queue.length];
      }),
    );
    final username = _displayUsername(ref);

    return AnimatedContainer(
      height: 140,
      duration: kMobileHomeAnimDuration,
      curve: kMobileHomeAnimCurve,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
      child: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _itemCount,
        itemBuilder: (context, index) {
          final phase = _PlaybackPhase.values[index % _pageCount];
          return _buildPage(context, theme, phase, current, next, username);
        },
      ),
    );
  }

  String? _displayUsername(WidgetRef ref) {
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final server = servers.isEmpty ? null : servers.first;
    final configured = server?.username?.trim();
    if (server == null || configured == null || configured.isEmpty) {
      return null;
    }

    final fetched = ref
        .watch(
          remoteUserNameProvider((sourceId: server.id, username: configured)),
        )
        .value
        ?.trim();
    return fetched == null || fetched.isEmpty ? configured : fetched;
  }

  Widget _buildPage(
    BuildContext context,
    M3EThemeData theme,
    _PlaybackPhase phase,
    rust.UiTrack? current,
    rust.UiTrack? next,
    String? username,
  ) {
    final scheme = theme.colorScheme;
    final type = theme.typeScale;
    final emphasized = theme.typography.emphasized;

    final Widget content;
    switch (phase) {
      case _PlaybackPhase.greeting:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              username == null || username.isEmpty
                  ? _greetingFor(context, DateTime.now())
                  : AppLocalizations.of(context).homeGreetingWithName(
                      _greetingFor(context, DateTime.now()),
                      username,
                    ),
              style: type.headlineMedium,
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              AppLocalizations.of(context).homeGreetingQuestion,
              style: type.bodyLarge.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        );
      case _PlaybackPhase.playing:
        content = Row(
          children: [
            // 左侧三行文本,占满剩余宽度
            Expanded(
              child: _buildThreeLines(
                type: type,
                overline: current == null ? '未在播放' : '正在播放',
                headline: current?.title ?? '还没有播放音乐',
                supporting: current == null
                    ? '从音乐库选择一首歌曲开始'
                    : '${current.artist} · ${current.album}',
                overlineStyle: type.labelMedium.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                headlineStyle: emphasized.headlineMedium,
                supportingStyle: type.bodyLarge.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(width: theme.spacing.lg),
            _WelcomeCover(track: current, twelveSided: true, theme: theme),
          ],
        );
      case _PlaybackPhase.ending:
        content = Row(
          children: [
            // 左侧三行文本,占满剩余宽度
            Expanded(
              child: _buildThreeLines(
                type: type,
                overline: next == null ? '队列已到末尾' : '下一首即将播放',
                headline: next?.title ?? (current == null ? '队列为空' : '没有下一首了'),
                supporting: next?.artist ?? '从音乐库添加更多歌曲',
                overlineStyle: type.labelMedium.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                headlineStyle: type.headlineMedium,
                supportingStyle: type.bodyLarge.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(width: theme.spacing.lg),
            _WelcomeCover(track: next, twelveSided: false, theme: theme),
          ],
        );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.xl,
          vertical: theme.spacing.lg,
        ),
        child: content,
      ),
    );
  }

  //左对齐文本
  Widget _buildThreeLines({
    required M3ETypeScale type,
    required String overline,
    required String headline,
    required String supporting,
    required TextStyle? overlineStyle,
    required TextStyle headlineStyle,
    required TextStyle? supportingStyle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overline,
          style: overlineStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: type.labelMedium.fontSize ?? 0),
        Text(
          headline,
          style: headlineStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: type.labelMedium.fontSize ?? 0),
        Text(
          supporting,
          style: supportingStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

String _greetingFor(BuildContext context, DateTime now) {
  final l10n = AppLocalizations.of(context);
  final hour = now.hour;
  if (hour >= 5 && hour < 12) return l10n.homeGreetingMorning;
  if (hour >= 12 && hour < 18) return l10n.homeGreetingAfternoon;
  return l10n.homeGreetingEvening;
}

//轮播封面:有内嵌封面显示真实封面,否则保留渐变占位
class _WelcomeCover extends ConsumerWidget {
  const _WelcomeCover({
    required this.track,
    required this.twelveSided,
    required this.theme,
  });

  final rust.UiTrack? track;
  final bool twelveSided;
  final M3EThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = track;
    final bytes = current == null
        ? null
        : ref.watch(trackCoverProvider(current)).value;
    final hasArt = bytes != null && bytes.isNotEmpty;
    final scheme = theme.colorScheme;
    final size = theme.spacing.xxl * 3;

    final child = hasArt
        ? Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          )
        : Center(
            child: Icon(
              M3EIcons.music_note,
              size: theme.spacing.xxl,
              color: scheme.onSurfaceVariant,
            ),
          );

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [scheme.primaryContainer, scheme.tertiaryContainer],
    );

    return twelveSided
        ? M3EShapeContainer.cookie12Sided(
            width: size,
            height: size,
            gradient: gradient,
            clipBehavior: Clip.antiAlias,
            child: child,
          )
        : M3EShapeContainer.cookie4Sided(
            width: size,
            height: size,
            gradient: gradient,
            clipBehavior: Clip.antiAlias,
            child: child,
          );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../widgets/remote_browser_provider.dart';
import '../../../../widgets/settings/subsonic_provider.dart';

/// 首页欢迎语。只保留欢迎信息和推荐副标题。
class MobileWelcomeSection extends ConsumerWidget {
  const MobileWelcomeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final username = _displayUsername(ref);
    final greeting = _greetingFor(context, DateTime.now());
    final title = username == null || username.isEmpty
        ? greeting
        : l10n.homeGreetingWithName(greeting, username);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.typeScale.headlineMedium,
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          l10n.homeRecommendationSubtitle,
          textAlign: TextAlign.center,
          style: theme.typeScale.bodyLarge.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
}

String _greetingFor(BuildContext context, DateTime now) {
  final l10n = AppLocalizations.of(context);
  final hour = now.hour;
  if (hour >= 5 && hour < 12) return l10n.homeGreetingMorning;
  if (hour >= 12 && hour < 18) return l10n.homeGreetingAfternoon;
  return l10n.homeGreetingEvening;
}

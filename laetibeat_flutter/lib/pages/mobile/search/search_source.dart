import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/settings/persistence.dart';

enum MobileSearchSource { local, subsonic }

const String kMobileSearchSourceKey = 'mobile.searchSource';

class MobileSearchSourceNotifier extends Notifier<MobileSearchSource> {
  @override
  MobileSearchSource build() {
    return switch (ref
        .read(sharedPreferencesProvider)
        .getString(kMobileSearchSourceKey)) {
      'subsonic' => MobileSearchSource.subsonic,
      _ => MobileSearchSource.local,
    };
  }

  void select(MobileSearchSource source) {
    if (source == state) return;
    state = source;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(kMobileSearchSourceKey, source.name),
    );
  }
}

final mobileSearchSourceProvider =
    NotifierProvider<MobileSearchSourceNotifier, MobileSearchSource>(
      MobileSearchSourceNotifier.new,
    );

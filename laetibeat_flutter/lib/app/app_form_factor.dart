import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 应用形态。只由启动装配层判定一次，UI 层不得再直接判断平台。
enum AppFormFactor {
  desktop,
  mobile,
}

/// 在 bootstrap 中根据平台选择形态并 override 到 ProviderScope。
final appFormFactorProvider = Provider<AppFormFactor>((ref) {
  throw UnimplementedError(
    'appFormFactorProvider 必须在 bootstrap 中通过 overrideWithValue 注入',
  );
});

AppFormFactor detectAppFormFactor() {
  if (kIsWeb) return AppFormFactor.desktop;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => AppFormFactor.mobile,
    _ => AppFormFactor.desktop,
  };
}

extension AppFormFactorX on AppFormFactor {
  bool get isDesktop => this == AppFormFactor.desktop;
  bool get isMobile => this == AppFormFactor.mobile;
}

import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../app_form_factor.dart';

/// 桌面端与移动端的主题工厂。
///
/// 两端共享 seed color / 字体回退等基础 token，但各自拥有独立的
/// M3EThemeData 配置入口，后续调整密度、导航主题、圆角时不会互相影响。
class AppThemeFactory {
  const AppThemeFactory._();

  static const Color _seed = Color(0xFF6750A4);

  static const List<String> _fontFallback = <String>[
    'Noto Sans SC',
    'Noto Sans TC',
    'Noto Sans JP',
    'Noto Sans KR',
  ];

  static M3EThemeData dataFor(AppFormFactor formFactor) {
    final base = M3EThemeData.light(
      seedColor: _seed,
    ).copyWith(fontFamilyFallback: _fontFallback);

    return switch (formFactor) {
      AppFormFactor.desktop => base.copyWith(
          navigationRailTheme: M3ENavigationRailTheme(
            collapsedWidth: 104,
          ),
        ),
      AppFormFactor.mobile => base,
    };
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistence.dart';

//设置页分类
enum SettingsCategory {
  appearance, //外观
  playerAudio, //播放器与音频
  content, //内容
  storage, //储存
  backup, //备份与还原
  changelog, //更新日志
  about, //关于
}

//选中分类的控制器
class SettingsCategoryNotifier extends Notifier<SettingsCategory> {
  @override
  SettingsCategory build() => SettingsCategory.appearance;

  void select(SettingsCategory category) {
    state = category;
  }
}

//当前选中的设置分类
final settingsCategoryProvider = NotifierProvider<SettingsCategoryNotifier, SettingsCategory>(
  SettingsCategoryNotifier.new,
);

//应用主题模式
enum AppThemeMode {
  light('亮色主题'),
  dark('暗色主题'),
  system('跟随系统');

  final String label;
  const AppThemeMode(this.label);
}

class AppThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    // 启动时从本地设置恢复主题;非法/缺失值回退亮色
    final saved = ref.read(sharedPreferencesProvider).getString(kThemeModeKey);
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => AppThemeMode.light,
    );
  }

  void select(AppThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(kThemeModeKey, mode.name);
  }
}

//当前应用主题模式
final appThemeModeProvider =
    NotifierProvider<AppThemeModeNotifier, AppThemeMode>(AppThemeModeNotifier.new);

# Laetibeat 前端结构说明

> 最后更新：2026-10-31

本文档说明 `lib/` 的目录组成、桌面端/移动端入口、共享层边界，以及新增页面时的放置位置。

## 1. 启动链路

```text
lib/main.dart
  └─ bootstrap()
       ├─ 识别 AppFormFactor（desktop / mobile）
       ├─ 初始化 RustLib、SQLite、SharedPreferences、播放快照
       ├─ 注入平台服务 Provider
       └─ runApp(ProviderScope(child: LaetibeatApp()))
            └─ lib/app/app.dart
                 ├─ 选择主题：AppThemeFactory.dataFor(formFactor)
                 ├─ 包裹 MediaIntegrationHost
                 └─ 选择入口：
                      ├─ desktop -> DesktopApp
                      └─ mobile  -> MobileApp
```

关键文件：

```text
lib/main.dart
lib/app/bootstrap.dart
lib/app/app.dart
lib/app/app_form_factor.dart
lib/app/app_destination.dart
lib/app/app_size.dart
lib/app/theme/app_theme.dart
```

平台判断只允许出现在启动装配层（`app_form_factor.dart` / `bootstrap.dart`），页面和共享组件里不再直接判断 `TargetPlatform`。

## 2. 桌面端入口

```text
lib/pages/desktop/desktop_app.dart
```

`DesktopApp` 是桌面端唯一入口，负责：

- `M3ENavigationRail` 导航
- `M3ENavigationRail` 中的 Home / Library / Settings / Playlists / Charts
- Search 通过 NavigationRail 的 FAB 进入
- 顶部 `DesktopTitleBar`
- 按 `AppDestination` 切换桌面页面

桌面端结构：

```text
lib/pages/desktop/
  desktop_app.dart              # 桌面入口与导航
  desktop_title_bar.dart        # 自定义标题栏
  playlist_page.dart            # 歌单占位页
  chart_page.dart               # 图表占位页

  home/
    desktop_home_page.dart      # Home 双栏组合
    home_content.dart           # 首页内容主体

  library/
    desktop_library_page.dart   # Library 双栏组合

  search/
    desktop_search_page.dart    # Search 双栏组合
    search_view.dart            # 搜索状态与搜索结果内容

  settings/
    desktop_settings_page.dart  # 设置双栏组合
    settings_content.dart       # 设置分类内容映射

  player/
    desktop_playback_page.dart  # 桌面全屏播放页
    player_right_pane.dart      # 右侧播放面板/详情容器
    device_panel.dart           # 设备/输出面板

  layout/
    two_pane_layout.dart        # 桌面双栏/窄屏单栏布局
```

桌面端页面组合依赖的共享组件仍在：

```text
lib/widgets/library_browser.dart
lib/widgets/settings/
lib/widgets/player/playback_panel.dart
```

这些组件没有放进 `pages/desktop/`，因为它们属于可复用业务组件或播放核心，后续移动端也可能复用。

## 3. 移动端入口

```text
lib/pages/mobile/mobile_app.dart
```

`MobileApp` 是移动端唯一入口：

- 底部三个 Tab：Home / Library / Search
- `body` 内使用嵌套 `Navigator`，Home 是根 route
- 打开 Library / Search 会 push 新 route，底部导航外框保持不动
- 返回时 pop 回 Home，支持系统返回与 Android 预测性返回
- 使用 `NavigatorPopHandler` 将系统返回代理给嵌套 Navigator
- AndroidManifest 已开启 `android:enableOnBackInvokedCallback="true"`

移动端目录：

```text
lib/pages/mobile/
  mobile_app.dart               # 移动端入口 + 底部导航 + 嵌套 Navigator
  home/
    mobile_home_page.dart       # 独立首页
  library/
    mobile_library_page.dart    # 独立音乐库页
  search/
    mobile_search_page.dart     # 独立搜索页
```

移动端新增页面时，建议继续放在 `lib/pages/mobile/` 下，例如：

```text
lib/pages/mobile/
  home/
  library/
  search/
  player/
  settings/
  widgets/
  routes.dart
```

移动端 UI 不应 import `lib/pages/desktop/`。当前两端互不引用。

## 4. 共享层

### 4.1 共享状态与业务 Provider

```text
lib/widgets/player/player_provider.dart
lib/widgets/player/cover_provider.dart
lib/widgets/player/lyric_provider.dart
lib/widgets/player/playback_backend.dart

lib/widgets/settings/music_library_provider.dart
lib/widgets/settings/subsonic_provider.dart
lib/widgets/settings/remote_sync_provider.dart
lib/widgets/settings/settings_provider.dart

lib/widgets/remote_browser_provider.dart
lib/widgets/recommendation_provider.dart
lib/widgets/player/playback_stats.dart
```

这些 Provider 是两端共用的数据与业务状态，不应复制到桌面端或移动端页面里。

### 4.2 共享展示组件

```text
lib/widgets/library_browser.dart        # 音乐库浏览 UI
lib/widgets/settings/                   # 设置详情内容
lib/widgets/player/playback_panel.dart  # 播放面板核心
lib/widgets/player/lyrics_view.dart
lib/widgets/player/squish_button_row.dart
lib/widgets/daily_section.dart
lib/widgets/recent_section.dart
lib/widgets/welcome_section.dart
lib/widgets/history_section.dart
```

这些组件目前主要供桌面端使用，但保留在共享目录，方便移动端后续复用或提取。

### 4.3 共享布局契约

```text
lib/shared/layout/app_bottom_inset.dart
```

提供“页面底部需要预留高度”的统一作用域。桌面端没有该作用域时返回 0；移动端如果实现浮动播放器，可以使用它。

## 5. 平台能力与服务

```text
lib/core/providers/playback_backend_provider.dart
lib/core/services/directory_picker.dart
lib/core/services/media_session_service.dart
lib/core/services/window_service.dart
```

| 服务 | 桌面端实现 | 移动端现状 |
|---|---|---|
| DirectoryPicker | Rust `rfd` 目录选择 | 返回 null，待接 SAF / READ_MEDIA_AUDIO |
| WindowService | `window_manager` | `NoopWindowService` |
| MediaSessionService | 当前 Noop（MPRIS 暂停用） | 当前 Noop，待接 audio_service / MediaSession |
| PlaybackBackend | `MediaKitBackend` | 目前同样注入 `MediaKitBackend` |

服务选择统一在 `lib/app/bootstrap.dart` 完成，页面不直接创建具体平台实现。

## 6. 主题

```text
lib/app/theme/app_theme.dart
```

- `dataFor(AppFormFactor.desktop)`：桌面端主题配置
- `dataFor(AppFormFactor.mobile)`：移动端主题配置

两端共享 seed color 和字体回退等基础 token。移动端专属视觉修改应尽量只改 mobile 分支，避免影响桌面端。

## 7. 依赖规则

允许：

```text
desktop pages  -> widgets / core / app
mobile pages   -> widgets / core / app
widgets        -> core (必要时)
app            -> pages / widgets / core
```

禁止：

```text
desktop pages  -> mobile pages
mobile pages   -> desktop pages
widgets        -> pages
core           -> pages
```

当前已检查：

- 移动端没有 import 桌面端文件；
- 桌面端没有 import 移动端文件；
- 共享 Provider 不感知 UI 形态。

## 8. 新增页面时放在哪里

### 桌面端

1. 页面放在 `lib/pages/desktop/<feature>/`；
2. 路由/导航入口加到 `lib/pages/desktop/desktop_app.dart`；
3. 如果复用了 `lib/widgets/` 里的共享组件，注意该组件同时可能被移动端使用。

### 移动端

1. 页面放在 `lib/pages/mobile/<feature>/`；
2. 在 `lib/pages/mobile/mobile_app.dart` 的 `_buildTab()` 或自己的路由中接入；
3. 需要平台能力时，通过 `lib/core/services/` 的接口访问，不要直接在页面里写平台判断。

## 9. 当前遗留项

- `lib/pages/tmp.dart.bak` 是旧备份文件，不参与编译；确认不再需要后可删除。
- 移动端 UI 目前是占位壳，播放器、音乐库、搜索等页面待重写。
- `MobileDirectoryPicker` 仍返回 null，移动端本地音乐目录选择尚未接入。
- `MediaSessionService` 仍为 Noop，Android 后台播放与媒体通知尚未接入。

## 10. 验证命令

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter build linux --debug
```

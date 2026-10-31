/// 应用级目的地模型。
///
/// 桌面 Shell 和移动 Shell 各自把它映射到自己的导航控件：
/// - 桌面：NavigationRail destination
/// - 移动：NavigationBar tab 或 Navigator 二级页面
enum AppDestination {
  home,
  library,
  search,
  settings,
  playlists,
  charts,
}

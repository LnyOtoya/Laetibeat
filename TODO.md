# Laetibeat 项目蓝图

> 最后更新：2026-10-31
> 当前阶段：桌面端功能补全 + 移动端解耦

## 当前状态速览

- 本地音乐：扫描、增量复用、专辑/艺术家聚合、播放、封面、歌词、统计、推荐
- Navidrome：单服务端配置、手动同步、SQLite 快照、浏览/搜索、播放、封面/歌词、scrobble
- 缓存：本地封面按需读取；远端封面内存 + 磁盘 LRU；歌词 SQLite 正负缓存
- 跨平台：Linux 桌面可用；Android 已完成 Shell/页面/服务解耦，本地目录选择与后台媒体会话待接入；Windows/macOS 打包未开始
- 主要缺口：收藏/歌单/队列编辑/下载、播放设置、MPRIS/MediaSession 迁移、移动端存储权限与 SAF

## 阶段1：数据模型与基础扫描

- [x] 1.1 初始化 Rust workspace
- [x] 1.2 定义 Track/Album/Artist/PlayState 与音源抽象（AudioSource 目前保留，远端由 laetibeat_remote 独立实现）
- [x] 1.3 本地文件夹扫描与元数据解析（walkdir + lofty，支持 mp3/flac/m4a/wav）
- [x] 1.4 解码方案定板：桌面使用 media_kit（libmpv + FFmpeg），不自研 PCM 解码
- [x] 1.5 增量扫描：path + modified_ms + file_size 指纹复用
- [x] 1.6 Rust 侧专辑/艺术家聚合与碟号/音轨号排序

## 阶段2：前端与 FFI

- [x] 2.1 初始化 Flutter 前端（laetibeat_flutter）
- [x] 2.2 配置 flutter_rust_bridge
- [x] 2.3 打通 Dart ↔ Rust 数据传输
- [x] 2.4 UI 骨架：选择目录 → Rust 扫描 → 列表展示
- [x] 2.5 音乐库 JSON 快照持久化（临时文件 + rename、schemaVersion、Isolate 编解码）

## 阶段3：桌面播放与播放器 UI

- [x] 3.1 PlaybackBackend 抽象 + MediaKitBackend（Linux）
- [x] 3.2 播放状态由引擎流驱动：position/duration/playing/completed
- [x] 3.3 播放队列、随机播放、重复模式（顺序/单曲/列表）
- [x] 3.4 队列与播放状态持久化（不恢复播放进度）
- [x] 3.5 共享播放面板：封面取色、歌词、全屏、队列浮层
- [x] 3.6 设备/输出面板：设备切换、采样率/声道/码率
- [x] 3.7 本地/远端音源切换（简化到单 Navidrome）
- [x] 3.8 拖动进度条松手 seek；超长曲目 h:mm:ss 显示
- [ ] 3.9 收藏/喜欢（Favorite 导航、曲目/专辑喜欢、本地 + OpenSubsonic star/unstar）
- [ ] 3.10 歌单（本地 CRUD、加入歌单、远端 playlist 后续）
- [ ] 3.11 队列编辑（加入队列、下一首播放、删除、拖动排序、清空）
- [ ] 3.12 下载（当前按钮为占位）
- [ ] 3.13 播放设置：倍速、均衡器、淡入淡出、跳过静音、ReplayGain
- [ ] 3.14 底部三点菜单/列表行的“加入播放队列”“查看详情”等占位动作

## 阶段4：OpenSubsonic / Navidrome

- [x] 4.1 认证：API Key + 用户名密码 token（由 opensubsonic crate 处理 MD5/salt）
- [x] 4.2 统一客户端封装与 sourceId 注册表（laetibeat_remote）
- [x] 4.3 浏览/搜索/播放/封面/歌词接口
- [x] 4.4 单服务端连接配置：内容页弹层、测试成功才可保存
- [x] 4.5 手动同步音乐：getAlbumList2 分页 + 每专辑 getAlbum 并发，进度流
- [x] 4.6 SQLite 远端库：generation 代际切换，失败回滚保留旧数据
- [x] 4.7 远端浏览/搜索改为读本地 SQLite 快照
- [x] 4.8 scrobble 上报（now playing + 达到阈值后的正式记录）
- [ ] 4.9 远端 playlist / starred 列表
- [ ] 4.10 增量同步、取消同步、进度事件节流
- [ ] 4.11 离线 scrobble 队列与失败重试
- [ ] 4.12 大曲库分页/按需加载（当前推荐会缓存全部远端曲目）
- [ ] 4.13 last.fm 等外部统计平台上报

## 阶段5：播放统计与首页

- [x] 5.1 SQLite 播放事件与曲目聚合统计
- [x] 5.2 首页播放记录：今天/本周/本月、累计播放、收听时长、Top 歌手/专辑
- [x] 5.3 跨音源统计（本地 + 远端合并）
- [x] 5.4 专辑级推荐三模式，合并本地与远端播放记录
- [ ] 5.5 播放热力图
- [ ] 5.6 Home「See all」等入口落地

## 阶段6：封面 / 歌词 / 缓存

- [x] 6.1 本地封面：Rust lofty 读取内嵌图
- [x] 6.2 远端封面：内存 LRU + 磁盘 LRU 256MB，服务器变更时清理
- [x] 6.3 本地歌词：内嵌 → sidecar，按音频/sidecar 指纹缓存
- [x] 6.4 远端歌词：OpenSubsonic 返回，正缓存长期、负缓存 1 天
- [x] 6.5 歌词缓存 20MB 上限与过期负缓存清理
- [ ] 6.6 手动搜索歌词（见项目记忆；本地优先写 .lrc，后续可选写入标签）

## 阶段7：跨平台与系统集成

- [x] 7.1 Linux 桌面音频输出与调试构建
- [x] 7.2 导航壳解耦：DesktopShell / MobileShell 分离，页面按形态独立组合
- [x] 7.3 页面响应式：桌面 TwoPaneLayout 窄屏折叠，移动端使用独立单栏页面
- [x] 7.4 移动端播放页：迷你播放器 + 全屏页，隐藏 DevicePanel
- [ ] 7.5 MPRIS 迁移到 audio_service + audio_service_mpris（当前自研 MPRIS 已停用）
- [ ] 7.6 Android 后台播放、媒体会话、常驻通知
- [ ] 7.7 Windows / macOS / Android 打包与适配测试
- [x] 7.8 window_manager 平台门控与移动端启动配置

## 已知问题 / 技术债

- 自研 MPRIS 会卡死 waybar，已停用；后续统一迁移 audio_service
- 远端同步仅支持全量，暂无取消与增量；大库同步时间较长
- Scrobble 为 best-effort，服务器离线时不会补报
- 推荐聚合会把全部远端曲目缓存到内存，超大曲库需要改为聚合查询
- 本地音乐库仍使用 JSON 快照；播放统计与远端库使用两个独立 SQLite
- 多个设置分类仍是占位：播放器与音频、储存、备份与还原、更新日志
- 导航 Favorite/History/Daily Recommend 目前只改变选中态，不切换页面
- 移动端目录选择已抽象为 DirectoryPicker，但 MobileDirectoryPicker 仍返回 null，需接 SAF / READ_MEDIA_AUDIO
- 移动端后台播放与 MediaSession 尚未接入，MediaSessionService 当前为 Noop
- 远端推荐依赖先执行一次「同步音乐」
- 远端歌词正缓存没有 TTL，服务器更新歌词后需要手动清理

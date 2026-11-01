# Laetibeat 项目蓝图

> 最后更新：2026-11-01
> 当前阶段：移动端 UI 完善 + Android 音频服务迁移准备

## 当前状态速览

- 本地音乐：扫描、增量复用、专辑/艺术家聚合、播放、封面、歌词、统计、推荐
- Navidrome：单服务端配置、手动同步、SQLite 快照、浏览/搜索/播放、封面/歌词、scrobble
- 缓存：本地封面按需读取；远端封面内存 + 磁盘 LRU；歌词 SQLite 正负缓存
- 移动端：首页/音乐库/搜索/设置/播放页/迷你播放器已完成；音乐库按歌曲、歌单、艺术家、专辑分组
- 移动端 OpenSubsonic：连接、测试、扫描、歌单、艺术家简介、专辑/曲目浏览已接入真实数据
- 跨平台：Linux 桌面可用；Android UI 已解耦，后台播放与媒体会话待迁移；Windows/macOS 打包未开始
- 主要缺口：收藏/歌单编辑/队列编辑/下载、播放设置、Android 音频服务、移动端 SAF、MPRIS 迁移
- 音频后端：目前所有平台统一使用 media_kit；Android 计划迁移到 audio_service + just_audio

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
- [x] 2.6 移动端运行时生成接口：歌单、艺术家简介等 FFI 已接入

## 阶段3：桌面播放与播放器 UI

- [x] 3.1 PlaybackBackend 抽象 + MediaKitBackend（Linux）
- [x] 3.2 播放状态由引擎流驱动：position/duration/playing/completed
- [x] 3.3 播放队列、随机播放、重复模式（顺序/单曲/列表）
- [x] 3.4 队列与播放状态持久化（不恢复播放进度）
- [x] 3.5 共享播放面板：封面取色、歌词、全屏、队列浮层
- [x] 3.6 设备/输出面板：设备切换、采样率/声道/码率
- [x] 3.7 本地/远端音源切换（简化到单 Navidrome）
- [x] 3.8 拖动进度条松手 seek；超长曲目 h:mm:ss 显示
- [x] 3.9 移动端复用的迷你播放器、全屏播放页、播放队列浮层
- [x] 3.10 移动端歌曲列表接入真实本地/远端数据
- [ ] 3.11 收藏/喜欢（Favorite 导航、曲目/专辑喜欢、本地 + OpenSubsonic star/unstar）
- [ ] 3.12 歌单（本地 CRUD、加入歌单、远端 playlist 详情）
- [ ] 3.13 队列编辑（加入队列、下一首播放、删除、拖动排序、清空）
- [ ] 3.14 下载（当前按钮为占位）
- [ ] 3.15 播放设置：倍速、均衡器、淡入淡出、跳过静音、ReplayGain
- [ ] 3.16 底部三点菜单/列表行的“加入播放队列”“查看详情”等占位动作

## 阶段4：OpenSubsonic / Navidrome

- [x] 4.1 认证：API Key + 用户名密码 token（由 opensubsonic crate 处理 MD5/salt）
- [x] 4.2 统一客户端封装与 sourceId 注册表（laetibeat_remote）
- [x] 4.3 浏览/搜索/播放/封面/歌词接口
- [x] 4.4 单服务端连接配置：内容页弹层、测试成功才可保存
- [x] 4.5 手动同步音乐：getAlbumList2 分页 + 每专辑 getAlbum 并发，进度流
- [x] 4.6 SQLite 远端库：generation 代际切换，失败回滚保留旧数据
- [x] 4.7 远端浏览/搜索改为读本地 SQLite 快照
- [x] 4.8 scrobble 上报（now playing + 达到阈值后的正式记录）
- [x] 4.9 远端歌单：OpenSubsonic getPlaylists FFI + 移动端歌单列表
- [x] 4.10 艺术家详情：getArtistInfo2 FFI + biography
- [ ] 4.11 远端 playlist 详情、添加/删除曲目
- [ ] 4.12 远端 starred / 收藏列表
- [ ] 4.13 增量同步、取消同步、进度事件节流
- [ ] 4.14 离线 scrobble 队列与失败重试
- [ ] 4.15 大曲库分页/按需加载（当前推荐会缓存全部远端曲目）
- [ ] 4.16 last.fm 等外部统计平台上报

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
- [x] 7.2 导航壳解耦：DesktopApp / MobileApp 分离，页面按形态独立组合
- [x] 7.3 页面响应式：桌面 TwoPaneLayout 窄屏折叠，移动端使用独立单栏页面
- [x] 7.4 移动端播放页：迷你播放器 + 全屏播放页，隐藏 DevicePanel
- [ ] 7.5 MPRIS 迁移到 audio_service + audio_service_mpris（当前自研 MPRIS 已停用）
- [ ] 7.6 Android 后台播放、媒体会话、常驻通知
- [ ] 7.7 Windows / macOS / Android 打包与适配测试
- [x] 7.8 window_manager 平台门控与移动端启动配置
- [x] 7.9 移动端页面体系：首页/音乐库/搜索/设置/外观/内容/音源配置
- [x] 7.10 移动端库分类：歌曲、歌单、艺术家、专辑；支持排序、宫格/列表切换
- [x] 7.11 移动端详情页：专辑详情、艺术家详情、多碟分组、曲目列表
- [x] 7.12 移动端搜索栏、AppBar、底部导航、预测性返回
- [x] 7.13 歌曲排序：默认/标题/艺术家/专辑/添加时间，设置页同步
- [x] 7.14 移动端 OpenSubsonic 配置页真实连接、测试、扫描

## 阶段8：Android 音频服务迁移（当前）

目标：Android 从 media_kit 迁移到 `audio_service` + `just_audio`，桌面继续 media_kit。

### 8.1 播放后端拆分

- [ ] 新增 `JustAudioBackend`（Android/iOS）
- [ ] bootstrap 按平台注入：Android/iOS → JustAudio，桌面 → MediaKit
- [ ] 保持 `PlaybackBackend` 接口不向 UI 泄漏具体引擎
- [ ] 补齐 buffering / error / processing state 抽象
- [ ] 验证 OpenSubsonic stream URL、本地 file URI、恢复播放

### 8.2 audio_service 与状态归属

- [ ] 初始化 `audio_service`，配置通知渠道与 ongoing 行为
- [ ] 新增 `LaetibeatAudioHandler`，映射 play/pause/stop/seek/next/previous
- [ ] 明确播放状态源：AudioHandler 持有播放器，还是现有 PlayerNotifier 持有播放器
- [ ] 若 AudioHandler 在后台 isolate 运行，评估统计/scrobble/队列持久化迁移
- [ ] 用 `MediaItem` 同步标题、艺术家、专辑、时长、封面 `artUri`
- [ ] 同步队列、随机模式、重复模式
- [ ] 通知栏、锁屏、耳机键、媒体按钮
- [ ] 通知点击回到播放页/当前页面
- [ ] 替换/收缩 `MediaSessionService.sync()` 拉取式桥接

### 8.3 Android 配置

- [ ] Manifest 增加 `WAKE_LOCK`
- [ ] Manifest 增加 `FOREGROUND_SERVICE`
- [ ] Manifest 增加 `FOREGROUND_SERVICE_MEDIA_PLAYBACK`
- [ ] 声明 `AudioService`，`foregroundServiceType="mediaPlayback"`
- [ ] 声明 `MediaButtonReceiver`
- [ ] MainActivity 切换到 `AudioServiceActivity` 或 `AudioServiceFragmentActivity`
- [ ] Android 13+ 请求 `POST_NOTIFICATIONS`
- [ ] 通知频道、单色小图标、专辑封面大图标
- [ ] 处理 Android 14+ 前台服务类型启动限制

### 8.4 音频焦点与生命周期

- [ ] 配置 `audio_session` 为音乐用途
- [ ] 来电/其他应用播放时暂停或 duck
- [ ] 耳机拔出 becoming noisy 处理
- [ ] 蓝牙/有线/扬声器切换
- [ ] 暂停后通知保留策略
- [ ] App 退到后台、锁屏、划掉后的行为验证
- [ ] 后台播放时统计和 scrobble 继续工作

### 8.5 验证

- [ ] 本地文件后台播放
- [ ] OpenSubsonic 流媒体后台播放
- [ ] 锁屏控制
- [ ] 蓝牙耳机播放/暂停/上一首/下一首
- [ ] 暂停、继续、seek、播放完成
- [ ] 通知权限拒绝时的降级行为
- [ ] Android 13/14/15 和不同厂商 ROM

## 阶段9：Rust 音频引擎 / 发烧音频（未来）

目标：参考 Flick 等项目的 Rust UAC 实现，逐步建立独立的高解析音频后端；不阻塞阶段 8 的普通移动端播放。

### 9.1 架构原则

- [ ] FRB 只做控制面和状态事件，不通过 FRB 传输 PCM
- [ ] Rust 音频线程独立于 Flutter UI isolate
- [ ] 普通 Android 输出、Oboe/AAudio 独占、USB UAC 作为不同输出 backend
- [ ] 独占失败/未接 DAC 时自动回退 Android 标准管线
- [ ] 音频统计、队列、媒体库继续与普通播放共用

### 9.2 Rust 音频引擎

- [ ] 新增 Rust audio crate：解码、DSP、输出、队列时钟
- [ ] 解码：Symphonia / FFmpeg，覆盖 FLAC/WAV/MP3/M4A/OGG
- [ ] 重采样、dither、预放大、限幅
- [ ] 10 段/31 段参量均衡器
- [ ] 淡入淡出、crossfade、gapless
- [ ] 播放位置、缓冲、完成、错误事件
- [ ] 与 Flutter 的播放队列/统计状态同步

### 9.3 Android 输出

- [ ] Oboe/AAudio 标准输出
- [ ] 支持设备的 Oboe/AAudio exclusive mode
- [ ] DAP/内置 DAC 设备适配与白名单
- [ ] 输出采样率/位深跟随源文件
- [ ] 设备切换、耳机拔出、路由变化处理

### 9.4 USB DAC 独占

- [ ] Android UsbManager 授权与设备枚举
- [ ] USB fd 转交 Rust/libusb
- [ ] UAC1/UAC2 描述符解析
- [ ] claim interface、alt setting、采样率控制
- [ ] isochronous OUT 传输与环形缓冲
- [ ] 异步 DAC feedback 端点
- [ ] DAC quirk 兼容表
- [ ] 独占音量控制与系统音量键
- [ ] 拔出/重连恢复

### 9.5 DSD / 高解析

- [ ] DSF/DFF 解析
- [ ] WavPack DSD
- [ ] Native DSD
- [ ] DoP over PCM
- [ ] DSD → PCM 降级
- [ ] DAC 能力探测与输出策略

### 9.6 参考项目与许可证

- [ ] 研究 Flick 的 Rust UAC2 / Oboe / DSP 架构
- [ ] 研究 TrueSample Player 的 `usbaudio` UAC1/UAC2 库
- [ ] 研究 sylvakru 的 USB 独占实现
- [ ] 确认代码许可证、libusb/FFmpeg 等依赖分发方式
- [ ] 只移植必要模块，避免直接复制完整应用层

### 9.7 验收

- [ ] 本地 FLAC 原采样率直出 USB DAC
- [ ] 44.1/48/96/192kHz 切换正确
- [ ] 24bit 输出正确
- [ ] 无系统通知音混入（独占模式）
- [ ] DAC 拔出/重连不崩溃
- [ ] 普通模式与独占模式可切换
- [ ] 输出路径诊断 UI：采样率/位深/是否 bit-perfect

## 已知问题 / 技术债

- 自研 MPRIS 会卡死 waybar，已停用；后续统一迁移 audio_service
- Android 当前仍使用 media_kit；后台播放、媒体会话、常驻通知尚未接入
- `MediaSessionService` 当前是 Noop，`MediaIntegrationHost` 仅做简单状态同步
- 播放后端目前所有平台统一注入 `MediaKitBackend`，尚未按平台拆分
- media_kit 在 Android 上出现过原生 SIGSEGV，后台场景需要重点验证
- 远端同步仅支持全量，暂无取消与增量；大库同步时间较长
- Scrobble 为 best-effort，服务器离线时不会补报
- 推荐聚合会把全部远端曲目缓存到内存，超大曲库需要改为聚合查询
- 本地音乐库仍使用 JSON 快照；播放统计与远端库使用两个独立 SQLite
- 多个设置分类仍是占位：播放器与音频、储存、备份与还原、更新日志
- 导航 Favorite/History/Daily Recommend 目前只改变选中态，不切换页面
- 移动端目录选择已抽象为 DirectoryPicker，但 MobileDirectoryPicker 仍返回 null，需接 SAF / READ_MEDIA_AUDIO
- 移动端收藏、歌单编辑、下载、队列编辑仍为占位
- 远端推荐依赖先执行一次「同步音乐」
- 远端歌词正缓存没有 TTL，服务器更新歌词后需要手动清理
- 高级均衡器、USB 独占、DSD 尚未实现；当前没有现成 Flutter 包可直接满足

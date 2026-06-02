# Vibe Music Bug Log

## 2026-06-01: FFI CREATE_NO_WINDOW — 控制台窗口彻底消除

**问题**: node.exe 是 CUI 程序，任何启动方式（Process.start normal/detached、VBS、PowerShell Hidden）都会分配控制台窗口。
**根因**: Windows 内核对 CUI 程序强制分配控制台，只有 CreateProcessW + CREATE_NO_WINDOW (0x08000000) 标志能绕过。
**方案**: dart:ffi 直接调用 kernel32.dll 的 CreateProcessW，配合 SECURITY_ATTRIBUTES.bInheritHandle=1 确保子进程继承 stdin/stdout/stderr。
**文件**: lib/core/services/backend_service.dart（完全重写）
**依赖**: fi: ^2.2.0（新增）

## 2026-06-01: 句柄不可继承导致 node 无法正常启动

**问题**: CreateFileW 默认创建不可继承句柄，InheritHandles=0 禁止继承，node 拿不到有效的 stdout/stderr。
**表现**: 端口 3000 打开但接口无响应（node 启动异常）。
**修复**: SECURITY_ATTRIBUTES.bInheritHandle=1 + CreateProcessW bInheritHandles=1。

## 2026-06-01: inactive 生命周期误杀 node

**问题**: didChangeAppLifecycleState 在 inactive 状态（alt-tab）就调用 BackendService.stop()，导致切窗口就杀 node。
**修复**: 只在 dispose 时 stop，inactive 不做操作。

## 历史重大 Bug

| 日期 | Bug | 修复 |
|------|-----|------|
| 2026-05-30 | just_audio Windows 不支持 | 换 audioplayers |
| 2026-05-30 | Kuwo API JSON 解析失败 | 换 NeteaseCloudMusicApi |
| 2026-05-31 | 歌曲只能听30秒 | 网易云扫码登录获取 cookie |
| 2026-05-31 | 歌词不同步 | 重进歌词页时重新定位到当前时间线 |
| 2026-05-31 | 退出后播放状态丢失 | Hive 缓存当前歌曲+进度 |
| 2026-05-31 | PUB_CACHE 权限被 VPN 锁 | icacls 修复权限 |
| 2026-06-01 | node 控制台窗口 | FFI CreateProcessW + CREATE_NO_WINDOW |
| 2026-06-01 | WMF 无法播放外部音频 | HttpClient 下载到本地 + DeviceFileSource |
| 2026-06-01 | Hive 文件锁崩溃 | 改用 TEMP 目录存储 |
| 2026-06-01 | nuget SSL 下载失败 | Dart HttpClient 手动下载 |
| 2026-06-01 | 隐藏启动崩溃 | 避免 -WindowStyle Hidden |
| 2026-06-02 | GetModuleHandleW 查找错误 | 改用 kernel32.dll |
| 2026-06-02 | 悬浮歌词切歌不同步 | 保持 lyricsNotifierProvider 常驻 |
| 2026-06-02 | 暂停状态音量条失效 | try-catch + StatefulWidget |
| 2026-06-02 | 悬浮歌词按钮无反应 | 改用 StatefulWidget |

## 2026-06-01: WMF 无法播放外部音频 URL (80072EFD)

**问题**: Windows Media Foundation 无法连接外部 CDN 服务器（网易云 m801.music.126.net 等），报错 PlatformException(WindowsAudioError, 80072EFD)。Dart HttpClient 可以通过 indProxy = 'DIRECT' 绕过系统代理，但 WMF 使用系统网络栈，被 VPN 残留破坏。
**表现**: 接口返回 play OK，音频 URL 有效，但播放器无法加载音频。
**方案**: 新增 _downloadToFile 方法，用 HttpClient 先将音频下载到本地临时文件（%TEMP%\\vibe_audio_cache\\），再用 DeviceFileSource 播放本地文件。内存+磁盘双重缓存避免重复下载。
**文件**: lib/data/services/audio_player_service.dart

## 2026-06-01: Hive 文件锁导致应用崩溃

**问题**: Hive.initFlutter() 默认使用 C:\\Users\\<user>\\Documents\\ 目录。Codex sandbox 进程持有 .lock 文件锁且无法释放（Access Denied），导致 Hive 无法打开任何 Box，应用启动后崩溃。
**表现**: PathAccessException: Cannot open file, path = '...\\Documents\\netease_auth.hive' (OS Error: 拒绝访问。, errno = 5)
**方案**: 改为 Hive.init() + %TEMP%\\VibeMusic\\ 目录，绕过 sandbox 文件锁。
**文件**: lib/main.dart

## 2026-06-01: flutter clean 后 nuget.exe 下载失败

**问题**: lutter clean 删除了 CMake 缓存的 
uget.exe。重建时 CMake 尝试从 dist.nuget.org 下载，但系统 SSL 损坏（VPN 残留 SEC_E_NO_CREDENTIALS），下载失败导致构建中断。
**表现**: CMake Error: downloading 'https://dist.nuget.org/win-x86-commandline/v6.5.0/nuget.exe' failed, status_code: 35, SSL connect error
**方案**: 通过 Dart HttpClient（绕过代理）手动下载 
uget.exe 和 Microsoft.Windows.ImplementationLibrary nupkg，放置到 build 缓存目录。同时创建 NuGet.Config 指向本地源。
**文件**: 构建缓存（非代码）

## 2026-06-01: Flutter 窗口管理器导致隐藏启动崩溃

**问题**: 通过 Start-Process -WindowStyle Hidden 启动 exe 时，Flutter 的 windowManager 初始化失败导致应用崩溃。必须通过 ProcessStartInfo + CreateNoWindow=false + RedirectStandardError=true 启动才能稳定运行。
**表现**: 应用启动后 20-30 秒内静默退出，无错误输出。
**根因**: Flutter 引擎依赖有效的窗口句柄，-WindowStyle Hidden 导致窗口管理器无法正确初始化。
**规避**: 直接双击 exe 或从项目根目录通过 Start-Process 启动（不使用 -WindowStyle Hidden）。

## 2026-06-02: 悬浮歌词窗口初始化失败 — GetModuleHandleW 查找错误

**问题**: GetModuleHandleW 属于 kernel32.dll，但代码中错误地从 user32.dll 查找。
**表现**: Failed to lookup symbol 'GetModuleHandleW': The specified procedure could not be found.
**修复**: 改为 _kernel32.lookupFunction。
**文件**: lib/core/services/floating_lyrics_service.dart

## 2026-06-02: 悬浮歌词切歌不同步

**问题**: lyricsNotifierProvider 是懒加载的 NotifierProvider，只在歌词页被 ef.watch 激活。歌词页关闭后 Notifier 休眠，ef.listen(currentTrackProvider) 不触发，悬浮窗歌词不更新。
**表现**: 切歌或拖动进度条后悬浮歌词仍显示上一首，必须手动打开歌词页才能刷新。
**修复**: 在 PlayerBar 的 uild 中加入 ef.watch(lyricsNotifierProvider) 保持 Notifier 常驻。同时在 _fetchLyrics 中清空悬浮文字，加载完成后立即 _syncCurrentLine 同步当前位置。
**文件**: lib/ui/widgets/player_bar.dart, lib/providers/lyrics_provider.dart

## 2026-06-02: 暂停状态音量条无法拖动

**问题**: udioplayers 在无活跃音源时调用 setVolume 会抛异常，导致 Slider 的 onChanged 失败。
**表现**: 暂停/停止状态下拖动音量条无反应，播放后才跳到新位置。
**修复**: setVolume 加 	ry-catch 容错；_playCurrent 和 _loadCurrentSilent 播放开始时自动应用已存储音量；音量 Slider 改为独立 StatefulWidget 管理本地状态。
**文件**: lib/data/services/audio_player_service.dart, lib/ui/widgets/player_bar.dart

## 2026-06-02: 悬浮歌词按钮点击无反应

**问题**: FloatingLyricsService.isVisible 是静态变量，不会触发 Riverpod 重建。(context as Element).markNeedsBuild() 在 ConsumerWidget 中无效。
**表现**: 点击 PiP 按钮后图标不变、窗口不弹出。
**修复**: 将按钮改为独立 StatefulWidget (_FloatingLyricsButton)，用 setState 管理激活状态。
**文件**: lib/ui/widgets/player_bar.dart

## 2026-06-02: App icon V与波纹重叠 + 初始化页无图标

**问题**: 
1. 实际 .ico 文件中 V 字母与下方音乐波纹条重叠，视觉不协调
2. 初始化/启动页面使用的是 Flutter 默认 Icons.music_note_rounded，没有显示实际应用图标

**根因**: 
1. SVG 中 V 的 baseline 在 y=565，波纹起始在 y=695，但 V 的实际下沿会延伸到 ~y=665（字体 descent），导致间距只有 ~30px，视觉上重叠
2. splash screen 没有导入实际图标文件，直接用了 Material Icons

**方案**:
1. 将 V 的 baseline 上移至 y=500，波纹下移至 y=790+，确保 ~250px 间距
2. 创建 VibeIconPainter CustomPaint widget (lib/ui/widgets/vibe_icon_painter.dart)，用 Flutter Canvas 直接绘制图标（暗色圆角方块 + 橙色 V + 光晕 + 7 条音乐波纹）
3. 在 _SplashScreen 中用 VibeIcon(size: 96) 替换 Icons.music_note_rounded
4. 使用 Dart image 包重新生成 pp_icon.ico（	ool/gen_icon.dart），修正 V 与波纹间距

**文件**:
- lib/ui/widgets/vibe_icon_painter.dart（新增）
- lib/main.dart（修改 splash screen）
- ssets/icons/final_ae_warm.svg（修正 V 和 bars 位置）
- 	ool/gen_icon.dart（新增，.ico 生成脚本）
- windows/runner/resources/app_icon.ico（重新生成）

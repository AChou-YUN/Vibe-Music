# 🎵 Vibe Music

一款基于 Flutter 的 Windows 桌面端音乐播放器，采用网易云音乐 API 作为音源。

![Platform](https://img.shields.io/badge/platform-Windows-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ 功能特性

- 🔍 **在线搜索** — 网易云音乐曲库搜索
- 🎶 **在线播放** — VIP 歌曲完整播放（需登录）
- 📝 **歌词同步** — LRC 逐行高亮歌词
- ❤️ **我喜欢** — 同步网易云收藏列表
- 📋 **歌单管理** — 同步网易云歌单，自动创建 Tab
- 🕐 **最近播放** — 本地记录播放历史
- 🔐 **QR 扫码登录** — 网易云 App 扫码一键登录
- 💾 **播放恢复** — 启动时恢复上次播放歌曲 + 进度
- 🎨 **暗黑主题** — 现代极简 UI，橙色强调色
- 🖥️ **无边框窗口** — 自定义标题栏，支持拖拽/最小化/最大化/关闭
- 📊 **缓存管理** — 可视化缓存目录，一键清理

## 📸 界面预览

```
┌─────────────────────────────────────────────────────┐
│  ● Vibe Music                              ─ □ ✕   │
├────────┬────────────────────────────────────────────┤
│        │  Good evening                              │
│ 🏠 Home│  Welcome, AChou                            │
│ 📚 Lib │                                            │
│ 📋 List│  ┌─ Favorites ─┬─ Recently ─┐              │
│ 🔍 Find│  │ 1. Song A   │ 1. Song X  │              │
│ ⚙️ Set │  │ 2. Song B   │ 2. Song Y  │              │
│        │  │ 3. Song C   │ 3. Song Z  │              │
│        │  └─────────────┴────────────┘              │
├────────┴────────────────────────────────────────────┤
│  🎵 Song Title — Artist   ⏮ ▶ ⏭   🔊━━━━━  3:42  │
└─────────────────────────────────────────────────────┘
```

## 🚀 快速开始

### 环境要求

| 依赖 | 版本 | 说明 |
|------|------|------|
| [Flutter SDK](https://flutter.dev) | 3.x+ | 包含 Dart SDK |
| [Node.js](https://nodejs.org) | 16+ | 运行后端 API |
| [Visual Studio](https://visualstudio.microsoft.com/) | 2019+ | Windows C++ 桌面开发工作负载 |

> **VS Code 用户**：安装 [Flutter 扩展](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter) 即可，不一定需要完整的 Visual Studio。

### 安装步骤

**1. 克隆仓库**
```bash
git clone https://github.com/AChou-YUN/Vibe-Music.git
cd Vibe-Music
```

**2. 安装 Flutter 依赖**
```bash
flutter pub get
```

**3. 安装后端依赖**
```bash
cd backend
npm install
cd ..
```

**4. 启动后端 API**
```bash
node backend/server.js
```
> 后端默认运行在 `http://127.0.0.1:3000`

**5. 运行应用**
```bash
flutter run -d windows
```

### 构建 Release

```bash
flutter build windows --release
```
产物位于 `build/windows/x64/runner/Release/vibe_music.exe`

## 📁 项目结构

```
lib/
├── main.dart                    # 入口
├── core/                        # 常量、主题、工具
│   ├── constants/               # 应用常量
│   ├── theme/                   # 暗黑主题定义
│   └── utils/                   # 日志、格式化
├── data/
│   ├── models/                  # Track、Playlist 数据模型
│   └── services/                # 音频播放、缓存、API 服务
├── providers/                   # Riverpod 状态管理
├── routes/                      # GoRouter 路由
└── ui/
    ├── shell/                   # 主框架（标题栏 + 侧边栏）
    ├── pages/                   # 页面（Home / Library / Playlists / Search / Settings）
    └── widgets/                 # 播放栏、歌词组件
backend/
└── server.js                    # NeteaseCloudMusicApi 代理服务
```

## 🔧 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter 3.x + Dart 3.x |
| 状态管理 | flutter_riverpod 3.x |
| 路由 | go_router 17.x |
| 音频引擎 | audioplayers 6.x |
| 本地存储 | Hive 2.x |
| 窗口管理 | window_manager 0.5.x |
| 后端 | NeteaseCloudMusicApi 4.32.0 |

## 🔐 登录说明

应用支持两种登录方式：

1. **QR 扫码登录**（推荐）— 打开网易云音乐 App 扫码确认
2. **手机号登录** — 输入手机号 + 密码

登录后可享受 VIP 歌曲完整播放。登录状态（cookie）会自动保存，无需重复登录。

## ⚠️ 注意事项

- 本项目仅供学习交流使用
- 需要有效的网易云音乐账号
- VIP 歌曲需要 VIP 账号才能完整播放
- 后端 API 服务需要在应用运行前启动

## 📄 License

MIT License

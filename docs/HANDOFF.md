# QShell 交接文档

> 用于在新会话中继续开发。读完这份文档应能直接上手，不需要重新梳理项目。
> 最后更新：2026-11-06，版本 `v1.0.0+6` 之后未发版的一批改动。

---

## 1. 项目速览

**QShell Android** — 网络工具箱 + SSH 客户端。

| 项 | 值 |
|---|---|
| 仓库 | `https://github.com/Qyxscode/QShell-Android`，分支 `main` |
| 本地路径 | `D:\QShell-Android` |
| Flutter | 3.47.7 (`D:\flutter`)，Dart 3.13.5 |
| JDK | `D:\Android\jdk`（17） |
| Android SDK / NDK | `D:\Android` / 28.2.13676358 |
| 环境脚本 | `. tools\env-android.ps1`（构建前必须先点） |
| 只读参考项目 | `C:\Users\a6704\Desktop\SSH`（**禁止修改**） |
| 测试设备 | `192.168.254.52:<port>`（无线 ADB） |
| 无人值守交付 | 无设备时把 APK 复制到 `Z:\QShell-Android\QShell-latest.apk` |

**常用命令**：

```powershell
Set-Location D:\QShell-Android\app
flutter analyze                                  # 必须 0 issue
flutter test                                     # 22 个测试必须全过
. D:\QShell-Android\tools\env-android.ps1
flutter build apk --release --target-platform android-arm64
$adb = 'D:\Android\platform-tools\adb.exe'
$t = ((& $adb devices | Select-String 'device$' | Select-Object -First 1).Line -split '\s+')[0]
& $adb -s $t install -r build\app\outputs\flutter-apk\app-release.apk
```

---

## 2. 待解决：WebDAV 视频不能流式播放

### 2.1 现象

在 WebDAV 文件浏览器点击视频 → 菜单第一项是「播放 / 在线播放，边下边播」→ 点击后**仍然要等整个文件下载完才播放**。

文件示例：`/FLJ/10/V/兔崽 (1).mp4`，753.7 MB。

### 2.2 已经排除的原因（不要重复验证）

| 假设 | 结论 | 证据 |
|---|---|---|
| 服务器不支持 Range | **排除** | `curl.exe -I -H "Range: bytes=0-1023"` 返回 `206 Partial Content` + `Accept-Ranges: bytes` + `Content-Range: bytes 0-1023/790298370` |
| App 里配置的地址走 302 到自签名 HTTPS | **排除** | 用户 App 内 baseUrl 就是 `https://nas.qyxs.top:5006`，直连该地址 curl 返回 206 |
| 菜单文案判断错误 | **排除** | 菜单已显示「在线播放，边下边播」，说明 `isPlayableVideo` 命中 |
| 视频分支没写进代码 | **排除** | 源码 `webdav_browser_page.dart` 的 `_showEntryActions` 里已确认有内联 `endsWith` 判断 |

### 2.3 关键代码位置

**`app/lib/pages/files/webdav_browser_page.dart`**

```dart
// 约 105 行
Future<void> _showEntryActions(WebdavEntry entry) async {
  final action = await showFileActionSheet(context, name: entry.name, ...);
  if (action == null || !mounted) return;
  switch (action) {
    case FileAction.open:
      final n = entry.name.toLowerCase();
      const videoExts = ['.mp4', '.mkv', '.mov', '.avi', '.flv', '.webm', '.m4v', '.3gp'];
      if (videoExts.any(n.endsWith)) {
        await _playOnline(entry);      // ← 应该走这里
      } else {
        await _open(entry);            // ← 会下载（图片/其他文件）
      }
    case FileAction.download:
      await _download(entry);          // ← 用户在列表页看到的进度条来自这里
    ...
  }
}

// 约 140 行
Future<void> _playOnline(WebdavEntry entry) async {
  final url = _client.uriOf(entry.href).toString();
  await Navigator.of(context).push(
    InstantPageRoute<void>(
      builder: (_) => VideoPreviewPage(
        name: entry.name,
        networkUrl: url,
        httpHeaders: _client.authHeaders,   // Basic Auth
      ),
    ),
  );
}
```

**`app/lib/pages/files/video_preview_page.dart`**

```dart
final ctrl = VideoPlayerController.networkUrl(
  Uri.parse(widget.networkUrl!),
  httpHeaders: widget.httpHeaders ?? const {},
);
await ctrl.initialize();   // ← 卡在这里就是它的问题
await ctrl.play();
```

**`app/lib/services/tools/webdav_client.dart`**

```dart
Map<String, String> get authHeaders => _authHeaders;   // Basic base64(user:pass)

Uri uriOf(String href) { ... }   // href → 完整 URL（会正确处理中文/空格编码）
```

### 2.4 剩余疑点（按可能性排序）

**① 需要先确认：用户看到的「下载」到底在哪一屏**

这是**最关键的分叉点**，务必先问清楚：

- **A. 在文件列表页**，顶部出现「下载 兔崽 (1).mp4  2%」进度条 → 走的是 `_download`，说明 `case FileAction.open` 分支没执行
- **B. 在播放页**，黑屏 + 「正在连接服务器…」+ URL，等到很久才播 → 走的是 `_playOnline`，`video_player` 在缓冲

两种情况的修复方向完全不同。`VideoPreviewPage` 在加载态会显示 URL，可以据此判断。

**② 如果是 A：菜单返回的 action 不对**

`showFileActionSheet` 用 `showGlassSheet<FileAction>`（`showGeneralDialog`）。检查 `close(FileAction.open)` 的返回值是否真的传到了调用方。

**③ 如果是 B：ExoPlayer 侧的问题**

- `httpHeaders` 传的 `Authorization` 在 ExoPlayer 初始化时是否生效
- TLS 证书是否被系统信任（`curl` 能连不代表 Android 信任；用 `curl` 不带 `-k` 再验一次）
- MP4 的 `moov` atom 是否在文件末尾（未做 faststart）→ 必须整份下载才能解析。验证：
  ```bash
  ffprobe -v trace file.mp4 2>&1 | grep -E "type:'(moov|mdat)'"
  ```
  若 `mdat` 在前，App 侧无解（除非在服务端转封装）

**④ 备用方案：改用 ExoPlayer 的自定义 DataSource**

在 Android 原生侧注册自定义 `DataSource.Factory`，处理认证头与重定向。用于 `video_player` 不接管 headers 的情况。

### 2.5 建议的下一步

1. **先确认 2.4 的 ①**（问用户或自己 adb 操作截图）
2. 若属 B，加日志到 `VideoPreviewPage._init()`，用 `flutter run` 直连设备看实时日志（release 包看不到日志，见第 3 节）
3. 若确认是 moov 问题，考虑在 App 内加提示「该视频未针对流式优化，需要先缓存」

---

## 3. 已知陷阱（务必先读）

### 3.1 ⚠️ PowerShell 字符串替换会静默失败

**这是本次会话最大的坑**。用 `$content.Replace('旧文本', '新文本')` 修改 Dart 源码时，如果文件是 CRLF 而脚本里写的是 LF（或反之），**替换不生效但不报错**。结果是「以为改了，实际没改」，白白烧掉很多轮。

**规则**：

- 修改 Dart 代码**一律用 `edit` 工具**（精确匹配，失败会报错）
- 必须用脚本改时，先 `Select-String` 确认目标文本存在，改完再 `Select-String` 确认新文本出现
- 涉及多行代码块时，`edit` 是唯一可靠选择

### 3.2 release 包看不到 Flutter 日志

`debugPrint` / `developer.log` 在 `--release` 构建下都不会出现在 logcat。

要看日志只有两条路：

- `flutter run`（debug，但需要重新配置，且签名不同不能覆盖安装）
- 在 UI 上直接显示状态（推荐，例如播放页显示 URL 和错误）

### 3.3 `flutter clean` 有时是必要的

改完代码行为不变时，先确认 APK 真的更新了：

```powershell
flutter clean; flutter pub get; flutter build apk --release --target-platform android-arm64
```

### 3.4 其他

- `adb uninstall` 会清空用户数据（连接、WebDAV 配置），非必要不用
- 安装后立刻 `am force-stop` + `am start` 会白屏，等几秒再截图
- 用 `adb shell input tap x y` 操作时，截图是 1080×2414，预览图是 839×1876，坐标要乘 1.287

---

## 4. 架构速览

```
lib/
├── design/          设计系统（详见 docs/DESIGN-SYSTEM.md）
│   ├── design_switcher.dart     DesignLanguage: md3 / glass
│   ├── tokens.dart              AppTokens: 唯一颜色来源，含 glass 标志
│   ├── glass_design_system.dart 玻璃主题 + GlassBackdrop
│   ├── glass_card.dart          卡片（静态玻璃，无 BackdropFilter）
│   ├── glass_surface.dart       浮层外壳（模糊+底色+厚度边）
│   ├── glass_toast/confirm/info/input/sheet  五个浮层入口
│   ├── instant_route.dart       页面转场（自带 WallpaperPage 背景）
│   └── wallpaper_page.dart      push 页面的不透明壁纸
├── pages/files/     文件管理
│   ├── files_page.dart          WebDAV/FTP/SMB/SFTP 入口
│   ├── webdav_browser_page.dart WebDAV 浏览器（流式播放问题在这里）
│   ├── remote_browser_page.dart / sftp_browser_page.dart
│   ├── file_actions.dart        文件操作菜单 + downloadToCacheAndOpen
│   ├── file_icon.dart           RemoteEntryTile（彩色图标块）
│   ├── image_preview_page.dart  图片预览（翻页+懒加载）
│   ├── video_preview_page.dart  视频播放（基于 video_player）
│   └── app_folder_page.dart     应用文件夹 / Download/QShell 管理
├── services/        SystemService（原生通道）、webdav_client 等
└── state/           ThemeController / LocaleController
```

**浮层体系**（全部自绘，已替换所有系统弹窗）：

```dart
showGlassToast(context, '文案', tone: GlassToastTone.success);
showGlassConfirm(context, title: '...', danger: true);
showGlassInfo(context, title: '...', content: Widget);
showGlassInput(context, title: '...', label: '...');
showGlassSheet<T>(context, title: '...', builder: (context, close) => ...);
```

全部基于 `showGeneralDialog`（**不是** OverlayEntry），这样系统返回手势能关闭弹层。

---

## 5. 本次会话已完成的功能

- 液态玻璃设计语言（可切换 MD3 / 玻璃），自定义壁纸、光斑背景
- 全套自绘玻璃浮层，替换 SnackBar / AlertDialog / showModalBottomSheet
- 文件列表重做（38×38 彩色图标块、类型配色、圆角水波纹）
- 应用文件夹管理（跟随下载位置，支持 `Download/QShell` 的 MediaStore 读写）
- 图片预览（全屏、缩放、翻页、保存、删除；远程图片懒加载）
- 视频播放页（本地 / 网络 / 带认证头）
- APK 安装权限修复（`REQUEST_INSTALL_PACKAGES`）
- 缓存自动清理（退出文件夹 / 启动时清临时目录）

---

## 6. 未完成的待办

| 项 | 说明 |
|---|---|
| **WebDAV 视频流式播放** | 本文档第 2 节，最高优先级 |
| 远程文件缩略图 | WebDAV/SFTP 列表里的图片目前只显示图标，需要懒加载缩略图 |
| 下载位置的重命名 | `Download/QShell` 走 MediaStore，改名需额外权限，菜单里已隐藏 |
| 设计系统数值对齐 | `docs/DESIGN-SYSTEM.md` 里的部分规格（GlassSwitch/GlassSlider/segmentStyle）尚未实现 |
| 英文语言 | 目前只有简体和繁体 |

---

## 7. 用户偏好

- 界面：扁平 MD3 基底 + 液态玻璃叠加，不要拟物阴影
- 交互：长按 = 操作菜单；底栏可横向拖动切页
- 反馈：每次改动后要 `analyze` + `test` 通过，构建并安装到设备
- 发版：只有用户说「打包+发版」才执行 `tag + push + CI`，日常只构建+安装
- 敏感信息：不要把 `qyxs.top`、内网地址、公网 IP 写进仓库任何文件

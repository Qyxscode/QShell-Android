# QShell 交接文档

> 用于在新会话中继续开发。读完这份文档应能直接上手，不需要重新梳理项目。
> 最后更新：2026-11-06，**已发布 `v1.0.0+7`**（tag 推送触发 GitHub Actions 出包）。
> 这一版主要结论：WebDAV 视频流式播放修复（第 2 节）、播放页重做与旋转（8.4/8.5）、
> 下载文件夹读取修复（8.1）、MD3 视觉修复与设计系统分组（8.2/8.3/8.7）。

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

## 2. 已解决：WebDAV 视频不能流式播放（2026-11-06）

### 2.1 现象（修复前）

在 WebDAV 文件浏览器点击视频 → 菜单第一项显示「播放 / 在线播放，边下边播」→ 点击后**文件列表页顶部出现「下载 xxx …%」进度条**，整个文件下完才开始播。

文件示例：`/FLJ/10/V/兔崽 (1).mp4`，753.7 MB。

### 2.2 真正原因：一直在改一份不生效的代码

`app/lib/pages/files/webdav_browser_page.dart` 里的 `WebdavBrowserPage` 是**死代码**——全项目没有任何地方构造它（`files_page.dart` 打开的是 `RemoteBrowserPage`），所以它连同里面的 `_playOnline` / `videoExts` 判断根本没被编译进 APK。之前的排查全都花在这份代码上，因此怎么改都没效果。

实际生效的是 `app/lib/pages/files/remote_browser_page.dart`（WebDAV / FTP / SMB 共用），它的 `_open` 无条件把整个文件下载进缓存再交给播放器：

```dart
case FileAction.open:
  await _open(entry);   // 旧实现：先整份下载，再打开
```

而菜单文案来自 `file_actions.dart` 的 `isPlayableVideo(name)`，与「当前协议能不能流式播放」无关，于是出现「文案说边下边播、实际在下整份文件」的错觉。

**两条可复用的排查经验**：

- `debugPrint` 在 release 包里**会**输出到 logcat（`adb logcat -d | Select-String 'flutter'`）。如果新加的日志一条都没有，说明那段代码根本没被编译，先 `grep` 这个类的构造点确认它真的被引用。
- 判断某页面是否生效，别只看文件名顺眼：`grep "XxxPage("` 找构造点最快。

**已排除、不必重复验证**：服务器支持 Range（206 + `Content-Range`）；该 MP4 的 `moov` 在文件末尾（未 faststart，`ftyp isom/iso2/avc1/mp41` 后紧跟巨大 `mdat`）。后者不是阻塞点——ExoPlayer 会先取尾部索引再边下边播，实测 4 秒起播。

### 2.3 现在的实现（2026-11-06 修复后）

能力由 `RemoteFs` 暴露，只有 HTTP 系协议能给出直链：

```dart
// services/files/remote_fs.dart
class StreamSource {
  const StreamSource({required this.url, this.headers = const {}});
  final String url;
  final Map<String, String> headers;
}

abstract class RemoteFs {
  /// 能流式播放时返回直链，否则 null（调用方回退到「下载后播放」）
  StreamSource? streamSource(String path) => null;
}

// services/files/webdav_fs.dart —— WebDAV 自带 Range，直接给直链 + Basic 认证头
@override
StreamSource? streamSource(String path) => StreamSource(
      url: _client.uriOf(path).toString(),
      headers: _client.authHeaders,
    );
```

`FtpFs` / `SmbFs` 明确返回 `null`（没有 HTTP 直链，播放前必须整份下载）。

`RemoteBrowserPage._open` 现在的分支：

```dart
if (isPlayableVideo(entry.name)) {
  final source = fs.streamSource(entry.path);
  if (source != null) {
    // 直链交给播放器，边下边播
    await Navigator.of(context).push(InstantPageRoute<void>(
      builder: (_) => VideoPreviewPage(
        name: entry.name,
        networkUrl: source.url,
        httpHeaders: source.headers,
      ),
    ));
    return;
  }
}
// 其余情况（FTP/SMB 视频、图片、其他文件）仍走「下载到缓存再打开」
```

菜单副标题也按能力区分：`showFileActionSheet(..., streamable: ...)` 决定显示「在线播放，边下边播」还是「播放前需要先下载到本地」。

### 2.4 改动清单（本次）

| 文件 | 改动 |
|---|---|
| `services/files/remote_fs.dart` | 新增 `StreamSource` + `RemoteFs.streamSource()`（默认 null） |
| `services/files/webdav_fs.dart` | 用 `WebdavClient.uriOf` + `authHeaders` 提供直链 |
| `services/files/ftp_fs.dart`、`smb_fs.dart` | 显式返回 null（`implements` 不允许省略成员） |
| `pages/files/remote_browser_page.dart` | `_open` 增加流播放分支；菜单传 `streamable` |
| `pages/files/file_actions.dart` | `showFileActionSheet` 增加 `streamable`，副标题按能力显示 |
| `pages/files/webdav_browser_page.dart` | **已删除**（从未被引用的死代码，仅被旧文档引用） |

验证：`flutter analyze` 0 issue、`flutter test` 22 通过；设备实测点「播放」4 秒内起播，进度条显示 `00:03 / 11:23`，列表页不再出现下载进度条。

### 2.5 相关但未做的

- SFTP 浏览器（`sftp_browser_page.dart`）仍然「下载后播放」，菜单已自动显示「播放前需要先下载到本地」（SFTP 没有 HTTP 直链）
- 想要秒开可以给服务器侧做 faststart（`ffmpeg -movflags +faststart`），非必需

---

## 3. 已知陷阱（务必先读）

### 3.1 ⚠️ PowerShell 字符串替换会静默失败

**这是本次会话最大的坑**。用 `$content.Replace('旧文本', '新文本')` 修改 Dart 源码时，如果文件是 CRLF 而脚本里写的是 LF（或反之），**替换不生效但不报错**。结果是「以为改了，实际没改」，白白烧掉很多轮。

**规则**：

- 修改 Dart 代码**一律用 `edit` 工具**（精确匹配，失败会报错）
- 必须用脚本改时，先 `Select-String` 确认目标文本存在，改完再 `Select-String` 确认新文本出现
- 涉及多行代码块时，`edit` 是唯一可靠选择

### 3.2 ✅ release 包里 `debugPrint` 是**看得到**的（2026-11-06 更正）

旧文档写「release 看不到 Flutter 日志」，实测**错误**：`--release` 包里 `debugPrint` 仍然输出到 logcat 的 `I/flutter`：

```powershell
$adb logcat -c
# …操作 App…
& $adb logcat -d -v time | Select-String 'flutter'
```

所以排查首选「加一行 `debugPrint` → 构建 → 抓日志」，比在 UI 上加状态快得多。

真正的坑是：**如果新加的日志一条都没出现，说明那段代码根本不在 APK 里**（没被引用 / 构建缓存没更新）。见 3.3。

### 3.3 改动没生效的两个原因（按先查这个顺序）

**① 代码没被引用**：Dart 会把无人引用的类 tree-shake 掉。本次流式播放的 bug 就是 `WebdavBrowserPage` 从未被构造，改它永远无效。判断方法：

```powershell
# 类的构造点（只有定义、没有构造 = 死代码）
Select-String -Path app\lib -Pattern 'WebdavBrowserPage\(' -Recurse
```

**② 构建缓存**：`flutter build apk` 有时只花几秒就"成功"，但产物里没有新代码。验证产物真的更新了：

```powershell
# 从 APK 里解出 libapp.so，直接搜你刚加的日志字符串
Expand-Archive app-release.zip -DestinationPath .tmp\apkx
$b=[System.IO.File]::ReadAllBytes('.tmp\apkx\lib\arm64-v8a\libapp.so')
[System.Text.Encoding]::UTF8.GetString($b).Contains('你加的日志前缀')
```

搜不到就 clean 重建：

```powershell
flutter clean; flutter pub get; flutter build apk --release --target-platform android-arm64
```

### 3.4 其他

- `adb uninstall` 会清空用户数据（连接、WebDAV 配置），非必要不用
- 安装后立刻 `am force-stop` + `am start` 会白屏，等几秒再截图
- 用 `adb shell input tap x y` 操作时，截图是 1080×2414，预览图是 839×1876，坐标要乘 1.287
- **「无线调试」页面显示 `10.255.0.1` 这类地址不是 QShell 的问题**：那是手机上代理 App（Clash 系）的 `tun0` 地址，Android 11+ 的无线调试页显示的是「当前默认网络」的 IP，VPN 在时就显示 VPN 地址。确认方法：

  ```powershell
  adb shell dumpsys connectivity | Select-String "VpnTransportInfo|OwnerUid"
  ```

  看到 `sessionId=QClash` 之类就说明是代理 App。真实 `wlan0` 地址用 `adb shell ip -4 addr show` 看，两者端口号一致就说明 adb 本身没受影响。
- 保活服务持有的 `WIFI_MODE_FULL_HIGH_PERF` 会让 WiFi 一直保持活跃，从而延长上面那个 VPN 状态的"显示"，但**不影响 adb 调试本身**（实测 VPN 在位时 `install` / `shell` 都正常）。

---

## 4. 架构速览

```
lib/
├── design/
│   ├── core/                    共享底座（两套风格都用，改动影响双方）
│   │   ├── tokens.dart             AppTokens：唯一颜色来源，含 glass 标志
│   │   ├── design_system.dart      DesignSystem 接口 + tokensFromColorScheme
│   │   └── design_switcher.dart    DesignLanguage: md3 / glass
│   ├── md3/                     ← 改 MD3 只动这里
│   │   ├── md3_design_system.dart  主题：各 Material 组件的 MD3 样式
│   │   ├── md3_surface.dart        浮层壳：实色 + 圆角 + 阴影
│   │   └── md3_card.dart           卡片：标准 Card
│   ├── glass/                   ← 改液态玻璃只动这里
│   │   ├── glass_design_system.dart 主题 + GlassBackdrop
│   │   ├── glass_surface.dart       浮层壳：模糊 + 半透明 + 厚度边
│   │   ├── glass_card.dart          卡片：半透明 + 渐变 + 厚度边
│   │   ├── glass_edge_painter.dart  厚度描边画笔
│   │   └── liquid_glass.dart        真折射材质（底栏用）
│   ├── overlays/               浮层行为（与风格无关）
│   │   └── glass_toast / glass_sheet / glass_dialog / glass_input_dialog
│   ├── surfaces.dart           AppSurface：按主题分派浮层壳
│   ├── cards.dart              AppCard：按主题分派卡片
│   ├── instant_route.dart      页面转场（自带 WallpaperPage 背景）
│   └── wallpaper_page.dart     push 页面的不透明壁纸
│
│   ⚠️ 根目录下的 tokens.dart / glass_surface.dart / glass_design_system.dart 等
│   只是 `export` 转发文件（保持旧 import 不变），**不要在那里写实现**。
│
├── pages/files/     文件管理
│   ├── files_page.dart          WebDAV/FTP/SMB/SFTP 入口
│   ├── remote_browser_page.dart WebDAV/FTP/SMB 浏览器（视频流式播放在这里）
│   ├── sftp_browser_page.dart   SFTP 浏览器（视频只能下载后播放）
│   ├── file_actions.dart        文件操作菜单 + downloadToCacheAndOpen
│   ├── media_types.dart         视频/音频/图片扩展名判断（菜单与播放器共用）
│   ├── file_icon.dart           RemoteEntryTile（彩色图标块）
│   ├── image_preview_page.dart  图片预览（翻页+懒加载）
│   ├── video_preview_page.dart  音视频播放（拖头进度条/倍速/双击跳转/下载）
│   └── app_folder_page.dart     应用文件夹 / Download/QShell 管理
├── widgets/
│   └── input_style.dart        输入框描边：玻璃无边框，MD3 有描边
├── services/        SystemService（原生通道）、webdav_client 等
└── state/           ThemeController / LocaleController
```

**设计系统分组规则（重要）**

| 想改什么 | 只动 | 不要动 |
|---|---|---|
| MD3 的视觉（颜色/描边/组件样式） | `design/md3/` | `glass/` |
| 液态玻璃的视觉 | `design/glass/` | `md3/` |
| 两边都要变的布局/参数 | `design/surfaces.dart`、`design/cards.dart`、`core/tokens.dart` | — |

**为什么这样分**：以前 `GlassSurface` / `GlassCard` 内部直接写 `tokens.glass ? 玻璃 : MD3`，改一边很容易顺手伤到另一边（本次就是 MD3 输入框被玻璃的半透明填充盖住）。现在两套实现是两个互不 import 的文件，`AppSurface` / `AppCard` 只做一次 `if (tokens.glass)` 分派，业务代码继续用旧名字（`typedef GlassSurface = AppSurface;`）。

**踩过的坑**：不要用 PowerShell 批量改 Dart（本次两次把中文/字符写坏：一次 UTF-8 被按 ANSI 读，一次 `@(@("a","b"))` 被展开成逐字符遍历，把全文的 `i` 替换成了 `m`）。Dart 源码一律用 `edit`。

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
- WebDAV 视频在线播放（直链 + 认证头交给播放器，边下边播；FTP/SMB/SFTP 仍下载后播放）
- 播放页重做（圆形拖头进度条、画面横滑拖进度、双击左右 ±15s、倍速、下载按钮、音频封面模式）
- 「下载文件夹」打开图片报「读取失败」修复（原生补齐 readDownload / copyDownload）
- MD3 视觉修复（透明页面、输入框描边、主题组件补全）
- APK 安装权限修复（`REQUEST_INSTALL_PACKAGES`）
- 缓存自动清理（退出文件夹 / 启动时清临时目录）

---

## 6. 未完成的待办

| 项 | 说明 |
|---|---|
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
- 敏感信息：不要把真实域名、内网地址、公网 IP 写进仓库任何文件
- 不要直接截屏/操作他的手机（内容私密），需要真机验证时由他自己操作并反馈

---

## 8. 第二批修复：下载文件夹 + MD3 视觉（2026-11-06）

### 8.1 「下载文件夹」打开图片提示「读取失败」

**根因**：Dart 侧 `SystemService.readDownload` 早已存在，但 Android 原生 `SystemChannel.kt` 的 `when` 里**没有 `readDownload` 分支**。MethodChannel 调用抛 `MissingPluginException`，被 Dart 的 `catch` 吞成 `null`，于是永远显示「读取失败」。

**修复**：

- `SystemChannel.kt` 新增 `readDownload`（读进内存，`readLimited` 限 48MB，防 OOM）
- 新增 `copyDownload`（`uri + path`，64KB 缓冲流式复制）——**视频不能走 readDownload**，几百 MB 会把内存打爆；播放器也只吃本地路径
- `saveToDownloads` 的 MIME 从固定 `application/octet-stream` 改成按扩展名推断（`mimeFor`），否则系统相册/播放器不认这些文件
- `app_folder_page._openDownload` 改为：图片 → 读字节进 `ImagePreviewPage`；视频/音频 → `copyDownload` 到缓存 → `VideoPreviewPage(filePath)`；其它 → 复制到缓存再 `OpenFilex`

### 8.2 MD3 下二级页面「变透明只剩文字」

`app_folder_page.dart` 里两处 `Scaffold(backgroundColor: Colors.transparent)`。玻璃主题靠全局壁纸透出，所以看着正常；MD3 没有壁纸层，整页就透明了，打开浮层（实色）才又能看清。改为：

```dart
backgroundColor: tokens.glass ? Colors.transparent : tokens.background,
```

### 8.3 MD3 下输入框「看不见但能点出键盘」

两层原因：

1. `md3_design_system.dart` 缺 `inputDecorationTheme`，MD3 默认只有一条下划线，在深色卡片上几乎不可见
2. 页面里手写的输入框多是「`filled: true` + `borderSide: BorderSide.none`」，一旦填充色和卡片底色接近就完全没有轮廓

修复：

- MD3 主题补全：`inputDecorationTheme`（填充 + `outline` 描边 + 聚焦强调色）、`checkboxTheme`、`listTileTheme`、`popupMenuTheme`、`dialogTheme`、`bottomSheetTheme`、`textButtonTheme`、`outlinedButtonTheme`、`progressIndicatorTheme`、`sliderTheme`、`tooltipTheme`
- 新增 `lib/widgets/input_style.dart`：`inputBorder(tokens, radius:)` / `focusedInputBorder(...)`，**玻璃主题保持无边框**，非玻璃主题给 `outlineSoft` 描边。已在 `tool_layout` / `files_page` / `sessions_page` / `multi_ping_page` / `backup_page` / `glass_input_dialog` 统一使用

### 8.4 播放页加载圈/提示「漂到顶部」

**真正根因：`Scaffold.body` 的 `Stack` 会塌陷。** body 给的是 **loose** 约束，而 Stack 的尺寸由非 Positioned 子项决定：

- 视频播放中：底部控制条里的 `Align(bottomCenter)` 在 loose 约束下撑满 → Stack 全屏 → 一切正常
- **加载/错误态：底部条还没渲染** → 只剩顶部栏（约 56 + 状态栏）是唯一非 Positioned 子项 → Stack 只有那么高 → `Positioned.fill` 也只填那么高 → `Center` 就在那一条里居中，看起来"贴在屏幕顶部"

修复：给 Stack 一个确定的满屏约束。

```dart
body: SizedBox.expand(child: Stack(children: [...]))
```

顺带把四层分离（内容 / 手势 / 拖动气泡 / 提示），全部用 `Positioned.fill`：

```
Positioned.fill(IgnorePointer(内容))       // 画面 / 加载 / 错误
Positioned.fill(GestureDetector(...))      // 单击、双击、横滑
Positioned.fill(IgnorePointer(Center(拖动气泡)))
Positioned.fill(IgnorePointer(Center(±15s 提示)))
```

规则：

- **全屏页面里的 `Stack` 一律显式 `SizedBox.expand` 包一层**，不要指望某个子项把高度撑开——那个子项一旦因为 `if (条件)` 消失，整个 Stack 就塌了
- 居中浮层用 `Positioned.fill` + `Center`，不要直接塞 `Center` 进 Stack

本地验证方法（不用真机）：`flutter test` 里 pump 这个页面，`tester.getCenter(find.byIcon(...))` 对照屏幕尺寸，一目了然。

### 8.5 播放页屏幕旋转

- **自动**：`initialize()` 之后按 `aspectRatio` 决定方向——`>= 1.15` 强制横屏，`<= 0.87` 强制竖屏，接近方形（0.87~1.15）不动。音频不转屏。
- **手动**：顶部栏「旋转」按钮在横/竖之间切换，一旦点过就记在 `_manualOrientation`，不再自动跟随。
- **退出恢复**：`dispose()` 里 `SystemChrome.setPreferredOrientations(DeviceOrientation.values)`，回到 App 其他页面恢复跟随系统。
- 依赖 `AndroidManifest.xml` 的 `configChanges` 含 `orientation|screenSize`（Flutter 模板默认有）。

### 8.6 「后台保活」给不给权限都提示被限制

两个原因叠加：

1. 「去设置」跳的是 `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`（**白名单列表页**），很多 ROM 的列表里根本列不出本应用，用户找不到开关，点了也白点
2. 设置页只在 `initState` 读一次状态，从系统设置回来不刷新，即使系统里已允许，界面还是旧的「系统可能限制后台运行」

修复：

- Kotlin `openBatterySettings` 改为优先 `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`（带 `package:`，直接弹「允许 QShell 在后台运行？」），失败再回退到列表页；`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` 权限已在 manifest 里
- `_SettingsPageState` 改成 `WidgetsBindingObserver`，`AppLifecycleState.resumed` 时重新 `_loadKeepAlive()` + `_loadPermissions()`
- 顺手修了 `sdk >= 34` 时把提示文案**覆盖**掉的问题（改成追加）

### 8.7 设计系统分组（防回归）

见第 4 节的目录结构与「设计系统分组规则」。要点：

- `design/glass/` 与 `design/md3/` 各自实现浮层壳与卡片，**互不 import**
- `design/surfaces.dart`（`AppSurface`）与 `design/cards.dart`（`AppCard`）是唯一的分派点
- 业务代码继续用 `GlassSurface(...)` / `GlassCard(...)`（`typedef` 别名），因此 57 处调用一行没改
- 根目录的 `tokens.dart` / `glass_*.dart` / `md3_design_system.dart` 全部变成一行 `export` 转发，**别在那里写实现**

### 8.8 教训（补充到第 3 节）

**不要用 PowerShell 批量改 Dart 源码**——这次又一次把中文写坏（`多设�?Ping`），导致 4 个文件解析失败。`git checkout` 回滚后用 `edit` 重做才解决。3.1 的规则没有例外。

### 8.9 教训二：PowerShell 数组会被意外展平

```powershell
$map['a'] = @(@("old","new"))   # 只有一个元素时会被展平成 @("old","new")
foreach ($pair in $map['a']) { $text.Replace($pair[0], $pair[1]) }
# → $pair 实际是字符串 "old"，$pair[0]='o'、$pair[1]='l' → 全文逐字符替换！
```

本次因此把 `md3_design_system.dart` 里所有 `i` 换成了 `m`。**Dart 源码只用 `edit`；非要用脚本时，先拿一个文件试写并 `git diff` 确认。**

### 8.10 配置变更后页面不刷新（重启才生效）

**现象**：WebDAV 备份恢复完成后，SSH 主机不出现在会话列表，必须重启 App。

**原因**：会话页和节点监视都常驻在 `AppShell` 的 `PageView` 里（带 `AutomaticKeepAlive`），只在 `initState` 读一次配置，之后永远不重建。恢复备份只是写 SharedPreferences，没有任何东西通知它们。

**修复**：`QShellConfigStore` 增加静态通知器：

```dart
static final ValueNotifier<int> revision = ValueNotifier<int>(0);
static void _bumpRevision() => revision.value++;
```

`importFromBytes` / `addHost` / `updateHost` / `removeHost` / `clear` 之后都 bump；`SessionsPage`、`MonitorPage` 在 `initState` 里 `addListener`、`dispose` 里 `removeListener`，回调里 `_load()`。

**新页面要读配置时照这个模式订阅**，别再依赖"重建页面"。

### 8.11 节点监视不再自动全选

**现象**：添加主机后，节点监视里自动出现全部主机，用户没得选。

**原因**：`MonitorPage._load()` 里 `prefs.getStringList('monitor.selected') == null` 时默认全选。

**修复**：

- 默认空集合：`_selected = saved?.toSet() ?? <String>{}`
- 顶栏按钮从 `sync` 图标换成 `+`（tooltip「添加监控主机」），点开就是带复选框的主机多选面板（全选 / 清空 / 确认），选择结果存 `monitor.selected`
- 手动添加（二维码扫描等）的节点仍然独立存在，不受影响

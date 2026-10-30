# Android 项目接入说明（给桌面版仓库维护方）

本文档说明如何把 `QShell-Android` 纳入 QShell 仓库并随桌面版一起发版。

---

## 一、目录放置

本 Android 项目使用**独立仓库** `QShell-Android`，项目根目录即下面的结构：

```
QShell-Android/
├── app/                  # Flutter 工程
├── tools/                # 构建脚本与交叉编译素材
├── dist/                 # 发版 APK
├── README.md
└── ANDROID-HANDOFF.md
```

## 二、必须排除的目录（.gitignore）

仓库根 `.gitignore` 需要包含：

```gitignore
# Flutter / Android 构建产物
android/app/build/
android/app/.dart_tool/
android/app/.idea/
android/app/android/.gradle/
android/app/android/local.properties
android/app/android/app/.cxx/
android/app/android/app/build/
android/app/android/app/libs/

# 本地日志与临时产物
android/logs/
android/spike-*/
android/icon-build/

# 平台杂项
*.iml
.DS_Store
```

`android/dist/` 可以**提交**（放最终 APK），也可以忽略、改为只在 Release 上传——按你们的发版流程定。

## 三、版本号规则

两个文件必须同时改：

| 文件 | 字段 | 示例 |
|---|---|---|
| `app/pubspec.yaml` | `version:` | `1.0.0+12` |
| `app/lib/version.dart` | `kAppVersion` | `'1.0.0+12'` |

- 格式：`主.次.修订+构建号`
- **构建号（`+` 后）每次发版必须递增**，应用内的更新检查就是在比它
- 例如：`1.0.0+1` → `1.0.0+2` → `1.0.1+3`

## 四、构建

```powershell
cd android
. .\tools\env-android.ps1    # NDK 28.2 / SDK / JDK 17
cd app
flutter pub get
flutter build apk --release --target-platform android-arm64
```

产物：`app/build/app/outputs/flutter-apk/app-release.apk`（约 10 MB，仅 arm64）

**签名**：当前 `android/app/build.gradle` 的 release 使用 debug 签名。正式对外发布建议改为仓库内 keystore（Android 7+ 必须签名，debug 签名可安装但会被商店拒绝）。

## 五、Release 资产命名

应用内更新检查的逻辑是：**取 release 资产列表里第一个 `.apk` 文件**（`update_service.dart` → `latest()`）。

建议命名：

```
QShell-Android-1.0.0.12-arm64.apk
QShell-Windows-x64-1.0.0.msi
```

## 六、仓库与发版

**本 Android 项目使用独立仓库**：`https://github.com/Qyxscode/QShell-Android`

桌面版仓库只放桌面端，两边各自发版、各自维护版本号：

| 项目 | Tag 格式 | Release 资产 |
|---|---|---|
| QShell（桌面） | `v1.2.0` | `.msi` / `.exe` |
| QShell-Android | `v1.0.0+12` | `QShell-Android-1.0.0.12-arm64.apk` |

### 发版步骤

1. 改 `app/pubspec.yaml` 的 `version:` 和 `app/lib/version.dart` 的 `kAppVersion`（构建号 +1）
2. 构建 release APK
3. 在 **QShell-Android 仓库**创建 Release：
   ```
   Tag: v1.0.0+12
   Title: QShell Android v1.0.0 (build 12)
   Assets: QShell-Android-1.0.0.12-arm64.apk
   ```
4. 勾选 **Set as the latest release**

应用内「检查更新」走 `api.github.com/repos/Qyxscode/QShell-Android/releases/latest`，
取 tag 的 `+` 后构建号与 `kAppVersion` 比较，下载资产中第一个 `.apk`。

## 七、应用内更新源

配置位置：`app/lib/services/update_service.dart`

```dart
static const String _defaultRepo = '';   // 填 owner/repo
```

填入仓库后，「设置 → 检查更新」即可工作。

## 八、权限与后台限制

- 前台服务保活：`TerminalKeepAliveService`（`dataSync` 类型 + WakeLock + WifiLock）
- Android 14+ 对 `dataSync` 有运行时长上限，长期后台运行可能被系统回收
- 部分国产 ROM（ColorOS 等）默认隐藏低优先级前台通知，代码里已用 `IMPORTANCE_DEFAULT` 规避

## 九、已知限制

| 项 | 说明 |
|---|---|
| 仅 arm64 | 未打包 armeabi-v7a / x86_64 |
| Wi-Fi 扫描频率 | 受系统节流限制（Android 9+ 最少 30 秒，实际约 1 分钟一次） |
| MAC / ARP | Android 10+ 读不到其他设备的 MAC，局域网设备类型靠端口指纹 + mDNS 推断 |
| 邻区小区 | 部分 ROM 不开放 `allCellInfo`，只能拿到服务小区 |
| Wi-Fi 带宽 | `WifiInfo` 没有 `channelWidth`，当前连接不显示带宽（扫描列表里有） |

## 十、目录结构速查

```
app/lib/
├── design/          设计 token（AppTokens）
├── i18n/            文案（简体 / 繁体）
├── pages/
│   ├── home/        主页、Wi-Fi 分析、局域网扫描、各类详情页
│   ├── sessions/    会话、终端、备忘录
│   ├── tools/       11 个工具页
│   ├── files/       文件浏览器（SMB/SFTP/FTP/WebDAV）
│   └── settings/    设置、WebDAV 备份
├── services/        配置、系统通道、SSH、各协议实现
├── shell/           底栏 + PageView 外壳
└── version.dart     版本号
```

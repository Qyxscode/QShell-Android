# QShell Android

QShell 的 Android 客户端：多功能网络工具箱 + SSH 终端，Material Design 3。

与桌面版 [QShell](https://github.com/Qyxscode/QShell) 共享同一份 `config.json` 配置格式，可通过 zip / WebDAV 双向迁移。

仓库：https://github.com/Qyxscode/QShell-Android

## 功能

**主页**：链路拓扑（本机 → 网关 → 出口）、蜂窝 / Wi-Fi / 流量水位卡、节点详情

**会话**：分组连接管理、导入桌面版配置、备忘录（快捷命令）、SSH 终端（跳板机、私钥登录、断线重连、后台保活）

**工具**
- 诊断：Ping（ICMP/TCP）、多设备 Ping、节点监视、GeoPing、Traceroute（含 IP 归属地）、端口扫描、Whois、DNS Lookup
- 性能：iperf3（内置二进制）、网速测试
- 局域网：子网扫描（端口指纹 + mDNS 设备识别）、UPnP 扫描、Wake On LAN
- 计算：IP 计算器
- 支持分组内拖拽排序

**文件**：SMB / SFTP / FTP / WebDAV 浏览器（上传、下载、重命名、删除、属性）

**Wi-Fi 分析**：信号历史曲线、信道占用图（2.4G/5G）、信道评估与推荐、网络质量评分、一键诊断

**设置**：外观（昼夜 / Material You 取色）、终端外观、数据导入导出、WebDAV 备份恢复、权限管理、检查更新

## 构建

环境：Flutter 3.47+、JDK 17、Android SDK（NDK 28.2）、仅 arm64。

```powershell
# 载入环境（本机脚本，含 NDK / SDK / JDK 路径）
. .\tools\env-android.ps1

cd app
flutter pub get
flutter build apk --release --target-platform android-arm64
```

产物：`app/build/app/outputs/flutter-apk/app-release.apk`

### 原生依赖

- `app/src/main/cpp/jni_traceroute.c`：非特权 ICMP traceroute（CMake）
- `app/src/main/jniLibs/arm64-v8a/libiperf3.so`：交叉编译的 iperf3 3.17.1

## 版本号

单一来源：`app/lib/version.dart`

```dart
const String kAppVersion = '1.0.0+1';
```

发版时同时修改：
1. `app/lib/version.dart` 的 `kAppVersion`
2. `app/pubspec.yaml` 的 `version:`

格式 `主.次.修订+构建号`，构建号每次发版递增。应用内「检查更新」比较的就是构建号。

## 更新检查

`app/lib/services/update_service.dart`：

- 通过 GitHub Releases API 拉取最新 release
- 版本比较：优先比 `+` 后的构建号，其次语义版本
- 下载：取 release 资产中**第一个 `.apk`**
- 更新源仓库地址在 `_defaultRepo` 常量（`owner/repo`）

## 配置兼容性

读写桌面版 `config.json` 的以下部分：

- `devices[].hosts[]`：连接（`name/protocol/host/port/user/pwd/key_path/passphrase/proxy_*`）
- `memos[]`：备忘录（`group` / `items[].name` / `items[].cmd`）

其余字段（`managed_hosts`、`settings`、`webdav` 等）在备份导出时**原样保留**，不会被手机端丢弃。

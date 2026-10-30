# QShell Android

QShell 的 Android 客户端：网络工具箱 + SSH 终端，Material Design 3。

与桌面版 [QShell](https://github.com/Qyxscode/QShell) 使用同一份 `config.json`，配置可通过 zip 或 WebDAV 双向迁移。

## 功能

**主页** — 链路拓扑、蜂窝 / Wi-Fi / 流量实时曲线、设备详情

**会话** — 分组连接管理、导入桌面版配置、快捷命令备忘录、SSH 终端（跳板机、私钥登录、断线重连、后台保活）

**工具**

- 诊断：Ping、多设备 Ping、节点监视、GeoPing、Traceroute、端口扫描、Whois、DNS 查询
- 性能：iperf3、网速测试
- 局域网：子网扫描、UPnP、Wake On LAN
- 计算：IP 计算器

**文件** — SMB / SFTP / FTP / WebDAV

**Wi-Fi 分析** — 信号历史、信道占用图、信道评估与推荐、网络质量评分

**设置** — 外观、终端外观、数据导入导出、WebDAV 备份、权限管理

## 系统要求

- Android 7.0（API 24）及以上
- arm64 设备

## 下载

从 [Releases](https://github.com/Qyxscode/QShell-Android/releases) 下载最新 APK。

## 构建

环境：Flutter 3.47+、JDK 17、Android SDK（含 NDK）

```powershell
cd app
flutter pub get
flutter build apk --release --target-platform android-arm64
```

产物：`app/build/app/outputs/flutter-apk/app-release.apk`

原生依赖（CMake 工程与预编译的 iperf3 二进制）已在仓库内，无需额外准备。

## 配置格式

读取桌面版 `config.json` 的以下部分：

- `devices[].hosts[]` — 连接信息（含跳板机 `proxy_*`、私钥 `key_path` / `passphrase`）
- `memos[]` — 备忘录

其余字段在备份导出时原样保留。

## 已知限制

- Wi-Fi 扫描受系统节流限制，两次扫描间隔约 1 分钟
- Android 10+ 无法读取其他设备的 MAC，局域网设备类型由端口指纹与 mDNS 推断
- 部分 ROM 不开放 `allCellInfo`，只能读取服务小区

## 许可

待定。

# QShell Android Spike 报告

> 时间：2026-10-29
> 对应交接文档 `ANDROID-HANDOFF.md` 第 9 节第 0 步 / 第 11 节 5 个问题
> 工件：`D:\QShell-Android\app`（Tauri 2 + Vue3 + xterm + russh，可连 SSH 的真机 demo）

---

## 结论速览

| # | 问题 | 结论 |
|---|---|---|
| 1 | 除 ssh2/openssl 外还有多少编译错误 | **50 个错误点，40 个来自 ssh2 API，其余 10 个是桌面专属模块**（arboard 2 / autostart 3 / single-instance 1 / tray+menu 2 / std::os::windows 1，另 1 行是汇总） |
| 2 | ssh2 vendored OpenSSL 能否用 NDK 编过 | **Windows 主机上不划算**，实测 1 小时 + 6 轮仍失败；**换 russh（+ring）一次编过，1m05s** |
| 3 | `tauri android init` 能否在真机跑空 WebView | **能**。init 成功，debug APK 126MB（后来 289MB 含 4 ABI），OnePlus PJF110 / Android 16 / API 36 正常启动 |
| 4 | xterm 在 Android WebView 的渲染与输入 | **正常**，但有 3 个必改点（软键盘 resize、edge-to-edge 状态栏、visualViewport 初值 0 的坑），见下文 |
| 5 | 前端体积与低端机首屏 | 桌面 dist 776KB JS(gzip 214KB)+166KB CSS(gzip 28KB)；demo 页 JS 402KB(gzip 110KB)；**真机首帧实测 321~478ms**（OnePlus 旗舰，非低端机） |

**总建议：值得做，SSH 库换 `russh`（ring 后端），不要跟 ssh2 的交叉编译死磕。**

---

## 环境（实测）

| 项 | 值 |
|---|---|
| Rust | 1.99.1（edition 2024 无问题） |
| Rust targets | 已装 aarch64 / armv7 / i686 / x86_64-linux-android |
| NDK | `D:\Android\ndk\28.2.13676358`（另有 27.x） |
| SDK | `D:\Android`，platforms 33/34/35/36/37，build-tools 34/35/36 |
| JDK | `D:\Android\jdk`（Temurin 17.0.12）—— **不要用系统 JDK 27，Gradle 9 会挑刺** |
| SDK 自带 cmake | 3.22.1（不在 PATH） |
| 手机 | OnePlus PJF110，Android 16（API 36），WebView 155.0.8059.43 |
| 工程 | `D:\QShell-Android\app`（新建，未动桌面仓库） |

环境脚本：`D:\QShell-Android\tools\env-android.ps1`（点源即可，已含 NDK linkerk/CC/AR 与 JAVA_HOME）

---

## Q1：除 ssh2/openssl 外的编译错误

做法：把桌面 `src-tauri` 复制到 `D:\QShell-Android\spike-cfgcheck`，
把 `ssh2`、`arboard` 移到 `[target.'cfg(not(target_os = "android"))'.dependencies]`，
再 `cargo check --target aarch64-linux-android`。

结果：**50 条 error，按文件分布**

| 文件 | 错误数 | 原因 |
|---|---|---|
| `ssh.rs` | 18 | `ssh2::` API |
| `sftp.rs` | 8 | `ssh2::` API |
| `lib.rs` | 8 | `tauri::menu`/`tray` 2、`autostart` 3、`single_instance` 1、`arboard` 2 |
| `port_forward.rs` | 7 | `ssh2::` API |
| `traffic.rs` | 6 | `ssh2::` API |
| `monitor.rs` | 1 | `ssh2::` API |
| `probe.rs` | 1 | `std::os::windows` |

**能直接编过的**（NDK clang 交叉编译无压力，日志实测 Checking 通过）：
`tauri 2.12`、`tauri-plugin-*`、`ring`、`aws-lc-sys`、`libz-sys`、`reqwest`、`tokio`、
`image`、`zbus`、`notify-rust`、`portable-pty`、`serialport`。

> 注：`portable-pty` / `serialport` 能编过但**运行时不可用**（无 pty、无 USB OTG 权限），
> 按交接文档用 cfg 排除功能即可，不占编译错误。

**工作量判断**：SSH 层要改的是 4 个文件 40 处 API 调用（ssh/sftp/port_forward/traffic/monitor），
其余桌面专属 10 处用 `#[cfg]` 分包即可，属于半天到一天的机械活。

---

## Q2：ssh2 + vendored OpenSSL 能不能编过（重点）

**结论：Windows 主机上可以做到，但不值得。已改 russh。**

实测卡点链条（每步都是真实报错，可按序复现）：

1. **系统的 perl 是 MSWin32 版**（`C:\tools\perl`，5.38.2）
   → OpenSSL `Configure` 直接拒绝：
   `This perl implementation doesn't produce Unix like paths`
2. 换 Git 自带的 cygwin perl（5.42.3）
   → 它是**裁剪版**，缺 `Locale::Maketext::Simple`、`ExtUtils::MakeMaker`、`Pod::Usage`
3. 把 Windows perl 的纯 Perl 模块复制过去补上
   → 缺 `ExtUtils::MakeMaker`，补完缺 `Pod::Usage`，补完 `Configure` 终于通过
4. `Configure` 过了，`make` 又挂：
   - `make` 得用 NDK 自带的 `prebuilt/windows-x86_64/bin/make.exe`
   - 传进去的 `CC` 是 Windows 反斜杠路径，被 cygwin `sh` 当转义吃掉：
     `D:Androidndk...clang.exe: command not found`
   - 改成正斜杠 `clang.exe` + `CFLAGS=--target=aarch64-linux-android24` 后，
     又回到 perl 的 `PERL5LIB` 被 sh 改写（`/d/...` 变成 `D /...`）
5. 到这一步已经 **~1 小时、6 轮**，还没编出一个 `.a`

对比：**russh 0.65（default-features=false, features=["ring","rsa","flate2"]）**
在同一个工程里 `cargo check --target aarch64-linux-android` **1m05s 通过，零改动**。

补充证据：NDK 的 clang 本身没问题——`ring`、`aws-lc-sys`、`libz-sys` 这些 C 依赖
全部靠 NDK clang 编过了，卡住的只是 OpenSSL 那套 perl+make 构建系统。

**成本/收益**：保留 ssh2 需要 MSYS2 全套环境 + 每个开发机都要配一遍 + 后续 CI 也得配；
russh 是纯 Rust，`cargo build --target aarch64-linux-android` 直接过。
按交接文档的 2 小时阈值，到点即换。

---

## Q3：tauri android init + 真机空壳

- `npm run tauri android init` 一次成功（需要 `CI=true`，否则会等交互）
- JDK 必须用 17（`D:\Android\jdk`），系统 JDK 27 + Gradle 9.6.1 会报错
- 首次 build 下载 gradle-9.6.1 + 依赖，约 10 分钟；之后增量 1~2 分钟
- debug APK：universal 包 289MB（4 个 ABI，未 strip）；arm64 单 ABI 会小很多
- OnePlus / Android 16 / API 36 上**正常启动、无崩溃**

---

## Q4：xterm 在 Android WebView 的实测

**渲染**：默认 DOM 渲染器，等宽字体、ANSI 颜色、光标、滚动条都正常（见截图）。
未测 WebGL 渲染器与低端机帧率。

**输入**：xterm 的隐藏 textarea 能正常触发系统输入法，字符回传正确。

**必须处理的 3 个移动端问题（demo 里已解决）**：

1. **软键盘遮挡**
   WebView 的布局视口不随键盘变化，只变 `visualViewport`。
   必须监听 `visualViewport.resize`，把根容器高度钉到 `vv.height`，并逐帧 `fit()`。
   （交接文档 5.2 说的就是这个）
2. **edge-to-edge 状态栏重叠**
   Android 15+ 强制 edge-to-edge，内容会画到状态栏下面。
   顶部用 `padding-top: calc(8px + env(safe-area-inset-top))`，底部键条同理加
   `env(safe-area-inset-bottom)`，`viewport` 里加 `viewport-fit=cover`。
3. **`visualViewport.height` 初值可能是 0（很坑）**
   启动瞬间如果把它直接写进 CSS 高度，整页高度变 0 → **纯黑屏**。
   demo 里踩了一次，改成 `if (h > 120) 才写入`。

**未验证**：中文宽字符选择、长按复制、触摸滚动惯性、IME 组合输入（compositionend）。

---

## Q5：体积与首屏

| 产物 | raw | gzip |
|---|---|---|
| 桌面版 dist JS | 776 KB | 214 KB |
| 桌面版 dist CSS | 166 KB | 28 KB |
| demo 页 JS（Vue+xterm） | 402 KB | 110 KB |
| demo 页 CSS | 5.7 KB | 1.6 KB |

真机实测（OnePlus PJF110 / Android 16 / WebView 155）：
- 冷启动首帧 **478ms**
- 热启动 **321~388ms**
（`performance.now()` 在 `onMounted` 后两帧取，含 WebView 初始化与 Vue 挂载）

> 桌面版 776KB 的单文件前端在低端机上首屏预计 1~2s 量级。
> 建议 Android 入口按需加载（拆 xterm、主题、SFTP 等），不要整包塞进去。

---

## Demo 说明（`D:\QShell-Android\app`）

技术栈：Tauri 2.12 + Vue 3 + TS + xterm 6 + russh 0.65（ring）+ tokio

已实现：
- 连接表单（host/port/user/password）
- xterm 终端，SSH 数据经 Tauri 事件 `ssh://data`（base64）推给前端
- 键盘输入 → `ssh_write`
- resize → PTY `window_change`
- 断开事件 `ssh://exit`
- 底部功能键条：Tab / Ctrl+C / Esc / Ctrl+D
- 软键盘 resize、safe-area、启动耗时显示

**没做的**（留给正式版）：连接列表/分组、私钥登录、known_hosts 校验（现在信任所有主机密钥，仅限 spike）、
前台服务保活、自动重连、复制粘贴、字号调节。

### 构建 / 安装

```powershell
# 1. 环境
. D:\QShell-Android\tools\env-android.ps1

# 2. 打包 debug APK（arm64）
cd D:\QShell-Android\app
$env:CI = 'true'
npm run tauri android build -- --debug --apk -t aarch64

# 3. 安装
adb install -r .\src-tauri\gen\android\app\build\outputs\apk\universal\debug\app-universal-debug.apk
adb shell am start -n com.a6704.qshell/.MainActivity
```

---

## 下一步建议（按优先级）

1. **定 SSH 库**：russh 已实测可用，建议直接定它；桌面版继续用 ssh2，代码分叉点只在 `ssh.rs`/`sftp.rs` 的适配层。
2. **工程骨架**：把 `app/` 定为 Android 正式工程；桌面仓库那份保持不动，先把 `config.json` 读取 + 连接列表做出来。
3. **移动端体验**：功能键条做完整（方向键、粘滞 Ctrl）、长按选择/复制、字号调节。
4. **保活**：前台服务 + 通知；这块要看国产 ROM 的实际表现（OnePlus 上待测）。
5. **体积**：Android 入口按需加载，目标 gzip < 120KB。

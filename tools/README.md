# tools/

构建辅助脚本与交叉编译素材，**不进产物**，但建议随仓库提交（换机器重编译时要用）。

| 文件 | 用途 |
|---|---|
| `env-android.ps1` | 设置 NDK / SDK / JDK 路径（构建前 `. .\tools\env-android.ps1`） |
| `iperf-build.sh` / `iperf-build-manual.sh` | iperf3 交叉编译脚本 |
| `iperf-src/` | iperf3 3.17.1 源码（交叉编译用） |
| `perl5/`、`bin/` | 交叉编译所需的本地 perl 环境 |

生成的 `libiperf3.so` 已提交在 `app/android/app/src/main/jniLibs/arm64-v8a/`，日常构建不需要重新编译 iperf3。
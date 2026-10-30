#!/bin/sh
set -e

BIN=/d/Android/ndk/28.2.13676358/toolchains/llvm/prebuilt/windows-x86_64/bin
CC="$BIN/clang.exe"
TARGET=aarch64-linux-android24

cd /d/QShell-Android/tools/iperf-src/iperf-3.17.1/src

rm -f ./*.o iperf3

SOURCES="cjson.c dscp.c iperf_api.c iperf_auth.c iperf_client_api.c iperf_error.c iperf_locale.c iperf_pthread.c iperf_sctp.c iperf_server_api.c iperf_tcp.c iperf_time.c iperf_udp.c iperf_util.c main.c net.c tcp_info.c timer.c units.c"

for f in $SOURCES; do
  "$CC" --target=$TARGET -O2 -DHAVE_CONFIG_H -I. -c "$f" -o "${f%.c}.o"
done

"$CC" --target=$TARGET -o iperf3 ./*.o -lm

"$BIN/llvm-strip.exe" iperf3 2>/dev/null || true
ls -la iperf3
file iperf3 2>/dev/null || true

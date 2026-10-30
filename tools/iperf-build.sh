#!/bin/sh
set -e

NDK=/d/Android/ndk/28.2.13676358
TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/windows-x86_64
export PATH="$TOOLCHAIN/bin:$NDK/prebuilt/windows-x86_64/bin:$PATH"

export CC="aarch64-linux-android24-clang.cmd"
export AR="llvm-ar.exe"
export RANLIB="llvm-ranlib.exe"
export STRIP="llvm-strip.exe"

cd /d/QShell-Android/tools/iperf-src/iperf-3.17.1

./configure --host=aarch64-linux-android --without-openssl --disable-shared
make -j4

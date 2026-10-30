# Android cross-compile env. Usage: . D:\QShell-Android\tools\env-android.ps1
$env:NDK_HOME = 'D:\Android\ndk\28.2.13676358'
$env:ANDROID_NDK_HOME = 'D:\Android\ndk\28.2.13676358'
$env:ANDROID_SDK_ROOT = 'D:\Android'
$env:ANDROID_HOME = 'D:\Android'
$env:JAVA_HOME = 'D:\Android\jdk'
$ndkBin = 'D:\Android\ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin'

$api = '24'
$env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER  = "$ndkBin\aarch64-linux-android$api-clang.cmd"
$env:CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER = "$ndkBin\armv7a-linux-androideabi$api-clang.cmd"
$env:CARGO_TARGET_I686_LINUX_ANDROID_LINKER      = "$ndkBin\i686-linux-android$api-clang.cmd"
$env:CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER    = "$ndkBin\x86_64-linux-android$api-clang.cmd"

$env:CC_aarch64_linux_android = "$ndkBin\aarch64-linux-android$api-clang.cmd"
$env:CXX_aarch64_linux_android = "$ndkBin\aarch64-linux-android$api-clang++.cmd"
$env:AR_aarch64_linux_android = "$ndkBin\llvm-ar.exe"
$env:RANLIB_aarch64_linux_android = "$ndkBin\llvm-ranlib.exe"

$env:CC_armv7_linux_androideabi = "$ndkBin\armv7a-linux-androideabi$api-clang.cmd"
$env:CXX_armv7_linux_androideabi = "$ndkBin\armv7a-linux-androideabi$api-clang++.cmd"
$env:AR_armv7_linux_androideabi = "$ndkBin\llvm-ar.exe"
$env:RANLIB_armv7_linux_androideabi = "$ndkBin\llvm-ranlib.exe"

$env:CC_i686_linux_android = "$ndkBin\i686-linux-android$api-clang.cmd"
$env:CXX_i686_linux_android = "$ndkBin\i686-linux-android$api-clang++.cmd"
$env:AR_i686_linux_android = "$ndkBin\llvm-ar.exe"
$env:RANLIB_i686_linux_android = "$ndkBin\llvm-ranlib.exe"

$env:CC_x86_64_linux_android = "$ndkBin\x86_64-linux-android$api-clang.cmd"
$env:CXX_x86_64_linux_android = "$ndkBin\x86_64-linux-android$api-clang++.cmd"
$env:AR_x86_64_linux_android = "$ndkBin\llvm-ar.exe"
$env:RANLIB_x86_64_linux_android = "$ndkBin\llvm-ranlib.exe"

$env:Path = "$ndkBin;$env:Path"

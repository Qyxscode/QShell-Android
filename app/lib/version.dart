/// 当前版本号（与 pubspec.yaml 的 version 保持一致）。
///
/// 发版时同步修改这里：`1.0.0+12` → 版本号 + 构建号。
const String kAppVersion = '1.0.0+4';

/// 展示用的短版本（v1.0.0）
String get kAppVersionLabel => 'v${kAppVersion.split('+').first}';
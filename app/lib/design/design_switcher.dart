import 'design_system.dart';
import 'md3_design_system.dart';

/// 可切换的设计语言清单。
///
/// 出 MD4 时：新增 `md4_design_system.dart`，实现 [DesignSystem]，
/// 在这里加一个枚举值 + 一行映射，页面与主题控制器都不用改。
enum DesignLanguage {
  md3;

  static DesignSystem resolve(DesignLanguage language) {
    switch (language) {
      case DesignLanguage.md3:
        return const Md3DesignSystem();
    }
  }
}

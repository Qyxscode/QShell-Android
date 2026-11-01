import 'design_system.dart';
import 'glass_design_system.dart';
import 'md3_design_system.dart';

/// 可切换的设计语言清单。
///
/// 新增语言：写一个 `xxx_design_system.dart` 实现 [DesignSystem]，
/// 在这里加一个枚举值 + 一行映射，页面与主题控制器都不用改。
enum DesignLanguage {
  md3,
  glass;

  static DesignSystem resolve(DesignLanguage language) {
    switch (language) {
      case DesignLanguage.md3:
        return const Md3DesignSystem();
      case DesignLanguage.glass:
        return const GlassDesignSystem();
    }
  }
}
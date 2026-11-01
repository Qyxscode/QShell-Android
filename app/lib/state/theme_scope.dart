import 'package:flutter/material.dart';

import 'theme_controller.dart';

/// 把外观控制器放到 widget 树上，任何页面都能拿到（设置页从右上角齿轮进入）。
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// 拿不到时返回 null（测试或独立 widget 场景）
  static ThemeController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
  }

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope?.notifier != null, 'ThemeScope 缺失：请在 MaterialApp 上方包裹');
    return scope!.notifier!;
  }
}

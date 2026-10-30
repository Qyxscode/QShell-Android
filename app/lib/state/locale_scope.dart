import 'package:flutter/widgets.dart';

import 'locale_controller.dart';

/// 把 LocaleController 注入组件树（页面里读写语言用）。
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope?.notifier != null, 'LocaleScope 未找到：检查 app.dart 是否包了外层');
    return scope!.notifier!;
  }

  static LocaleController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.notifier;
}

import 'package:flutter/material.dart';

import 'design/design_switcher.dart';
import 'i18n/app_strings.dart';
import 'shell/app_shell.dart';
import 'state/locale_controller.dart';
import 'state/locale_scope.dart';
import 'state/theme_controller.dart';
import 'state/theme_scope.dart';

class QShellApp extends StatelessWidget {
  const QShellApp({
    super.key,
    required this.controller,
    required this.localeController,
    this.dynamicAccent,
  });

  final ThemeController controller;
  final LocaleController localeController;

  /// 系统壁纸取色后的强调色（Material You）；为空表示系统不支持或用户关闭。
  final Color? dynamicAccent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[controller, localeController]),
      builder: (context, _) {
        final design = DesignLanguage.resolve(controller.designLanguage);
        final useDynamic = controller.useDynamicColor && dynamicAccent != null;
        final effectiveSeed = useDynamic ? dynamicAccent! : controller.seed;

        return ThemeScope(
          controller: controller,
          child: LocaleScope(
            controller: localeController,
            child: AppStringsScope(
              // 文案作用域包在 MaterialApp 外：push 出来的页面也能拿到
              strings: AppStrings.forLanguage(localeController.language),
              child: MaterialApp(
                title: 'QShell',
                debugShowCheckedModeBanner: false,
                theme: design.buildTheme(
                  brightness: Brightness.light,
                  seed: effectiveSeed,
                ),
                darkTheme: design.buildTheme(
                  brightness: Brightness.dark,
                  seed: effectiveSeed,
                ),
                themeMode: controller.themeMode,
                home: const AppShell(),
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'design/design_switcher.dart';
import 'design/fade_transitions.dart';
import 'design/glass_design_system.dart';
import 'design/tokens.dart';
import 'i18n/app_strings.dart';
import 'shell/app_shell.dart';
import 'state/locale_controller.dart';
import 'state/locale_scope.dart';
import 'state/theme_controller.dart';
import 'state/theme_scope.dart';

/// 页面转场统一用纯淡入：默认的缩放转场会把壁纸背景一起盖住
const _transitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: InstantPageTransitionsBuilder(),
    TargetPlatform.iOS: InstantPageTransitionsBuilder(),
    TargetPlatform.windows: InstantPageTransitionsBuilder(),
    TargetPlatform.macOS: InstantPageTransitionsBuilder(),
    TargetPlatform.linux: InstantPageTransitionsBuilder(),
  },
);

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
              child: Builder(
                builder: (innerContext) {
                  // 这里还在 MaterialApp 之外，用平台亮度推断当前明暗
                  final platformDark =
                      View.of(innerContext).platformDispatcher
                              .platformBrightness ==
                          Brightness.dark;
                  final isDark = switch (controller.themeMode) {
                    ThemeMode.dark => true,
                    ThemeMode.light => false,
                    ThemeMode.system => platformDark,
                  };

                  // 从主题里取 token，用于绘制背景层（不依赖 Theme context）
                  final theme = design.buildTheme(
                    brightness:
                        isDark ? Brightness.dark : Brightness.light,
                    seed: effectiveSeed,
                  );
                  final tokens = theme.extension<AppTokens>();

                  // 这里在 MaterialApp 之外，没有 Directionality/MediaQuery，
                  // Stack 需要显式给一个，否则首帧直接抛异常黑屏
                  return Directionality(
                    textDirection: TextDirection.ltr,
                    child: Stack(
                      children: [
                      // 背景层放在 MaterialApp 之外：
                      // 路由转场、页面重建都不会影响它，彻底消除 push 时的白闪/黑闪
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: (tokens?.glass ?? false)
                              ? GlassBackdrop(
                                  accent: tokens!.accent,
                                  brightness: isDark
                                      ? Brightness.dark
                                      : Brightness.light,
                                  background: tokens.background,
                                  wallpaper: controller.wallpaper,
                                  wallpaperDim: controller.wallpaperDim,
                                  child: const SizedBox.expand(),
                                )
                              : ColoredBox(
                                  color:
                                      tokens?.background ?? theme.colorScheme.surface,
                                ),
                        ),
                      ),
                      Positioned.fill(
                        child: MaterialApp(
                          title: 'QShell',
                          debugShowCheckedModeBanner: false,
                          theme: design
                              .buildTheme(
                                brightness: Brightness.light,
                                seed: effectiveSeed,
                              )
                              .copyWith(pageTransitionsTheme: _transitions),
                          darkTheme: design
                              .buildTheme(
                                brightness: Brightness.dark,
                                seed: effectiveSeed,
                              )
                              .copyWith(pageTransitionsTheme: _transitions),
                          themeMode: controller.themeMode,
                          // 不配这段，文本框长按的「复制/粘贴/全选」会走英文默认实现
                          locale: localeController.language ==
                                  AppLanguage.zhHant
                              ? const Locale('zh', 'TW')
                              : const Locale('zh', 'CN'),
                          supportedLocales: const [
                            Locale('zh', 'CN'),
                            Locale('zh', 'TW'),
                          ],
                          localizationsDelegates: const [
                            GlobalMaterialLocalizations.delegate,
                            GlobalWidgetsLocalizations.delegate,
                            GlobalCupertinoLocalizations.delegate,
                          ],
                          // 设计语言整体换皮肤，渐变过渡会露出中间态，直接瞬时切换
                          themeAnimationDuration: Duration.zero,
                          builder: (context, child) {
                            // 状态栏/导航栏图标跟随主题反色
                            final dark = Theme.of(context).brightness ==
                                Brightness.dark;
                            final base = dark
                                ? SystemUiOverlayStyle.light
                                : SystemUiOverlayStyle.dark;
                            return AnnotatedRegion<SystemUiOverlayStyle>(
                              value: base.copyWith(
                                statusBarColor: Colors.transparent,
                                systemNavigationBarColor: Colors.transparent,
                                statusBarIconBrightness: dark
                                    ? Brightness.light
                                    : Brightness.dark,
                                systemNavigationBarIconBrightness: dark
                                    ? Brightness.light
                                    : Brightness.dark,
                              ),
                              child: child ?? const SizedBox.shrink(),
                            );
                          },
                          home: const AppShell(),
                        ),
                      ),
                    ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

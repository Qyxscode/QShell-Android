import 'package:flutter/material.dart';

import 'wallpaper_page.dart';

/// 页面路由：新页面从右侧滑入，旧页面视差左移。
///
/// 转场能正常工作的前提是页面**不透明**——这里用 [WallpaperPage] 给每个
/// push 出来的页面铺一层壁纸背景，新页面滑入时能完整盖住旧页面，
/// 不会像透明页面那样出现内容重影。
class InstantPageRoute<T> extends PageRouteBuilder<T> {
  InstantPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  }) : super(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, animation, secondaryAnimation) =>
              WallpaperPage(child: builder(context)),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            final incoming = Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);

            final outgoing = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.22, 0),
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(
                  secondaryAnimation,
                );

            return SlideTransition(
              position: outgoing,
              child: SlideTransition(position: incoming, child: child),
            );
          },
        );
}

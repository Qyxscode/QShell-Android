import 'dart:io';

import 'package:flutter/material.dart';

import '../state/theme_scope.dart';
import 'glass_design_system.dart';
import 'tokens.dart';

/// 给「push 出来的页面」提供一层不透明背景。
///
/// 为什么要它：页面背景若是透明的（靠全局壁纸透上来），路由转场时新旧两个
/// 页面会同时可见，内容叠在一起就是重影。让每个页面自己画一遍同样的壁纸，
/// 页面就变成不透明的，转场时能完整盖住旧页面。
///
/// Tab 页不用包它——PageView 切页没有路由转场，共享全局背景更省。
class WallpaperPage extends StatelessWidget {
  const WallpaperPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    if (!tokens.glass) return child;

    // pageBuilder 的 context 位于 Overlay 里，InheritedWidget 依赖查找偶尔
    // 拿不到，补一个祖先查找兜底
    final controller = ThemeScope.maybeOf(context) ??
        context.findAncestorWidgetOfExactType<ThemeScope>()?.notifier;
    final path = controller?.wallpaper;
    final dim = controller?.wallpaperDim ?? 0.35;
    debugPrint(
      'WallpaperPage: glass=${tokens.glass} path=${path ?? "null"}',
    );

    if (path == null || path.isEmpty) {
      // 没有壁纸：必须复用主页同款的光斑背景。
      // 只画纯色会让二级页面变成一块死板的底色，和主页明显割裂。
      return GlassBackdrop(
        accent: tokens.accent,
        brightness: Theme.of(context).brightness,
        background: tokens.background,
        wallpaper: null,
        wallpaperDim: dim,
        child: child,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: tokens.background),
        Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: 1080,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
        // 压暗比主页重一点：二级页面看起来像浮在背景之上的一层，
        // 同时保持不透明（转场才不会出现内容重影）
        ColoredBox(
          color: (Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white)
              .withValues(alpha: (dim + 0.06).clamp(0.0, 0.92)),
        ),
        child,
      ],
    );
  }
}

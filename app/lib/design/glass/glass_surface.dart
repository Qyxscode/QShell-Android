import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/tokens.dart';
import 'glass_edge_painter.dart';

/// **玻璃**浮层外壳：模糊 + 半透明底色 + 顶部高光 + 厚度描边。
///
/// 这个文件只负责玻璃风格。MD3 的实色壳在 `md3/md3_surface.dart`，
/// 两者由 `design/surfaces.dart` 里的 `AppSurface` 按主题分派 ——
/// 改玻璃不会碰到 MD3，反之亦然。
///
/// 注意：
/// - 阴影画在 `ClipRRect` **外面**，否则会被裁掉；
/// - 不要在外面套 [Opacity] / `FadeTransition`，离屏层会让模糊失效，
///   需要淡入就让 [opacity] 跟着动画走（改底色 alpha，不是 widget 透明度）。
class GlassSurfaceLayer extends StatelessWidget {
  const GlassSurfaceLayer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.blur = 16,
    this.opacity = 0.46,
    this.padding = EdgeInsets.zero,
    this.showEdge = true,
    this.shadow = false,
    this.constraints,
  });

  final Widget child;
  final double borderRadius;
  final double blur;

  /// 底色不透明度
  final double opacity;

  final EdgeInsetsGeometry padding;
  final bool showEdge;
  final bool shadow;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    final body = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: _content(tokens, isDark, radius),
      ),
    );

    return ConstrainedBox(
      constraints: constraints ?? const BoxConstraints(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 阴影：必须在裁剪层之外，否则会被 ClipRRect 切掉
          if (shadow)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.42 : 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
          body,
        ],
      ),
    );
  }

  Widget _content(AppTokens tokens, bool isDark, BorderRadius radius) {
    return Stack(
      children: [
        // 底色
        Positioned.fill(
          child: ColoredBox(
            color: (isDark ? const Color(0xFF1B2028) : Colors.white)
                .withValues(alpha: opacity),
          ),
        ),
        // 顶部高光（+6%）
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.05 : 0.22),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.42],
                ),
              ),
            ),
          ),
        ),
        // 厚度描边
        if (showEdge)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: GlassEdgePainter(
                  isDark: isDark,
                  radius: radius.topLeft.x,
                  strength: 1.1,
                ),
              ),
            ),
          ),
        // ListTile / InkWell 必须有 Material 祖先，否则运行时抛异常
        // （浮层里没有 Scaffold，表现出来就是一整片灰）
        Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
  }
}

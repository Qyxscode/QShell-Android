import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'glass_edge_painter.dart';
import 'tokens.dart';

/// 浮层玻璃外壳：模糊 + 底色 + 顶部高光 + 厚度描边。
///
/// 所有浮层（toast / 菜单 / 弹窗 / 确认框）共用它，保证材质一致。
///
/// 注意：
/// - 阴影画在 `ClipRRect` **外面**，否则会被裁掉；
/// - 不要在外面套 [Opacity] / `FadeTransition`，离屏层会让模糊失效，
///   需要淡入就让 [opacity] 跟着动画走（改底色 alpha，不是 widget 透明度）。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
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

  /// 底色不透明度（玻璃）/ 1.0 表示实色（非玻璃主题）
  final double opacity;

  final EdgeInsetsGeometry padding;
  final bool showEdge;
  final bool shadow;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = tokens.glass;
    final radius = BorderRadius.circular(borderRadius);

    final body = ClipRRect(
      borderRadius: radius,
      child: glass
          ? BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: _content(tokens, isDark, radius, glass),
            )
          : ColoredBox(
              color: tokens.surfaceFloating,
              child: _content(tokens, isDark, radius, glass),
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
                      color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.16),
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

  Widget _content(
    AppTokens tokens,
    bool isDark,
    BorderRadius radius,
    bool glass,
  ) {
    return Stack(
      children: [
        // 底色
        Positioned.fill(
          child: ColoredBox(
            color: glass
                ? (isDark ? const Color(0xFF1B2028) : Colors.white)
                    .withValues(alpha: opacity)
                : Colors.transparent,
          ),
        ),
        // 顶部高光（+6%）
        if (glass)
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
        if (glass && showEdge)
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
        Padding(padding: padding, child: child),
      ],
    );
  }
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'glass_edge_painter.dart';

/// 液态玻璃（档位 B）：背景模糊 + 厚度感。
///
/// 用 [BackdropFilter.grouped]：同一 [BackdropGroup] 下的多个滤镜共享一次
/// 背景采样，滚动列表时不会因逐帧重采样而「模糊消失」。
/// 厚度由「上亮下暗渐变 + 白色内描边」模拟。
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.blur = 3,
    this.strength = 40,
    this.tint = 0.06,
    this.depth = 0.16,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
  });

  final Widget child;

  /// 模糊强度（越小越通透）
  final double blur;

  /// 折射强度：strength * 0.001 + 1 = 放大倍数
  final double strength;

  /// 整体底色（0 = 全透）
  final double tint;

  /// 厚度感强度（边缘高光/暗边）
  final double depth;

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    // 只用模糊做玻璃质感：ImageFilter.matrix 在滚动时会采样越界，
    // 导致玻璃在滑动后「失效」变成全透明。
    final filter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: filter,
        child: Stack(
          children: [
            // 底色（一般保持 0，玻璃靠后面的折射体现）
            if (tint > 0)
              Positioned.fill(
                child: ColoredBox(
                  color: (isDark ? Colors.black : Colors.white)
                      .withValues(alpha: tint),
                ),
              ),
            // 厚度：顶部一道高光，底部一道压暗，中间透明
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: depth * 0.55),
                        Colors.white.withValues(alpha: 0),
                        Colors.black.withValues(
                          alpha: depth * 0.28,
                        ),
                      ],
                      stops: const [0.0, 0.52, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // 内描边：和卡片同一套厚度画法，保证材质一致
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: GlassEdgePainter(
                    isDark: isDark,
                    radius: borderRadius.topLeft.x,
                    strength: 1.15,
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

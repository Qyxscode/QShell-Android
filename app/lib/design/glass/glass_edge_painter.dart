import 'package:flutter/material.dart';


/// 玻璃厚度描边：外圈亮线 + 内圈暗线 + 顶部高光渐变。
///
/// 卡片和底栏共用同一套画法，保证材质一致。
class GlassEdgePainter extends CustomPainter {
  const GlassEdgePainter({
    required this.isDark,
    required this.radius,
    this.strength = 1,
  });

  final bool isDark;
  final double radius;

  /// 整体强度倍率
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1) 外圈亮线：玻璃外缘的反光
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * strength
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: (isDark ? 0.22 : 0.55) * strength),
          Colors.white.withValues(alpha: (isDark ? 0.06 : 0.18) * strength),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(0.6),
        Radius.circular(radius - 0.6),
      ),
      outer,
    );

    // 2) 内圈暗线：让玻璃「看着有厚度」的分界
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: (isDark ? 0.22 : 0.05) * strength);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(2.0),
        Radius.circular((radius - 2.0).clamp(0, double.infinity)),
      ),
      inner,
    );

    // 3) 顶部高光：沿圆角的描边，用渐变从上往下淡出
    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * strength
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: (isDark ? 0.20 : 0.55) * strength),
          Colors.white.withValues(alpha: (isDark ? 0.06 : 0.16) * strength),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.32, 0.62],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(1.0),
        Radius.circular((radius - 1.0).clamp(0, double.infinity)),
      ),
      highlight,
    );
  }

  @override
  bool shouldRepaint(GlassEdgePainter old) =>
      old.isDark != isDark ||
      old.radius != radius ||
      old.strength != strength;
}

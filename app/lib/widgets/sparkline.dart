import 'package:flutter/material.dart';

/// 迷你折线图（每秒采样用）。
///
/// 自己画，不引第三方图表库：数据量小、样式要跟着 token 走。
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.height = 56,
    this.color,
    this.fill = true,
  });

  final List<double> values;
  final double height;
  final Color? color;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          lineColor: color ?? Theme.of(context).colorScheme.primary,
          fill: fill,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required List<double> values,
    required this.lineColor,
    required this.fill,
  }) : values = List<double>.unmodifiable(values);

  /// 构造时做一份不可变快照：调用方传的通常是同一个 List 实例
  /// （每秒原地 add/removeAt），不复制的话新旧 painter 会共享数据，
  /// shouldRepaint 永远判定“没变化”，曲线就不刷新。
  final List<double> values;
  final Color lineColor;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    // 数据不足（刚进页面 / 采样还没跑够）时画一条淡基线，
    // 避免卡片里出现一片纯空白的“曲线区”，看起来像坏了。
    if (values.length < 2) {
      final paint = Paint()
        ..color = lineColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      final y = size.height - 2;
      canvas.drawLine(const Offset(4, 0) + Offset(0, y), Offset(size.width - 4, y), paint);
      return;
    }

    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final span = (max - min).abs() < 0.0001 ? 1.0 : (max - min);
    final lo = min - span * 0.15;
    final hi = max + span * 0.15;

    // 左右各留 1px：线条用 butt 端帽，起点/终点正好落在填充边界上，
    // 不会出现「线条比色块长」的视觉效果。
    const inset = 1.0;
    double xAt(int i) =>
        inset + (size.width - inset * 2) * (i / (values.length - 1));
    double yAt(double v) =>
        size.height - ((v - lo) / (hi - lo)).clamp(0.0, 1.0) * size.height;

    final path = Path()..moveTo(xAt(0), yAt(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(xAt(i), yAt(values[i]));
    }

    if (fill) {
      // 填充用矩形底边，顶部上移 1px 让线条落在色块内部；左右边界与线条完全一致
      final fillPath = path.shift(const Offset(0, -1.0))
        ..lineTo(size.width - inset, size.height)
        ..lineTo(inset, size.height)
        ..close();
      final shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.22),
          lineColor.withValues(alpha: 0.10),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(fillPath, Paint()..shader = shader);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.butt
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) {
    // 调用方通常直接传同一个 List 实例（原地 add/removeAt），
    // 只比较引用会永远判定"没变"→ 曲线不刷新。这里比较长度和最新值。
    if (old.lineColor != lineColor || old.fill != fill) return true;
    if (old.values.length != values.length) return true;
    if (values.isEmpty) return false;
    return old.values.last != values.last;
  }
}

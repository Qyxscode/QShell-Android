import 'package:flutter/material.dart';

import '../state/theme_scope.dart';
import 'glass_edge_painter.dart';
import 'tokens.dart';

/// 可选的「玻璃卡片」：[refraction] 为 true 时用半透明玻璃质感渲染。
///
/// 卡片不做 BackdropFilter 模糊：Flutter 的 backdrop 采样在滚动容器里会
/// 随内容平移而短暂失效（模糊忽隐忽现），而卡片正是列表里最常见的元素。
/// 这里用「半透明底 + 上亮下暗渐变 + 多层描边」模拟玻璃厚度，滚动稳定。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.refraction,
    this.margin,
    this.elevation,
    this.color,
    this.shape,
    this.clipBehavior = Clip.antiAlias,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  final Widget child;

  /// null 表示跟随设置里的「卡片折射」开关
  final bool? refraction;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final Color? color;
  final ShapeBorder? shape;
  final Clip clipBehavior;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final enabled =
        refraction ?? (ThemeScope.maybeOf(context)?.glassAllCards ?? false);
    if (!enabled || !tokens.glass) {
      return Card(
        margin: margin,
        elevation: elevation,
        color: color,
        shape: shape,
        clipBehavior: clipBehavior,
        child: child,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding =
        margin is EdgeInsets ? margin as EdgeInsets : EdgeInsets.zero;

    return Padding(
      padding: padding,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            // 玻璃本体：半透明底 + 上亮下暗
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // 转场动画期间合成层会重建，底色太低会瞬间「透明」
                  color: Colors.white
                      .withValues(alpha: isDark ? 0.075 : 0.40),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.05 : 0.20),
                      Colors.white.withValues(alpha: 0),
                      Colors.black.withValues(alpha: isDark ? 0.07 : 0.025),
                    ],
                    stops: const [0.0, 0.48, 1.0],
                  ),
                ),
              ),
            ),
            // 厚度：多层描边（外亮、内暗、贴边高光）
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: GlassEdgePainter(
                    isDark: isDark,
                    radius: borderRadius.topLeft.x,
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              clipBehavior: clipBehavior,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

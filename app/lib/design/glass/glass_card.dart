import 'package:flutter/material.dart';

import 'glass_edge_painter.dart';

/// **玻璃**卡片：[refraction] 为 true 时用半透明玻璃质感渲染。
///
/// 卡片不做 BackdropFilter 模糊：Flutter 的 backdrop 采样在滚动容器里会
/// 随内容平移而短暂失效（模糊忽隐忽现），而卡片正是列表里最常见的元素。
/// 这里用「半透明底 + 上亮下暗渐变 + 多层描边」模拟玻璃厚度，滚动稳定。
///
/// 关闭折射时（设置里的开关）由 `AppCard` 退化成普通 `Card`，
/// 那个分支在 `design/cards.dart`，不在本文件。
class GlassCardLayer extends StatelessWidget {
  const GlassCardLayer({
    super.key,
    required this.child,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
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

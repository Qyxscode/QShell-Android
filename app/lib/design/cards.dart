import 'package:flutter/material.dart';

import '../state/theme_scope.dart';
import 'core/tokens.dart';
import 'glass/glass_card.dart';
import 'md3/md3_card.dart';

/// 卡片的统一入口：**按主题分派**。
///
/// | 情况 | 实现 | 视觉 |
/// |---|---|---|
/// | 玻璃主题 + 开启折射 | `glass/glass_card.dart` | 半透明 + 渐变 + 厚度边 |
/// | 玻璃主题但关闭折射 / MD3 主题 | `md3/md3_card.dart` | 标准 `Card` |
///
/// [refraction] 为 null 时跟随设置里的「卡片折射」开关。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.refraction,
    this.margin,
    this.elevation,
    this.color,
    this.shape,
    this.clipBehavior = Clip.antiAlias,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
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
    if (tokens.glass && enabled) {
      return GlassCardLayer(
        margin: margin,
        borderRadius: borderRadius,
        clipBehavior: clipBehavior,
        child: child,
      );
    }
    return Md3Card(
      margin: margin,
      elevation: elevation,
      color: color,
      shape: shape,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// 历史名字：早期卡片统一写成 `GlassCard(...)`，现在它按主题分派。
typedef GlassCard = AppCard;

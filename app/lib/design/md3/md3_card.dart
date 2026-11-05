import 'package:flutter/material.dart';

/// **MD3** 卡片：标准 `Card`（实色 + 主题里的浅阴影）。
///
/// 与 `glass/glass_card.dart` 对应，由 `design/cards.dart` 的 `AppCard`
/// 按主题分派。改 MD3 卡片只动这里。
class Md3Card extends StatelessWidget {
  const Md3Card({
    super.key,
    required this.child,
    this.margin,
    this.elevation,
    this.color,
    this.shape,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final Color? color;
  final ShapeBorder? shape;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      elevation: elevation,
      color: color,
      shape: shape,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// **MD3** 浮层外壳：实色底 + 圆角 + 可选阴影。
///
/// 与 `glass/glass_surface.dart` 的玻璃壳一一对应，由
/// `design/surfaces.dart` 的 `AppSurface` 按主题分派。
/// 这里不使用任何模糊 / 半透明 / 厚度描边——那些是玻璃语言的东西，
/// 改 MD3 时只需要动这个文件。
class Md3Surface extends StatelessWidget {
  const Md3Surface({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding = EdgeInsets.zero,
    this.shadow = false,
    this.constraints,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool shadow;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final radius = BorderRadius.circular(borderRadius);

    return ConstrainedBox(
      constraints: constraints ?? const BoxConstraints(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surfaceFloating,
          borderRadius: radius,
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: Theme.of(context).brightness ==
                                Brightness.dark
                            ? 0.36
                            : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: radius,
          // ListTile / InkWell 需要 Material 祖先（浮层里没有 Scaffold）
          child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

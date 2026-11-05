import 'package:flutter/material.dart';

import 'core/tokens.dart';
import 'glass/glass_surface.dart';
import 'md3/md3_surface.dart';

/// 浮层外壳的统一入口：**按主题分派**，业务代码只用这个。
///
/// 分工（改一类风格不会碰到另一类）：
///
/// | 主题 | 实现文件 | 视觉 |
/// |---|---|---|
/// | 玻璃 | `glass/glass_surface.dart` | 模糊 + 半透明 + 高光 + 厚度描边 |
/// | MD3 | `md3/md3_surface.dart` | 实色底 + 圆角 + 阴影 |
///
/// 两种实现互不 import，共享的只有这里的参数表。
/// 新增参数时：给两边都加一个可选参数，默认值保持各自现有观感。
class AppSurface extends StatelessWidget {
  const AppSurface({
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

  /// 仅玻璃主题使用
  final double blur;

  /// 仅玻璃主题使用
  final double opacity;

  final EdgeInsetsGeometry padding;

  /// 仅玻璃主题使用
  final bool showEdge;

  final bool shadow;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    if (tokens.glass) {
      return GlassSurfaceLayer(
        borderRadius: borderRadius,
        blur: blur,
        opacity: opacity,
        padding: padding,
        showEdge: showEdge,
        shadow: shadow,
        constraints: constraints,
        child: child,
      );
    }
    return Md3Surface(
      borderRadius: borderRadius,
      padding: padding,
      shadow: shadow,
      constraints: constraints,
      child: child,
    );
  }
}

/// 历史名字：早期所有浮层都写成 `GlassSurface(...)`。
/// 保留别名，业务代码不用改，语义上它已经是「按主题分派的浮层」。
typedef GlassSurface = AppSurface;

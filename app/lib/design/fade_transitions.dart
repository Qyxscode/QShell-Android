import 'package:flutter/material.dart';

/// 页面转场：不做动画，直接切换。
///
/// 为什么不用滑动/淡入：
/// 本应用的页面背景是透明的（透出全局壁纸），而 InstantPageRoute 的
/// 转场会在动画期间同时绘制新旧两个路由——一个页面的内容叠在另一个上面，
/// 视觉上就是文字和卡片重影。任何「两页同屏」的转场都避不开这一点，
/// 所以这里干脆瞬时切换。
class InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget? child,
  ) {
    return child ?? const SizedBox.shrink();
  }
}

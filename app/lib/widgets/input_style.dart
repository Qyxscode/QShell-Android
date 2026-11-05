import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// 输入框描边统一入口。
///
/// 玻璃主题靠半透明填充区分层次，保持无边框；
/// MD3 的填充色（surfaceContainerHigh）和卡片底色（surfaceContainer）常常
/// 只差一点点，无边框时输入框会「消失」——看起来像点不到，实际只是看不见。
/// 所以非玻璃主题下给一条 outline 描边。
OutlineInputBorder inputBorder(
  AppTokens tokens, {
  double radius = 12,
}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: tokens.glass
        ? BorderSide.none
        : BorderSide(color: tokens.outlineSoft),
  );
}

/// 聚焦态描边：两种主题都强调色，只是玻璃主题不加宽。
OutlineInputBorder focusedInputBorder(
  AppTokens tokens, {
  double radius = 12,
}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(
      color: tokens.accent,
      width: tokens.glass ? 1.2 : 1.5,
    ),
  );
}

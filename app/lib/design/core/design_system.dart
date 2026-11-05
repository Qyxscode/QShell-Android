import 'package:flutter/material.dart';

import 'tokens.dart';

/// 设计语言抽象。
///
/// 现在只有 MD3 一个实现；将来出 MD4 时新增一个实现类，
/// 在 [designSystemFor] 里加一个分支即可，页面代码不动。
abstract interface class DesignSystem {
  String get id;
  String get label;

  ThemeData buildTheme({
    required Brightness brightness,
    required Color seed,
    ColorScheme? dynamicScheme,
  });
}

/// 把 ColorScheme 映射成语义 token。
/// 这是 MD3 → tokens 的唯一转换点。
AppTokens tokensFromColorScheme(ColorScheme scheme) {
  final isDark = scheme.brightness == Brightness.dark;
  return AppTokens(
    background: scheme.surface,
    // 卡片用 surfaceContainer（比 Low 高一级，和页面底色拉开一点层次）
    surfaceCard: scheme.surfaceContainer,
    surfaceCardAlt: scheme.surfaceContainerHigh,
    outline: scheme.outline,
    outlineSoft: scheme.outlineVariant,
    textPrimary: scheme.onSurface,
    textSecondary: scheme.onSurfaceVariant,
    textDisabled: scheme.onSurface.withValues(alpha: 0.38),
    accent: scheme.primary,
    onAccent: scheme.onPrimary,
    accentSoft: scheme.primaryContainer,
    onAccentSoft: scheme.onPrimaryContainer,
    highlight: scheme.tertiary,
    onHighlight: scheme.onTertiary,
    success: isDark ? const Color(0xFF6DD58C) : const Color(0xFF1B7F45),
    warning: isDark ? const Color(0xFFF3C969) : const Color(0xFF9A6B00),
    danger: scheme.error,
    track: scheme.surfaceContainerHighest,
  );
}

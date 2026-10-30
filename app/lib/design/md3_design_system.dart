import 'package:flutter/material.dart';

import 'design_system.dart';

/// Material Design 3 实现。
///
/// 严格用 MD3 的 ColorScheme/组件语义：surface container 层级、
/// primary/secondary/tertiary、outline/outlineVariant 都按官方命名映射。
class Md3DesignSystem implements DesignSystem {
  const Md3DesignSystem();

  @override
  String get id => 'md3';

  @override
  String get label => 'Material Design 3';

  @override
  ThemeData buildTheme({
    required Brightness brightness,
    required Color seed,
    ColorScheme? dynamicScheme,
  }) {
    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final tokens = tokensFromColorScheme(scheme);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: tokens.background,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surfaceCard,
        indicatorColor: tokens.accentSoft,
        elevation: 0,
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => base.textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? tokens.onAccentSoft
                : tokens.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? tokens.onAccentSoft
                : tokens.textSecondary,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surfaceCard,
        surfaceTintColor: Colors.transparent,
        // MD3 elevated card：level 1 的浅阴影，深色模式下 Material 会自动弱化
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        margin: EdgeInsets.zero,
        // 关键：把子组件（InkWell 水波、长按高亮层）裁进圆角，
        // 否则长按会看到方形高亮/阴影盖在圆角卡片上。
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.outlineSoft,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: tokens.accentSoft,
          selectedForegroundColor: tokens.onAccentSoft,
          foregroundColor: tokens.textSecondary,
          side: BorderSide(color: tokens.outlineSoft),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.onAccent
              : tokens.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.accent
              : tokens.track,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.surfaceCardAlt,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

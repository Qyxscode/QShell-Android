import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_system.dart';

/// 液态玻璃风格（Glassmorphism）。
///
/// 做法：卡片半透明 + 背景铺彩色光斑 + 底栏/弹层做真实模糊。
/// 不在滚动列表的每一项上用 BackdropFilter，避免掉帧。
class GlassDesignSystem implements DesignSystem {
  const GlassDesignSystem();

  @override
  String get id => 'glass';

  @override
  String get label => '液态玻璃';

  @override
  ThemeData buildTheme({
    required Brightness brightness,
    required Color seed,
    ColorScheme? dynamicScheme,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    // 玻璃主题：卡片透出背景的彩色光斑
    final baseTokens = tokensFromColorScheme(scheme);
    final tokens = baseTokens.copyWith(
      background: isDark ? const Color(0xFF0A0D12) : const Color(0xFFE6EAF2),
      surfaceCard: Colors.white.withValues(alpha: isDark ? 0.09 : 0.48),
      // 弹层比卡片实一些，否则内容透出来边界不清
      surfaceCardAlt: (isDark ? const Color(0xFF1B2028) : Colors.white)
          .withValues(alpha: isDark ? 0.94 : 0.96),
      // 描边要跟背景反着来：浅色卡片配深边，深色卡片配浅边，否则边界看不见
      outline: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.10),
      outlineSoft: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06),
      track: Colors.white.withValues(alpha: isDark ? 0.16 : 0.5),
      glass: true,
    );

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
        // 透明，让背景光斑透出来
        backgroundColor: Colors.transparent,
        systemOverlayStyle: (isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
        // 让右上角圆形按钮的边缘与下方卡片对齐（卡片左右各 16）
        actionsPadding: const EdgeInsets.only(right: 10),
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          // 1px 高光边，模拟玻璃厚度
          side: BorderSide(color: tokens.outlineSoft, width: 1),
        ),
      ),
      // 玻璃主题下裸图标不成体系，统一给圆形玻璃底
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor:
              Colors.white.withValues(alpha: isDark ? 0.10 : 0.55),
          foregroundColor: tokens.textPrimary,
          shape: const CircleBorder(),
          minimumSize: const Size(40, 40),
          maximumSize: const Size(40, 40),
          padding: EdgeInsets.zero,
          iconSize: 20,
        ),
      ),
      // 输入框：玻璃底 + 高光边，和卡片同一套语言
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: isDark ? 0.07 : 0.45),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.outlineSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.outlineSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.accent, width: 1.4),
        ),
        labelStyle: TextStyle(color: tokens.textSecondary),
        hintStyle: TextStyle(
          color: tokens.textDisabled,
          fontSize: 13,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.outlineSoft,
        thickness: 1,
        space: 1,
      ),
      // 玻璃语言：实心按钮改成「彩色玻璃」——半透明强调色 + 高光边，
      // 不再是 MD3 那种纯色块
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent.withValues(alpha: isDark ? 0.62 : 0.72),
          foregroundColor: tokens.onAccent,
          disabledBackgroundColor: tokens.accent.withValues(alpha: 0.20),
          disabledForegroundColor: tokens.onAccent.withValues(alpha: 0.6),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
            side: BorderSide(
              color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.35),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: isDark ? 0.08 : 0.42),
          foregroundColor: tokens.textPrimary,
          side: BorderSide(color: tokens.outlineSoft),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: isDark ? 0.12 : 0.55),
          foregroundColor: tokens.textPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
            side: BorderSide(color: tokens.outlineSoft),
          ),
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
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surfaceCardAlt,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceCardAlt,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: tokens.outlineSoft),
        ),
      ),
    );
  }
}

/// 背景光斑：玻璃主题下铺在页面最底层，让半透明卡片有东西可透。
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({
    super.key,
    required this.child,
    required this.accent,
    required this.brightness,
  });

  final Widget child;
  final Color accent;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    // 日间背景浅，光斑要给足才能透出玻璃感
    final strength = isDark ? 0.46 : 0.52;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
        Positioned(
          top: -110,
          left: -80,
          child: _Orb(color: accent.withValues(alpha: strength), size: 300),
        ),
        Positioned(
          top: 140,
          right: -90,
          child: _Orb(
            color: accent.withValues(alpha: strength * 0.7),
            size: 260,
          ),
        ),
        Positioned(
          bottom: -120,
          left: 40,
          child: _Orb(
            color: accent.withValues(alpha: strength * 0.55),
            size: 320,
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

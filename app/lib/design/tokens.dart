import 'package:flutter/material.dart';

/// 语义 token 层。
///
/// 规矩：界面代码只允许引用这里的语义名（如 tokens.surfaceCard），
/// **不允许直接写死颜色**。将来切 MD4 时只替换这一层的生成方式，
/// 页面代码一行都不用改。
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.background,
    required this.surfaceCard,
    required this.surfaceCardAlt,
    required this.outline,
    required this.outlineSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.highlight,
    required this.onHighlight,
    required this.success,
    required this.warning,
    required this.danger,
    required this.track,
    this.glass = false,
  });

  final Color background;
  final Color surfaceCard;
  final Color surfaceCardAlt;
  final Color outline;
  final Color outlineSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color onAccentSoft;
  final Color highlight;
  final Color onHighlight;
  final Color success;
  final Color warning;
  final Color danger;
  final Color track;

  /// 是否玻璃质感主题（卡片半透明 + 背景装饰 + 底栏模糊）
  final bool glass;

  @override
  AppTokens copyWith({
    Color? background,
    Color? surfaceCard,
    Color? surfaceCardAlt,
    Color? outline,
    Color? outlineSoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? onAccentSoft,
    Color? highlight,
    Color? onHighlight,
    Color? success,
    Color? warning,
    Color? danger,
    Color? track,
    bool? glass,
  }) {
    return AppTokens(
      background: background ?? this.background,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceCardAlt: surfaceCardAlt ?? this.surfaceCardAlt,
      outline: outline ?? this.outline,
      outlineSoft: outlineSoft ?? this.outlineSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccentSoft: onAccentSoft ?? this.onAccentSoft,
      highlight: highlight ?? this.highlight,
      onHighlight: onHighlight ?? this.onHighlight,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      track: track ?? this.track,
      glass: glass ?? this.glass,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppTokens(
      background: mix(background, other.background),
      surfaceCard: mix(surfaceCard, other.surfaceCard),
      surfaceCardAlt: mix(surfaceCardAlt, other.surfaceCardAlt),
      outline: mix(outline, other.outline),
      outlineSoft: mix(outlineSoft, other.outlineSoft),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textDisabled: mix(textDisabled, other.textDisabled),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentSoft: mix(accentSoft, other.accentSoft),
      onAccentSoft: mix(onAccentSoft, other.onAccentSoft),
      highlight: mix(highlight, other.highlight),
      onHighlight: mix(onHighlight, other.onHighlight),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      track: mix(track, other.track),
      glass: t < 0.5 ? glass : other.glass,
    );
  }

  static AppTokens of(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    assert(tokens != null, 'AppTokens 缺失：请通过 DesignSystem 构建 ThemeData');
    return tokens!;
  }
}

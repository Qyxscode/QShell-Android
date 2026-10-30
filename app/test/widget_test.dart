import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qshell/design/design_system.dart';

void main() {
  test('ColorScheme 能映射出完整语义 token', () {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3B5BDB));
    final tokens = tokensFromColorScheme(scheme);

    expect(tokens.background, isNotNull);
    expect(tokens.surfaceCard, isNotNull);
    expect(tokens.accent, scheme.primary);
    expect(tokens.highlight, scheme.tertiary);
    expect(tokens.textPrimary, scheme.onSurface);
  });

  test('亮色与暗色 token 不同', () {
    final light = tokensFromColorScheme(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF3B5BDB),
        brightness: Brightness.light,
      ),
    );
    final dark = tokensFromColorScheme(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF3B5BDB),
        brightness: Brightness.dark,
      ),
    );
    expect(light.background, isNot(dark.background));
    expect(light.textPrimary, isNot(dark.textPrimary));
  });
}

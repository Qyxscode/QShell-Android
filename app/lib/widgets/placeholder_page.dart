import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// 未实现页面的统一占位。
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.planned = const <String>[],
  });

  final IconData icon;
  final String title;
  final String? description;
  final List<String> planned;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 34, color: tokens.onAccentSoft),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: text.titleLarge?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (planned.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tokens.outlineSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.construction_rounded,
                            size: 16, color: tokens.warning),
                        const SizedBox(width: 6),
                        Text(
                          '计划中的内容',
                          style: text.labelLarge
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...planned.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: tokens.outline,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: text.bodySmall
                                    ?.copyWith(color: tokens.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

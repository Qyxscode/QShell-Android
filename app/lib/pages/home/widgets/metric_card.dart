import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../widgets/sparkline.dart';

/// 主页的指标卡。
///
/// 两种形态：
/// - 传 [progress]（0~1）：卡片底部按比例填充成“水位”，直观表达绝对占比
///   （蜂窝 / WiFi 这类有 0~100 上限的指标）
/// - 只传 [series]：底部画实时折线（流量这类没有上限的指标）
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.value,
    this.unit,
    this.caption,
    this.series,
    this.progress,
    this.pendingHint,
    this.onTap,
    this.chartHeight = 44,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final String? value;
  final String? unit;
  final String? caption;
  final List<double>? series;

  /// 0~1，非空时显示水位填充而不是折线
  final double? progress;

  /// 数据源还没接上时的提示语（null 表示已接入）
  final String? pendingHint;
  final VoidCallback? onTap;
  final double chartHeight;

  bool get _pending => pendingHint != null;
  bool get _waterline => progress != null;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // 水位：从底部按比例填充
            if (_waterline && !_pending)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: (progress ?? 0).clamp(0.0, 1.0),
                    widthFactor: 1,
                    // 扁平纯色填充（不用渐变/描边，避免拟物感，符合 MD3）
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 15, color: accent),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: text.labelLarge?.copyWith(
                            color: tokens.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (onTap != null)
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: tokens.textDisabled),
                    ],
                  ),
                  if (_pending) ...[
                    const SizedBox(height: 8),
                    _PendingArea(
                      hint: pendingHint!,
                      tokens: tokens,
                      text: text,
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            value ?? '--',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.headlineSmall?.copyWith(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (unit != null) ...[
                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              unit!,
                              style: text.labelMedium
                                  ?.copyWith(color: tokens.textSecondary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            caption ?? ' ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall
                                ?.copyWith(color: tokens.textSecondary),
                          ),
                        ),
                        if (_waterline && progress != null)
                          Text(
                            '${(progress! * 100).round()}%',
                            style: text.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    if (!_waterline) ...[
                      const SizedBox(height: 6),
                      Sparkline(
                        values: series ?? const <double>[],
                        height: chartHeight,
                        color: accent,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingArea extends StatelessWidget {
  const _PendingArea({
    required this.hint,
    required this.tokens,
    required this.text,
  });

  final String hint;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        color: tokens.surfaceCardAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.outlineSoft),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty_rounded,
              size: 16, color: tokens.textDisabled),
          const SizedBox(height: 4),
          Text(
            hint,
            style: text.labelSmall?.copyWith(color: tokens.textDisabled),
          ),
        ],
      ),
    );
  }
}

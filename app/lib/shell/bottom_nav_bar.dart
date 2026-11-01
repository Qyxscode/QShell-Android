import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../design/glass_edge_painter.dart';
import '../design/liquid_glass.dart';
import '../design/tokens.dart';

/// 底部导航：玻璃胶囊 + 可长按拖动切页。
///
/// 长按时高亮胶囊会放大并轻微溢出底栏，拖动手指可在各页之间切换。
class BottomNavBar extends StatefulWidget {
  const BottomNavBar({
    super.key,
    required this.index,
    required this.labels,
    required this.iconsOutlined,
    required this.iconsFilled,
    required this.onSelect,
    required this.tokens,
    this.onPreview,
    this.glassRefraction = false,
  });

  final int index;
  final List<String> labels;
  final List<IconData> iconsOutlined;
  final List<IconData> iconsFilled;
  final ValueChanged<int> onSelect;

  /// 拖动过程中调用：只瞬时切页，不跑过渡动画（否则每帧都起一个动画会卡死）
  final ValueChanged<int>? onPreview;
  final AppTokens tokens;

  /// 液态玻璃是否启用模糊
  final bool glassRefraction;

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  static const double _height = 66;
  static const double _pad = 5;

  /// 是否处于「按住拖动」状态
  bool _dragging = false;

  void _onDragStart(DragStartDetails details) {
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details, double itemWidth) {
    final count = widget.labels.length;
    final x = details.localPosition.dx - _pad;
    final target = (x / itemWidth).floor().clamp(0, count - 1);
    if (target != widget.index) {
      (widget.onPreview ?? widget.onSelect)(target);
    }
  }

  void _onDragEnd() {
    if (!_dragging) return;
    setState(() => _dragging = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final text = Theme.of(context).textTheme;
    final count = widget.labels.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - _pad * 2) / count;
        return Stack(
          // 允许高亮胶囊在按住时溢出底栏
          clipBehavior: Clip.none,
          children: [
            // 高亮胶囊：按住时放大
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: _pad + itemWidth * widget.index,
              top: _pad,
              bottom: _pad,
              width: itemWidth,
              child: AnimatedScale(
                scale: _dragging ? 1.26 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.glass
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : tokens.accent.withValues(alpha: 0.13))
                        : tokens.accentSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: tokens.glass
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            // 按钮行
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _pad),
              child: Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onSelect(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: i == widget.index ? 1.0 : 0.94,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              child: Icon(
                                i == widget.index
                                    ? widget.iconsFilled[i]
                                    : widget.iconsOutlined[i],
                                size: 24,
                                color: i == widget.index
                                    ? (tokens.glass
                                        ? tokens.accent
                                        : tokens.onAccentSoft)
                                    : tokens.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              style: (text.labelSmall ??
                                      const TextStyle(fontSize: 10))
                                  .copyWith(
                                fontSize: 10,
                                color: i == widget.index
                                    ? (tokens.glass
                                        ? tokens.accent
                                        : tokens.onAccentSoft)
                                    : tokens.textSecondary,
                                fontWeight: i == widget.index
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              child: Text(
                                widget.labels[i],
                                maxLines: 1,
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
        );
      },
    );

    // 长按后拖动切页
    // 按下即可拖：用水平拖动而不是长按（长按要等 500ms，太迟钝）
    final gesture = GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        final width = box?.size.width ?? 320;
        final itemWidth = (width - _pad * 2) / count;
        _onDragUpdate(details, itemWidth);
      },
      onHorizontalDragEnd: (_) => _onDragEnd(),
      onHorizontalDragCancel: _onDragEnd,
      child: content,
    );

    // 非玻璃主题：普通卡片底
    if (!tokens.glass) {
      return Container(
        height: _height,
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: tokens.outlineSoft),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: gesture,
      );
    }

    // 玻璃主题：底层裁剪做模糊 + 描边，内容层不裁剪（高亮才能溢出）
    return SizedBox(
      height: _height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: widget.glassRefraction
                  ? LiquidGlass(
                      borderRadius: BorderRadius.circular(22),
                      strength: 42,
                      blur: 3,
                      depth: 0.18,
                      tint: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white)
                              .withValues(alpha: isDark ? 0.16 : 0.14),
                        ),
                      ),
                    )
                  : BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white)
                              .withValues(alpha: isDark ? 0.16 : 0.14),
                        ),
                      ),
                    ),
            ),
          ),
          // 描边（不裁剪，跟随圆角）
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: GlassEdgePainter(
                  isDark: isDark,
                  radius: 22,
                  strength: 1.15,
                ),
              ),
            ),
          ),
          Positioned.fill(child: gesture),
        ],
      ),
    );
  }
}

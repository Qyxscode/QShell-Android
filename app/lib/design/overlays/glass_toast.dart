import 'dart:async';

import 'package:flutter/material.dart';

import '../surfaces.dart';
import '../core/tokens.dart';

/// toast 语气，决定图标与颜色。
enum GlassToastTone { info, success, error }

/// 当前显示的 toast，保证同一时刻只留一条。
OverlayEntry? _activeToast;
Timer? _activeTimer;

/// 玻璃 toast：替代系统 SnackBar。
///
/// 规格：左右各 16、距底 96 + 安全区；圆角 12、模糊 16、底 0.38；
/// 260ms 上滑 35% + 淡入；停留 2s；点击立即关闭。
///
/// 淡入靠 [GlassSurface.opacity] 变化实现，**不能**在外面包 `FadeTransition`
/// 或 `Opacity`——那会把 BackdropFilter 变成离屏层，模糊直接失效。
void showGlassToast(
  BuildContext context,
  String message, {
  GlassToastTone tone = GlassToastTone.info,
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);

  // 同一时刻只留一条
  _activeTimer?.cancel();
  _activeToast?.remove();
  _activeToast = null;

  final tokens = AppTokens.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final (icon, color) = switch (tone) {
    GlassToastTone.success => (Icons.check_circle_rounded, tokens.success),
    GlassToastTone.error => (Icons.error_outline_rounded, tokens.danger),
    GlassToastTone.info => (Icons.info_outline_rounded, tokens.accent),
  };

  late OverlayEntry entry;
  var removed = false;
  void close() {
    if (removed) return;
    removed = true;
    _activeTimer?.cancel();
    entry.remove();
    if (identical(_activeToast, entry)) _activeToast = null;
  }

  entry = OverlayEntry(
    builder: (_) => _GlassToastView(
      message: message,
      icon: icon,
      color: color,
      isDark: isDark,
      tokens: tokens,
      onClose: close,
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
  _activeTimer = Timer(duration, close);
}

class _GlassToastView extends StatefulWidget {
  const _GlassToastView({
    required this.message,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.tokens,
    required this.onClose,
  });

  final String message;
  final IconData icon;
  final Color color;
  final bool isDark;
  final AppTokens tokens;
  final VoidCallback onClose;

  @override
  State<_GlassToastView> createState() => _GlassToastViewState();
}

class _GlassToastViewState extends State<_GlassToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return Positioned(
      left: 16,
      right: 16,
      bottom: 96 + MediaQuery.viewPaddingOf(context).bottom,
      child: AnimatedBuilder(
        animation: curve,
        builder: (context, child) {
          return Transform.translate(
            // 上滑 35%
            offset: Offset(0, (1 - curve.value) * 24),
            child: GlassSurface(
              borderRadius: 12,
              blur: 16,
              // 淡入靠底色 alpha，而不是 Opacity
              opacity: 0.38 * curve.value.clamp(0.0, 1.0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: widget.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium
                      ?.copyWith(color: widget.tokens.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

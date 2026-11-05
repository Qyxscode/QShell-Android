import 'dart:async';

import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'tokens.dart';

/// 玻璃确认框：替代 `showDialog` + `AlertDialog`。
///
/// 规格：圆角 20、模糊 18、底 0.46、barrier `black 0.30`；
/// 标题 15.5 bold（危险操作用 danger 色）+ 正文 13 + 等宽按钮。
///
/// [danger] 为 true 时确认按钮用危险色（删除类操作）。
Future<bool> showGlassConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmText = '确定',
  String cancelText = '取消',
  bool danger = false,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<bool>();
  var closed = false;

  late OverlayEntry entry;
  void close(bool result) {
    if (closed) return;
    closed = true;
    entry.remove();
    if (!completer.isCompleted) completer.complete(result);
  }

  entry = OverlayEntry(
    builder: (_) => _GlassConfirmView(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      danger: danger,
      onClose: close,
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _GlassConfirmView extends StatefulWidget {
  const _GlassConfirmView({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.danger,
    required this.onClose,
  });

  final String title;
  final String? message;
  final String confirmText;
  final String cancelText;
  final bool danger;
  final void Function(bool result) onClose;

  @override
  State<_GlassConfirmView> createState() => _GlassConfirmViewState();
}

class _GlassConfirmViewState extends State<_GlassConfirmView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final accent = widget.danger ? tokens.danger : tokens.accent;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onClose(false);
      },
      child: Stack(
        children: [
          // 遮罩：0.30 是上限，再深会让模糊后的内容发灰
          AnimatedBuilder(
            animation: curve,
            builder: (context, _) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onClose(false),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.30 * curve.value),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: curve,
              builder: (context, child) => Transform.scale(
                scale: 0.96 + 0.04 * curve.value,
                child: child,
              ),
              child: GestureDetector(
                onTap: () {},
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: GlassSurface(
                    borderRadius: 20,
                    blur: 18,
                    opacity: 0.46,
                    shadow: true,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: text.titleSmall?.copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: widget.danger
                                ? tokens.danger
                                : tokens.textPrimary,
                          ),
                        ),
                        if (widget.message != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            widget.message!,
                            style: text.bodySmall?.copyWith(
                              fontSize: 13,
                              height: 1.4,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _GlassButton(
                                label: widget.cancelText,
                                tokens: tokens,
                                text: text,
                                onTap: () => widget.onClose(false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _GlassButton(
                                label: widget.confirmText,
                                tokens: tokens,
                                text: text,
                                color: accent,
                                filled: true,
                                onTap: () => widget.onClose(true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.label,
    required this.tokens,
    required this.text,
    required this.onTap,
    this.color,
    this.filled = false,
  });

  final String label;
  final AppTokens tokens;
  final TextTheme text;
  final VoidCallback onTap;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: filled
                ? (color ?? tokens.accent)
                    .withValues(alpha: isDark ? 0.62 : 0.72)
                : Colors.white.withValues(alpha: isDark ? 0.08 : 0.42),
            border: Border.all(
              color: filled
                  ? Colors.white.withValues(alpha: isDark ? 0.16 : 0.35)
                  : tokens.outlineSoft,
            ),
          ),
          child: Text(
            label,
            style: text.labelLarge?.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: filled ? tokens.onAccent : tokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 玻璃信息弹窗：替代「`AlertDialog` + 只读内容 + 单个关闭按钮」。
Future<void> showGlassInfo(
  BuildContext context, {
  required String title,
  required Widget content,
  String closeText = '关闭',
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  var closed = false;

  late OverlayEntry entry;
  void close() {
    if (closed) return;
    closed = true;
    entry.remove();
    if (!completer.isCompleted) completer.complete();
  }

  entry = OverlayEntry(
    builder: (_) => _GlassInfoView(
      title: title,
      content: content,
      closeText: closeText,
      onClose: close,
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _GlassInfoView extends StatefulWidget {
  const _GlassInfoView({
    required this.title,
    required this.content,
    required this.closeText,
    required this.onClose,
  });

  final String title;
  final Widget content;
  final String closeText;
  final VoidCallback onClose;

  @override
  State<_GlassInfoView> createState() => _GlassInfoViewState();
}

class _GlassInfoViewState extends State<_GlassInfoView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return PopScope(
      canPop: true,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: curve,
            builder: (context, _) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.30 * curve.value),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: curve,
              builder: (context, child) => Transform.scale(
                scale: 0.96 + 0.04 * curve.value,
                child: child,
              ),
              child: GestureDetector(
                onTap: () {},
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: GlassSurface(
                    borderRadius: 20,
                    blur: 18,
                    opacity: 0.46,
                    shadow: true,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: text.titleSmall?.copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: SingleChildScrollView(child: widget.content),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: _GlassButton(
                            label: widget.closeText,
                            tokens: tokens,
                            text: text,
                            filled: true,
                            onTap: widget.onClose,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
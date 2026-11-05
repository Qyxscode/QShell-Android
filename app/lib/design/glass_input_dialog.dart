import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'tokens.dart';

/// 玻璃输入框弹窗：替代「`AlertDialog` + `TextField`」这类重命名 / 新建对话框。
///
/// 返回输入内容；取消或点遮罩返回 `null`。
///
/// 规格与 [showGlassConfirm] 一致：圆角 20、模糊 18、底 0.46、barrier 0.30。
Future<String?> showGlassInput(
  BuildContext context, {
  required String title,
  String? message,
  String? label,
  String? hint,
  String initial = '',
  String confirmText = '确定',
  String cancelText = '取消',
  int maxLines = 1,
  bool obscure = false,
  TextInputType? keyboardType,
  bool allowEmpty = false,
}) {
  // 走路由才能让系统返回键 / 手势返回生效
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondary, child) => ScaleTransition(
      // 只做缩放，不套 FadeTransition：Opacity 会让 BackdropFilter 失效
      scale: Tween<double>(begin: 0.96, end: 1).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          // 退出也用 easeOut，否则收尾会跳帧
          reverseCurve: Curves.easeOutCubic,
        ),
      ),
      child: child,
    ),
    pageBuilder: (context, animation, secondary) => _GlassInputView(
      title: title,
      message: message,
      label: label,
      hint: hint,
      initial: initial,
      confirmText: confirmText,
      cancelText: cancelText,
      maxLines: maxLines,
      obscure: obscure,
      keyboardType: keyboardType,
      allowEmpty: allowEmpty,
      onClose: (value) => Navigator.of(context).pop(value),
    ),
  );
}

class _GlassInputView extends StatefulWidget {
  const _GlassInputView({
    required this.title,
    required this.message,
    required this.label,
    required this.hint,
    required this.initial,
    required this.confirmText,
    required this.cancelText,
    required this.maxLines,
    required this.obscure,
    required this.keyboardType,
    required this.allowEmpty,
    required this.onClose,
  });

  final String title;
  final String? message;
  final String? label;
  final String? hint;
  final String initial;
  final String confirmText;
  final String cancelText;
  final int maxLines;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool allowEmpty;
  final void Function(String? result) onClose;

  @override
  State<_GlassInputView> createState() => _GlassInputViewState();
}

class _GlassInputViewState extends State<_GlassInputView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();
  late final TextEditingController _textCtrl =
      TextEditingController(text: widget.initial);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // 自动聚焦，省一次点击
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _textCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _textCtrl.text.trim();
    if (value.isEmpty && !widget.allowEmpty) return;
    widget.onClose(value);
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
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onClose(null);
      },
      // 键盘弹出时整体上移，否则高内容会被顶出屏幕
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
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
                        if (widget.message != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.message!,
                            style: text.bodySmall?.copyWith(
                              fontSize: 12.5,
                              height: 1.4,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextField(
                          controller: _textCtrl,
                          focusNode: _focus,
                          maxLines: widget.maxLines,
                          obscureText: widget.obscure,
                          keyboardType: widget.keyboardType,
                          textInputAction: widget.maxLines == 1
                              ? TextInputAction.done
                              : TextInputAction.newline,
                          onSubmitted: (_) => _submit(),
                          style: text.bodyMedium?.copyWith(
                            color: tokens.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: widget.label,
                            hintText: widget.hint,
                            isDense: true,
                            // 主题默认 filled，这里在自己的淡底上会叠出直角灰罩
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: tokens.outlineSoft),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: tokens.outlineSoft),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: tokens.accent,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _DialogButton(
                                label: widget.cancelText,
                                tokens: tokens,
                                text: text,
                                onTap: () => widget.onClose(null),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DialogButton(
                                label: widget.confirmText,
                                tokens: tokens,
                                text: text,
                                filled: true,
                                onTap: _submit,
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
        ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.tokens,
    required this.text,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final AppTokens tokens;
  final TextTheme text;
  final VoidCallback onTap;
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
                ? tokens.accent.withValues(alpha: isDark ? 0.62 : 0.72)
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

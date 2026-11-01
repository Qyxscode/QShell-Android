import 'package:flutter/material.dart';
import '../design/glass_card.dart';

import '../design/tokens.dart';

/// 工具页统一布局组件。
///
/// 约定：所有工具页都是「输入卡片 → 全宽主按钮 → 结果区」，
/// 保证字段标签对齐、间距一致，避免每页各写一套。

/// 输入卡片：把一组字段/选择器包在一张卡里。
class ToolCard extends StatelessWidget {
  const ToolCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 10));
      spaced.add(children[i]);
    }
    return GlassCard(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: spaced,
        ),
      ),
    );
  }
}

/// 行式字段：左侧固定宽度标签 + 右侧输入框。
class ToolField extends StatelessWidget {
  const ToolField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: text.bodySmall?.copyWith(color: tokens.textSecondary),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            style: text.bodyMedium?.copyWith(color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: text.bodyMedium?.copyWith(color: tokens.textDisabled),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              filled: true,
              fillColor: tokens.surfaceCardAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: tokens.accent, width: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 全宽主按钮。
class ToolPrimaryButton extends StatelessWidget {
  const ToolPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.loading = false,
    this.loadingLabel,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool loading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return SizedBox(
      width: double.infinity,
      // 不用 FilledButton.icon：它是「图标+文字」整体居中，
      // 文字会偏右。主按钮只要纯文字，才能视觉居中。
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.onAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(loadingLabel ?? '处理中…'),
                ],
              )
            : Text(label),
      ),
    );
  }
}

/// 结果区标题（小字，带上下留白）。
class ToolSectionTitle extends StatelessWidget {
  const ToolSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: text.labelMedium?.copyWith(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// 提示 / 错误行（带图标）。
class ToolNotice extends StatelessWidget {
  const ToolNotice({
    super.key,
    required this.message,
    this.error = false,
  });

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final color = error ? tokens.danger : tokens.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: text.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

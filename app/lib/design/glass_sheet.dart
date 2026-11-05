import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'tokens.dart';

/// 玻璃底部弹窗：替代 `showModalBottomSheet`。
///
/// **基于路由**（`showGeneralDialog`）而不是 `OverlayEntry`：
/// 只有走路由，系统返回键 / 手势返回才会自动关闭弹层。
/// 早先用 OverlayEntry 时 `PopScope` 不在路由栈里，返回手势完全无效。
///
/// 悬浮式设计：左右留 10、底部让出手势条与键盘；四角圆角 24
/// （贴屏幕底会被屏幕物理圆角裁断描边）。
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context, void Function(T? result) close)
      builder,
  WidgetBuilder? actions,
  double maxHeightFactor = 0.78,
  bool dismissible = true,
  /// 为 false 时隐藏拖拽条与标题（用于纯动作菜单）
  bool showHeader = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: title,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondary) => _GlassSheetPage<T>(
      title: title,
      builder: builder,
      actions: actions,
      maxHeightFactor: maxHeightFactor,
      dismissible: dismissible,
      showHeader: showHeader,
    ),
    transitionBuilder: (context, animation, secondary, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}

class _GlassSheetPage<T> extends StatefulWidget {
  const _GlassSheetPage({
    required this.title,
    required this.builder,
    required this.actions,
    required this.maxHeightFactor,
    required this.dismissible,
    required this.showHeader,
  });

  final String title;
  final Widget Function(BuildContext context, void Function(T? result) close)
      builder;
  final WidgetBuilder? actions;
  final double maxHeightFactor;
  final bool dismissible;
  final bool showHeader;

  @override
  State<_GlassSheetPage<T>> createState() => _GlassSheetPageState<T>();
}

class _GlassSheetPageState<T> extends State<_GlassSheetPage<T>> {
  /// 下滑跟手偏移
  double _drag = 0;

  void _close([T? result]) => Navigator.of(context).pop(result);

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * widget.maxHeightFactor;

    return PopScope(
      canPop: widget.dismissible,
      child: Stack(
        children: [
          // 遮罩：0.32 是上限，再深模糊会发灰
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.dismissible ? _close : null,
            child: const ColoredBox(color: Color(0x52000000)),
          ),
          Positioned(
            left: 10,
            right: 10,
            // 让出键盘与手势条
            bottom: 10 + media.viewInsets.bottom + media.viewPadding.bottom,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (!widget.dismissible) return;
                final next = _drag + details.delta.dy;
                setState(() => _drag = next < 0 ? 0 : next);
              },
              onVerticalDragEnd: (details) {
                if (!widget.dismissible) return;
                if (_drag > 110 || (details.primaryVelocity ?? 0) > 700) {
                  _close();
                } else {
                  setState(() => _drag = 0);
                }
              },
              child: Transform.translate(
                offset: Offset(0, _drag),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: GlassSurface(
                    borderRadius: 24,
                    blur: 18,
                    opacity: 0.46,
                    shadow: true,
                    padding: EdgeInsets.fromLTRB(
                      18,
                      widget.showHeader ? 10 : 16,
                      18,
                      16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.showHeader) ...[
                        // 自绘拖拽条 36×4
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color:
                                  tokens.textDisabled.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                        Text(
                          widget.title,
                          style: text.titleMedium?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ],
                        Flexible(
                          child: SingleChildScrollView(
                            child: widget.builder(context, _close),
                          ),
                        ),
                        if (widget.actions != null) ...[
                          const SizedBox(height: 16),
                          widget.actions!(context),
                        ],
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

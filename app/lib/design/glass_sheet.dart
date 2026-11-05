import 'dart:async';

import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'tokens.dart';

/// 玻璃底部弹窗：替代 `showModalBottomSheet`。
///
/// 悬浮式设计：左右留 10、底部让出手势条与键盘；四角圆角 24
/// （贴屏幕底会被屏幕物理圆角裁断描边）。
///
/// 自带：遮罩渐显、上滑进入、点遮罩关闭、下滑手势关闭、返回键关闭、键盘避让。
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context, void Function(T? result) close)
      builder,
  WidgetBuilder? actions,
  double maxHeightFactor = 0.78,
  bool dismissible = true,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<T?>();
  var closed = false;

  late OverlayEntry entry;
  void close(T? result) {
    if (closed) return;
    closed = true;
    entry.remove();
    if (!completer.isCompleted) completer.complete(result);
  }

  entry = OverlayEntry(
    builder: (_) => _GlassSheetView<T>(
      title: title,
      builder: builder,
      actions: actions,
      maxHeightFactor: maxHeightFactor,
      dismissible: dismissible,
      onClose: close,
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _GlassSheetView<T> extends StatefulWidget {
  const _GlassSheetView({
    required this.title,
    required this.builder,
    required this.actions,
    required this.maxHeightFactor,
    required this.dismissible,
    required this.onClose,
  });

  final String title;
  final Widget Function(BuildContext context, void Function(T? result) close)
      builder;
  final WidgetBuilder? actions;
  final double maxHeightFactor;
  final bool dismissible;
  final void Function(T? result) onClose;

  @override
  State<_GlassSheetView<T>> createState() => _GlassSheetViewState<T>();
}

class _GlassSheetViewState<T> extends State<_GlassSheetView<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 200),
  )..forward();

  /// 下滑跟手偏移
  double _drag = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * widget.maxHeightFactor;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return PopScope(
      canPop: widget.dismissible,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.dismissible) widget.onClose(null);
      },
      child: Stack(
        children: [
          // 遮罩：0.32 是上限，再深模糊会发灰
          AnimatedBuilder(
            animation: curve,
            builder: (context, _) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.dismissible ? () => widget.onClose(null) : null,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.32 * curve.value),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            // 让出键盘与手势条
            bottom: 10 + media.viewInsets.bottom + media.viewPadding.bottom,
            child: AnimatedBuilder(
              animation: curve,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, (1 - curve.value) * 160 + _drag),
                child: child,
              ),
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (!widget.dismissible) return;
                  final next = _drag + details.delta.dy;
                  setState(() => _drag = next < 0 ? 0 : next);
                },
                onVerticalDragEnd: (details) {
                  if (!widget.dismissible) return;
                  if (_drag > 110 || (details.primaryVelocity ?? 0) > 700) {
                    widget.onClose(null);
                  } else {
                    setState(() => _drag = 0);
                  }
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: GlassSurface(
                    borderRadius: 24,
                    blur: 18,
                    opacity: 0.46,
                    shadow: true,
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 自绘拖拽条 36×4
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: tokens.textDisabled
                                  .withValues(alpha: 0.5),
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
                        Flexible(
                          child: SingleChildScrollView(
                            child: widget.builder(context, widget.onClose),
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

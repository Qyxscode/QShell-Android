import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../design/glass_dialog.dart';
import '../../design/glass_surface.dart';
import '../../design/glass_toast.dart';
import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';

/// 图片预览：全屏查看、双指缩放、保存、删除。
///
/// 之前点开图片直接交给系统相册，但相册里删不掉、也找不到源文件，
/// 所以这里自己实现一个轻量预览页。
class ImagePreviewPage extends StatefulWidget {
  const ImagePreviewPage({
    super.key,
    required this.bytes,
    required this.name,
    this.onDelete,
  });

  /// 图片原始字节（已下载到内存，不再依赖临时文件）
  final List<int> bytes;
  final String name;

  /// 删除回调：返回 true 表示删除成功，页面自动退出
  final Future<bool> Function()? onDelete;

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  bool _chrome = true;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 点击图片切换控件显隐
          GestureDetector(
            onTap: () => setState(() => _chrome = !_chrome),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: SizedBox.expand(
                child: Image.memory(
                  Uint8List.fromList(widget.bytes),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            size: 48, color: Colors.white54),
                        SizedBox(height: 12),
                        Text('无法解码这张图片',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 顶部：返回 + 文件名
          AnimatedSlide(
            offset: _chrome ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    _RoundButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 底部操作
          AnimatedSlide(
            offset: _chrome ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: GlassSurface(
                    borderRadius: 16,
                    blur: 18,
                    opacity: 0.42,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionButton(
                          icon: _busy
                              ? Icons.hourglass_top_rounded
                              : Icons.download_rounded,
                          label: '保存',
                          color: tokens.accent,
                          onTap: _busy ? null : _save,
                        ),
                        if (widget.onDelete != null)
                          _ActionButton(
                            icon: Icons.delete_outline_rounded,
                            label: strings.commonDelete,
                            color: tokens.danger,
                            onTap: _busy ? null : _delete,
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

  /// 保存到应用文档目录下的 QShell 文件夹。
  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/QShell');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final target = File('${dir.path}/${widget.name}');
      await target.writeAsBytes(widget.bytes);
      if (!mounted) return;
      showGlassToast(context, '已保存到 ${target.path}',
          tone: GlassToastTone.success);
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, '保存失败：$e', tone: GlassToastTone.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showGlassConfirm(
      context,
      title: '删除图片',
      message: '确定删除「${widget.name}」？',
      confirmText: '删除',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final done = await widget.onDelete?.call() ?? false;
      if (!mounted) return;
      if (done) {
        Navigator.of(context).maybePop();
      } else {
        showGlassToast(context, '删除失败', tone: GlassToastTone.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// 顶部圆形按钮
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

/// 底部动作按钮
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

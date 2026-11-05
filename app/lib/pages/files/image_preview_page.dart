import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../design/glass_dialog.dart';
import '../../design/glass_surface.dart';
import '../../design/glass_toast.dart';
import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';

/// 预览项：名称 + 字节，或一个懒加载器（远程图片首次翻到时才下载）。
class ImagePreviewItem {
  ImagePreviewItem({
    required this.name,
    this.bytes,
    this.loader,
    this.onDelete,
  }) : assert(bytes != null || loader != null, 'bytes 和 loader 至少给一个');

  final String name;

  /// 已加载的字节（本地文件、刚下载完的远程图片）
  List<int>? bytes;

  /// 懒加载：远程图片首次翻到这一页时才下载
  final Future<List<int>?> Function()? loader;

  /// 删除回调；返回 true 表示删除成功
  final Future<bool> Function()? onDelete;
}

/// 图片预览：全屏、双指缩放、左右翻页、保存、删除。
class ImagePreviewPage extends StatefulWidget {
  const ImagePreviewPage({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  /// 单图便捷构造
  ImagePreviewPage.single({
    Key? key,
    required String name,
    required List<int> bytes,
    Future<bool> Function()? onDelete,
  }) : this(
          key: key,
          items: [
            ImagePreviewItem(name: name, bytes: bytes, onDelete: onDelete),
          ],
        );

  final List<ImagePreviewItem> items;
  final int initialIndex;

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late final PageController _pageCtrl =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  late List<ImagePreviewItem> _items = List.of(widget.items);
  bool _chrome = true;
  bool _busy = false;

  ImagePreviewItem get _current => _items[_index];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final strings = AppStrings.of(context);
    final multiple = _items.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              return GestureDetector(
                // 单击切换控件显隐
                onTap: () => setState(() => _chrome = !_chrome),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: SizedBox.expand(
                    child: _ImageBody(item: _items[i]),
                  ),
                ),
              );
            },
          ),
          // 顶部：返回 + 文件名 + 页码
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _current.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (multiple)
                            Text(
                              '${_index + 1} / ${_items.length}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 两侧翻页箭头
          if (multiple) ...[
            _SideArrow(
              visible: _chrome && _index > 0,
              alignment: Alignment.centerLeft,
              icon: Icons.chevron_left_rounded,
              onTap: () => _go(_index - 1),
            ),
            _SideArrow(
              visible: _chrome && _index < _items.length - 1,
              alignment: Alignment.centerRight,
              icon: Icons.chevron_right_rounded,
              onTap: () => _go(_index + 1),
            ),
          ],
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
                        if (_current.onDelete != null)
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

  void _go(int target) {
    if (target < 0 || target >= _items.length) return;
    _pageCtrl.animateToPage(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/QShell');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final target = File('${dir.path}/${_current.name}');
      await target.writeAsBytes(_current.bytes ?? const <int>[]);
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
      message: '确定删除「${_current.name}」？',
      confirmText: '删除',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final done = await _current.onDelete?.call() ?? false;
      if (!mounted) return;
      if (!done) {
        showGlassToast(context, '删除失败', tone: GlassToastTone.error);
        return;
      }
      // 删掉后从列表移除，删空了就退出
      _items = List.of(_items)..removeAt(_index);
      if (_items.isEmpty) {
        Navigator.of(context).maybePop();
        return;
      }
      if (_index >= _items.length) _index = _items.length - 1;
      setState(() {});
      _pageCtrl.jumpToPage(_index);
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

/// 两侧翻页箭头
class _SideArrow extends StatelessWidget {
  const _SideArrow({
    required this.visible,
    required this.alignment,
    required this.icon,
    required this.onTap,
  });

  final bool visible;
  final Alignment alignment;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Material(
            color: Colors.black.withValues(alpha: 0.42),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: visible ? onTap : null,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, size: 24, color: Colors.white),
              ),
            ),
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
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

/// 单张图片：没有字节时走懒加载，加载中显示进度。
class _ImageBody extends StatefulWidget {
  const _ImageBody({required this.item});

  final ImagePreviewItem item;

  @override
  State<_ImageBody> createState() => _ImageBodyState();
}

class _ImageBodyState extends State<_ImageBody> {
  List<int>? _bytes;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _bytes = widget.item.bytes;
    if (_bytes == null) _startLoad();
  }

  Future<void> _startLoad() async {
    final loader = widget.item.loader;
    if (loader == null) return;
    setState(() => _loading = true);
    try {
      final data = await loader();
      if (!mounted) return;
      setState(() {
        _bytes = data;
        _loading = false;
        _failed = data == null;
      });
      // 回写，避免再次翻回来时重复下载
      if (data != null) widget.item.bytes = data;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Image.memory(
        Uint8List.fromList(_bytes!),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => const Center(
          child: Text('无法解码这张图片',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_failed ? Icons.cloud_off_rounded : Icons.image_outlined,
              size: 44, color: Colors.white38),
          const SizedBox(height: 10),
          Text(
            _failed ? '加载失败，点击重试' : '尚未加载',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (_failed)
            TextButton(
              onPressed: _startLoad,
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }
}
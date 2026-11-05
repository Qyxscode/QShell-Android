import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../design/glass_dialog.dart';
import '../../design/glass_input_dialog.dart';
import '../../design/glass_sheet.dart';
import '../../design/glass_toast.dart';
import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import 'file_icon.dart';
import 'image_preview_page.dart';

/// 应用私有文件夹的管理页。
///
/// 预览图片、临时下载转存的文件都落在这里，之前在系统文件管理器里很难找，
/// 所以单独开一个入口直接浏览、改名、删除。
class AppFolderPage extends StatefulWidget {
  const AppFolderPage({super.key});

  @override
  State<AppFolderPage> createState() => _AppFolderPageState();
}

class _AppFolderPageState extends State<AppFolderPage> {
  static const _folderName = 'QShell';

  Directory? _dir;
  List<FileSystemEntity> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/$_folderName');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final items = dir.listSync()
        ..sort((a, b) {
          final aDir = a is Directory;
          final bDir = b is Directory;
          if (aDir != bDir) return aDir ? -1 : 1;
          return _baseName(a).toLowerCase().compareTo(
                _baseName(b).toLowerCase(),
              );
        });
      if (!mounted) return;
      setState(() {
        _dir = dir;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showGlassToast(context, '读取失败：$e', tone: GlassToastTone.error);
    }
  }

  String _baseName(FileSystemEntity e) =>
      e.path.split(Platform.pathSeparator).last;

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  int get _totalSize {
    var sum = 0;
    for (final item in _items) {
      if (item is File) {
        try {
          sum += item.lengthSync();
        } catch (_) {}
      }
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('应用文件夹'),
        actions: [
          IconButton(
            tooltip: strings.filesRefresh,
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // 路径 + 占用空间
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Icon(Icons.folder_special_rounded,
                    size: 16, color: tokens.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _dir?.path ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      fontSize: 11,
                      color: tokens.textDisabled,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_items.length} 项 · ${_fmtSize(_totalSize)}',
                  style: text.labelSmall?.copyWith(
                    fontSize: 11,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_open_rounded,
                                size: 44, color: tokens.textDisabled),
                            const SizedBox(height: 12),
                            Text(
                              '这个文件夹还是空的',
                              style: text.bodyMedium
                                  ?.copyWith(color: tokens.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '预览图片时的「保存」会存到这里',
                              style: text.labelSmall
                                  ?.copyWith(color: tokens.textDisabled),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final name = _baseName(item);
                          final isDir = item is Directory;
                          final size = item is File
                              ? (() {
                                  try {
                                    return _fmtSize(item.lengthSync());
                                  } catch (_) {
                                    return '--';
                                  }
                                })()
                              : '文件夹';
                          return RemoteEntryTile(
                            name: name,
                            isDirectory: isDir,
                            subtitle: size,
                            onTap: () => _open(item),
                            onLongPress: () => _showActions(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(FileSystemEntity item) async {
    if (item is Directory) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _SubFolderPage(dir: item),
        ),
      );
      await _load();
      return;
    }
    if (item is! File) return;
    final name = _baseName(item);
    if (isPreviewableImageName(name)) {
      final bytes = await item.readAsBytes();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImagePreviewPage(
            bytes: bytes,
            name: name,
            onDelete: () async {
              try {
                await item.delete();
                await _load();
                return true;
              } catch (_) {
                return false;
              }
            },
          ),
        ),
      );
      await _load();
      return;
    }
    await OpenFilex.open(item.path);
  }

  Future<void> _showActions(FileSystemEntity item) async {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final name = _baseName(item);
    final strings = AppStrings.of(context);

    final action = await showGlassSheet<String>(
      context,
      title: name,
      builder: (context, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MenuRow(
            icon: Icons.open_in_new_rounded,
            label: strings.filesOpen,
            color: tokens.accent,
            tokens: tokens,
            text: text,
            onTap: () => close('open'),
          ),
          _MenuRow(
            icon: Icons.drive_file_rename_outline_rounded,
            label: '重命名',
            color: tokens.textPrimary,
            tokens: tokens,
            text: text,
            onTap: () => close('rename'),
          ),
          _MenuRow(
            icon: Icons.delete_outline_rounded,
            label: strings.commonDelete,
            color: tokens.danger,
            tokens: tokens,
            text: text,
            onTap: () => close('delete'),
          ),
        ],
      ),
    );

    switch (action) {
      case 'open':
        await _open(item);
      case 'rename':
        await _rename(item);
      case 'delete':
        await _remove(item);
    }
  }

  Future<void> _rename(FileSystemEntity item) async {
    final name = _baseName(item);
    final next = await showGlassInput(
      context,
      title: '重命名',
      label: '文件名',
      initial: name,
    );
    if (next == null || next.isEmpty || next == name || !mounted) return;
    try {
      final parent = item.path.substring(
        0,
        item.path.length - name.length,
      );
      await item.rename('$parent$next');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, '重命名失败：$e', tone: GlassToastTone.error);
    }
  }

  Future<void> _remove(FileSystemEntity item) async {
    final name = _baseName(item);
    final ok = await showGlassConfirm(
      context,
      title: AppStrings.of(context).commonDelete,
      message: '确定删除「$name」？',
      confirmText: AppStrings.of(context).commonDelete,
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await item.delete(recursive: true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, '删除失败：$e', tone: GlassToastTone.error);
    }
  }
}

/// 子文件夹浏览（只读 + 删除），避免为多级目录再写一套管理器。
class _SubFolderPage extends StatefulWidget {
  const _SubFolderPage({required this.dir});

  final Directory dir;

  @override
  State<_SubFolderPage> createState() => _SubFolderPageState();
}

class _SubFolderPageState extends State<_SubFolderPage> {
  List<FileSystemEntity> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    try {
      setState(() {
        _items = widget.dir.listSync()
          ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
      });
    } catch (_) {}
  }

  String _baseName(FileSystemEntity e) =>
      e.path.split(Platform.pathSeparator).last;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(_baseName(widget.dir))),
      body: _items.isEmpty
          ? Center(
              child: Text(
                '空文件夹',
                style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return RemoteEntryTile(
                  name: _baseName(item),
                  isDirectory: item is Directory,
                  subtitle: item is File ? '' : '文件夹',
                  onTap: item is Directory
                      ? () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _SubFolderPage(dir: item),
                            ),
                          );
                          _load();
                        }
                      : () => OpenFilex.open(item.path),
                );
              },
            ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.tokens,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final AppTokens tokens;
  final TextTheme text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: text.bodyMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 与 file_actions 里的判断保持一致，避免两处逻辑漂移。
bool isPreviewableImageName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return false;
  const exts = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif',
  };
  return exts.contains(name.substring(dot + 1).toLowerCase());
}

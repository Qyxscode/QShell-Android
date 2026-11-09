import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../design/glass_dialog.dart';
import '../../design/glass_input_dialog.dart';
import '../../design/glass_sheet.dart';
import '../../design/glass_toast.dart';
import '../../design/instant_route.dart';
import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/download_helper.dart';
import '../../services/system_service.dart';
import 'file_actions.dart';
import 'file_icon.dart';
import 'image_preview_page.dart';
import 'video_preview_page.dart';

/// 下载文件夹的管理页。
///
/// 位置跟随「设置 → 下载位置」：应用私有目录 / Download/QShell。
/// 两者数据来源不同（后者只能通过 MediaStore 读），所以分开渲染。
class AppFolderPage extends StatefulWidget {
  const AppFolderPage({super.key});

  @override
  State<AppFolderPage> createState() => _AppFolderPageState();
}

class _AppFolderPageState extends State<AppFolderPage> {
  Directory? _dir;
  List<FileSystemEntity> _files = const [];
  List<DownloadEntry> _downloads = const [];
  String _location = DownloadHelper.appLocation;
  bool _loading = true;

  /// 多选模式：长按任意一项进入，用于批量删除
  bool _selecting = false;
  final Set<String> _selected = <String>{};

  String _keyOfItem(FileSystemEntity e) => e.path;

  String _keyOfDownload(DownloadEntry d) => d.uri;

  List<String> get _allKeys => _isDownloads
      ? _downloads.map(_keyOfDownload).toList()
      : _files.map(_keyOfItem).toList();

  void _enterSelect(String key) {
    setState(() {
      _selecting = true;
      _selected
        ..clear()
        ..add(key);
    });
  }

  void _exitSelect() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelect(String key) {
    setState(() {
      if (!_selected.remove(key)) _selected.add(key);
    });
  }

  void _toggleSelectAll() {
    final keys = _allKeys;
    setState(() {
      if (_selected.length == keys.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(keys);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    if (count == 0) return;
    final ok = await showGlassConfirm(
      context,
      title: '删除选中项',
      message: '确定删除选中的 $count 项？删除后无法恢复。',
      confirmText: '删除',
      danger: true,
    );
    if (ok != true || !mounted) return;
    var failed = 0;
    if (_isDownloads) {
      for (final entry in _downloads) {
        if (!_selected.contains(_keyOfDownload(entry))) continue;
        final done = await SystemService.deleteDownload(entry.uri);
        if (!done) failed++;
      }
    } else {
      for (final item in _files) {
        if (!_selected.contains(_keyOfItem(item))) continue;
        try {
          await item.delete(recursive: true);
        } catch (_) {
          failed++;
        }
      }
    }
    _exitSelect();
    await _load();
    if (!mounted) return;
    showGlassToast(
      context,
      failed == 0 ? '已删除 $count 项' : '已删除 ${count - failed} 项，$failed 项失败',
      tone: failed == 0 ? GlassToastTone.success : GlassToastTone.error,
    );
  }

  bool get _isDownloads => _location == DownloadHelper.downloadsLocation;

  int get _count => _isDownloads ? _downloads.length : _files.length;

  int get _totalSize {
    if (_isDownloads) {
      return _downloads.fold(0, (sum, d) => sum + d.size);
    }
    var sum = 0;
    for (final item in _files) {
      if (item is File) {
        try {
          sum += item.lengthSync();
        } catch (_) {}
      }
    }
    return sum;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // 离开文件夹就清掉「打开」留下的临时文件
    clearOpenCache();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final location = await DownloadHelper.getLocation();
    if (location == DownloadHelper.downloadsLocation) {
      // 读 MediaStore 内容需要媒体权限，第一次进来先请求
      await SystemService.requestMediaImages();
      final list = await SystemService.listDownloads();
      if (!mounted) return;
      setState(() {
        _location = location;
        _downloads = list;
        _files = const [];
        _dir = null;
        _loading = false;
      });
      return;
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/QShell');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final files = dir.listSync()
        ..sort((a, b) {
          final aDir = a is Directory;
          final bDir = b is Directory;
          if (aDir != bDir) return aDir ? -1 : 1;
          return _baseName(a)
              .toLowerCase()
              .compareTo(_baseName(b).toLowerCase());
        });
      if (!mounted) return;
      setState(() {
        _location = location;
        _dir = dir;
        _files = files;
        _downloads = const [];
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

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final strings = AppStrings.of(context);

    return Scaffold(
      // 玻璃主题靠壁纸透出做材质，MD3 没有壁纸层，透明只会让页面「消失」
      backgroundColor: tokens.glass ? Colors.transparent : tokens.background,
      appBar: AppBar(
        leading: _selecting
            ? IconButton(
                tooltip: '取消',
                onPressed: _exitSelect,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Text(
          _selecting
              ? '已选 ${_selected.length} 项'
              : (_isDownloads ? '下载文件夹' : '应用文件夹'),
        ),
        actions: [
          if (_selecting)
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(
                _selected.length == _count ? '取消全选' : '全选',
              ),
            )
          else ...[
            IconButton(
              tooltip: '批量选择',
              onPressed: _count == 0
                  ? null
                  : () {
                      setState(() => _selecting = true);
                    },
              icon: const Icon(Icons.checklist_rounded),
            ),
            IconButton(
              tooltip: strings.filesRefresh,
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 当前位置 + 切换
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 6, 6),
            child: Row(
              children: [
                Icon(
                  _isDownloads
                      ? Icons.download_rounded
                      : Icons.folder_special_rounded,
                  size: 16,
                  color: tokens.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isDownloads ? 'Download/QShell' : (_dir?.path ?? ''),
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
                  '$_count 项 · ${_fmtSize(_totalSize)}',
                  style: text.labelSmall?.copyWith(
                    fontSize: 11,
                    color: tokens.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: _switchLocation,
                  child: const Text('切换', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _count == 0
                    ? _empty(tokens, text)
                    : _list(tokens, text),
          ),
          if (_selecting)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _selected.isEmpty ? null : _deleteSelected,
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text('删除 ${_selected.length} 项'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(AppTokens tokens, TextTheme text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isDownloads
                ? Icons.download_done_rounded
                : Icons.folder_open_rounded,
            size: 44,
            color: tokens.textDisabled,
          ),
          const SizedBox(height: 12),
          Text(
            _isDownloads ? 'Download/QShell 里还没有文件' : '这个文件夹还是空的',
            style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            '下载与「保存」会自动放到这里',
            style: text.labelSmall?.copyWith(color: tokens.textDisabled),
          ),
        ],
      ),
    );
  }

  Widget _list(AppTokens tokens, TextTheme text) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
      itemCount: _count,
      itemBuilder: (context, index) {
        if (_isDownloads) {
          final d = _downloads[index];
          final key = _keyOfDownload(d);
          return RemoteEntryTile(
            name: d.name,
            isDirectory: false,
            subtitle: _fmtSize(d.size),
            trailing: _selecting
                ? Checkbox(
                    value: _selected.contains(key),
                    onChanged: (_) => _toggleSelect(key),
                  )
                : null,
            onTap: _selecting
                ? () => _toggleSelect(key)
                : () => _openDownload(d),
            onLongPress: _selecting
                ? null
                : () => _showDownloadActions(d),
          );
        }
        final item = _files[index];
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
        final showThumb = item is File && isPreviewableImageName(name);
        final key = _keyOfItem(item);
        return RemoteEntryTile(
          name: name,
          isDirectory: isDir,
          subtitle: size,
          thumbnail: showThumb
              ? Image.file(
                  item,
                  fit: BoxFit.cover,
                  cacheWidth: 120,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                )
              : null,
          trailing: _selecting
              ? Checkbox(
                  value: _selected.contains(key),
                  onChanged: (_) => _toggleSelect(key),
                )
              : null,
          onTap: _selecting ? () => _toggleSelect(key) : () => _open(item),
          onLongPress: _selecting ? null : () => _showFileActions(item),
        );
      },
    );
  }

  Future<void> _switchLocation() async {
    final strings = AppStrings.of(context);
    final choice = await showGlassSheet<String>(
      context,
      title: '下载位置',
      builder: (context, close) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(strings.settingsAppDir),
            subtitle: Text(strings.settingsAppDirDesc),
            trailing:
                !_isDownloads ? const Icon(Icons.check_rounded) : null,
            onTap: () => close(DownloadHelper.appLocation),
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: Text(strings.settingsDownloads),
            subtitle: Text(strings.settingsDownloadsDesc),
            trailing: _isDownloads ? const Icon(Icons.check_rounded) : null,
            onTap: () => close(DownloadHelper.downloadsLocation),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    await DownloadHelper.setLocation(choice);
    await _load();
  }

  // ---------- 应用目录 ----------

  Future<void> _open(FileSystemEntity item) async {
    if (item is Directory) {
      if (!mounted) return;
      await Navigator.of(context).push(
        InstantPageRoute<void>(builder: (_) => _SubFolderPage(dir: item)),
      );
      await _load();
      return;
    }
    if (item is! File) return;
    final name = _baseName(item);
    if (isPreviewableImageName(name)) {
      // 收集同目录所有图片，预览时可左右翻页
      final images = <File>[];
      var startIndex = 0;
      for (final e in _files) {
        if (e is File && isPreviewableImageName(_baseName(e))) {
          if (e.path == item.path) startIndex = images.length;
          images.add(e);
        }
      }
      final items = <ImagePreviewItem>[];
      for (final f in images) {
        try {
          items.add(
            ImagePreviewItem(
              name: _baseName(f),
              bytes: await f.readAsBytes(),
              onDelete: () async {
                try {
                  await f.delete();
                  await _load();
                  return true;
                } catch (_) {
                  return false;
                }
              },
            ),
          );
        } catch (_) {
          // 读不出来的跳过
        }
      }
      if (items.isEmpty || !mounted) return;
      await Navigator.of(context).push(
        InstantPageRoute<void>(
          builder: (_) => ImagePreviewPage(
            items: items,
            initialIndex: startIndex.clamp(0, items.length - 1),
          ),
        ),
      );
      await _load();
      return;
    }
    await OpenFilex.open(item.path);
  }

  Future<void> _showFileActions(FileSystemEntity item) async {
    final action = await _menu(_baseName(item));
    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        await _open(item);
      case 'select':
        _enterSelect(_keyOfItem(item));
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
      final parent = item.path.substring(0, item.path.length - name.length);
      await item.rename('$parent$next');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, '重命名失败：$e', tone: GlassToastTone.error);
    }
  }

  Future<void> _remove(FileSystemEntity item) async {
    final ok = await showGlassConfirm(
      context,
      title: AppStrings.of(context).commonDelete,
      message: '确定删除「${_baseName(item)}」？',
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

  // ---------- Download/QShell ----------

  Future<void> _openDownload(DownloadEntry entry) async {
    try {
      // 图片：小文件，直接读进内存做预览（可左右翻页 / 删除）
      if (isPreviewableImageName(entry.name)) {
        final bytes = await SystemService.readDownload(entry.uri);
        if (bytes == null) {
          if (!mounted) return;
          showGlassToast(context, '读取失败', tone: GlassToastTone.error);
          return;
        }
        if (!mounted) return;
        await Navigator.of(context).push(
          InstantPageRoute<void>(
            builder: (_) => ImagePreviewPage.single(
              bytes: bytes,
              name: entry.name,
              onDelete: () async => SystemService.deleteDownload(entry.uri),
            ),
          ),
        );
        await _load();
        return;
      }

      // 视频/音频/其它：MediaStore 里的内容不能按路径打开，先流式复制到缓存。
      // 不能走 readDownload —— 几百 MB 的视频会直接撑爆内存。
      final dir = await getTemporaryDirectory();
      final target = File('${dir.path}/${entry.name}');
      final copied = await SystemService.copyDownload(entry.uri, target.path);
      if (!copied) {
        if (!mounted) return;
        showGlassToast(context, '读取失败', tone: GlassToastTone.error);
        return;
      }
      if (!mounted) return;
      if (isPlayableMedia(entry.name)) {
        await Navigator.of(context).push(
          InstantPageRoute<void>(
            builder: (_) => VideoPreviewPage(
              name: entry.name,
              filePath: target.path,
            ),
          ),
        );
        return;
      }
      await OpenFilex.open(target.path);
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, '打开失败：$e', tone: GlassToastTone.error);
    }
  }

  Future<void> _showDownloadActions(DownloadEntry entry) async {
    final action = await _menu(entry.name);
    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        await _openDownload(entry);
      case 'select':
        _enterSelect(_keyOfDownload(entry));
      case 'delete':
        final ok = await showGlassConfirm(
          context,
          title: AppStrings.of(context).commonDelete,
          message: '确定删除「${entry.name}」？',
          confirmText: AppStrings.of(context).commonDelete,
          danger: true,
        );
        if (!ok || !mounted) return;
        final done = await SystemService.deleteDownload(entry.uri);
        if (!mounted) return;
        if (done) {
          await _load();
        } else {
          showGlassToast(context, '删除失败', tone: GlassToastTone.error);
        }
    }
  }

  /// 共用操作菜单。重命名只对应用内目录开放（MediaStore 改名需要额外权限）。
  Future<String?> _menu(String title) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final strings = AppStrings.of(context);
    return showGlassSheet<String>(
      context,
      title: title,
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
          if (!_isDownloads)
            _MenuRow(
              icon: Icons.drive_file_rename_outline_rounded,
              label: '重命名',
              color: tokens.textPrimary,
              tokens: tokens,
              text: text,
              onTap: () => close('rename'),
            ),
          _MenuRow(
            icon: Icons.checklist_rounded,
            label: '多选（批量删除）',
            color: tokens.accent,
            tokens: tokens,
            text: text,
            onTap: () => close('select'),
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
  }
}

/// 子文件夹（只读浏览）。
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

  @override
  void dispose() {
    // 离开文件夹就清掉「打开」留下的临时文件
    clearOpenCache();
    super.dispose();
  }

  void _load() {
    try {
      setState(() {
        _items = widget.dir.listSync()
          ..sort(
            (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
          );
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
      backgroundColor: tokens.glass ? Colors.transparent : tokens.background,
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
                            InstantPageRoute<void>(
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
              Text(label, style: text.bodyMedium?.copyWith(color: color)),
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

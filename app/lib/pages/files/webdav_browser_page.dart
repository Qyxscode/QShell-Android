import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/download_helper.dart';
import '../../services/tools/webdav_client.dart';
import 'file_icon.dart';
import 'file_actions.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';

/// 传输被用户取消。
class _TransferCancelled implements Exception {
  const _TransferCancelled();
}

/// WebDAV 浏览器：列目录、下载、上传、删除、新建目录。
class WebdavBrowserPage extends StatefulWidget {
  const WebdavBrowserPage({
    super.key,
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  final String baseUrl;
  final String username;
  final String password;

  @override
  State<WebdavBrowserPage> createState() => _WebdavBrowserPageState();
}

class _WebdavBrowserPageState extends State<WebdavBrowserPage> {
  late final WebdavClient _client = WebdavClient(
    baseUrl: widget.baseUrl,
    username: widget.username,
    password: widget.password,
  );

  String _path = '';
  List<WebdavEntry> _entries = const <WebdavEntry>[];
  bool _loading = true;
  String? _error;

  DateTime? _lastBackAt;
  String? _transferName;
  int _transferTotal = 0;
  int _transferDone = 0;
  bool _transferUpload = false;
  bool _cancelRequested = false;
  http.Client? _uploadClient;

  @override
  void initState() {
    super.initState();
    _list('');
  }

  Future<void> _list(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _client.list(path);
      if (!mounted) return;
      setState(() {
        _path = path;
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  String get _parentPath {
    if (_path.isEmpty) return '';
    final trimmed =
        _path.endsWith('/') ? _path.substring(0, _path.length - 1) : _path;
    final index = trimmed.lastIndexOf('/');
    if (index <= 0) return '';
    return trimmed.substring(0, index);
  }

  /// 显示用的路径：根显示 `/`，其余显示 `/a/b`。
  String get _displayPath => _path.isEmpty ? '/' : '/$_path';

  /// 单击 / 长按文件：操作菜单。
  Future<void> _showEntryActions(WebdavEntry entry) async {
    final action = await showFileActionSheet(
      context,
      name: entry.name,
      isDirectory: entry.isDirectory,
      subtitle: entry.isDirectory ? AppStrings.of(context).browserFolder : _fmt(entry.size),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case FileAction.open:
        await _open(entry);
      case FileAction.download:
        await _download(entry);
      case FileAction.rename:
        await _rename(entry);
      case FileAction.properties:
        await _properties(entry);
      case FileAction.delete:
        await _delete(entry);
    }
  }

  Future<void> _open(WebdavEntry entry) async {
    setState(() {
      _transferName = entry.name;
      _transferTotal = entry.size;
      _transferDone = 0;
      _transferUpload = false;
      _cancelRequested = false;
    });
    try {
      final bytes = await _client.download(
        entry.href,
        onProgress: (received, total) {
          if (_cancelRequested) throw const _TransferCancelled();
          if (!mounted) return;
          setState(() {
            _transferDone = received;
            if (total > 0) _transferTotal = total;
          });
        },
      );
      final dir = await Directory.systemTemp.createTemp('qshell_open');
      final file = File('${dir.path}/${entry.name}');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } on _TransferCancelled {
      // 忽略
    } catch (e) {
      if (mounted) _toast(AppStrings.of(context).browserOpenFailedTemplate.replaceAll('{msg}', '$e'));
    } finally {
      if (mounted) setState(() => _transferName = null);
    }
  }

  Future<void> _rename(WebdavEntry entry) async {
    final newName = await askNewName(context, entry.name);
    if (newName == null || !mounted) return;
    try {
      final slash = entry.href.lastIndexOf('/');
      final dir = slash < 0 ? '' : entry.href.substring(0, slash + 1);
      await _client.rename(entry.href, '$dir$newName');
      if (!mounted) return;
      _toast(AppStrings.of(context).browserRenamedTemplate.replaceAll('{name}', newName));
      await _list(_path);
    } catch (e) {
      if (mounted) _toast(AppStrings.of(context).browserRenameFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }

  Future<void> _properties(WebdavEntry entry) {
    return showFileProperties(
      context,
      name: entry.name,
      path: entry.href,
      isDirectory: entry.isDirectory,
      sizeText: entry.isDirectory ? null : _fmt(entry.size),
    );
  }
  Future<void> _download(WebdavEntry entry) async {
    setState(() {
      _transferName = entry.name;
      _transferTotal = entry.size;
      _transferDone = 0;
      _transferUpload = false;
      _cancelRequested = false;
    });
    try {
      final bytes = await _client.download(
        entry.href,
        onProgress: (received, total) {
          if (_cancelRequested) throw const _TransferCancelled();
          if (!mounted) return;
          setState(() {
            _transferDone = received;
            if (total > 0) _transferTotal = total;
          });
        },
      );
      final finalPath = await DownloadHelper.saveBytes(entry.name, bytes);
      if (!mounted) return;
      setState(() => _transferName = null);
      _toast('已下载 ${entry.name}（${_fmt(bytes.length)}）\n$finalPath');
    } on _TransferCancelled {
      if (!mounted) return;
      setState(() => _transferName = null);
      _toast('已取消下载 ${entry.name}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _transferName = null);
      _toast(AppStrings.of(context).browserDownloadFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }

  Future<void> _upload() async {
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _transferName = picked.name;
        _transferTotal = bytes.length;
        _transferDone = 0;
        _transferUpload = true;
        _cancelRequested = false;
      });
      final target =
          _path.isEmpty ? picked.name : '$_path/${picked.name}';
      final client = http.Client();
      _uploadClient = client;
      await _client.upload(target, bytes, client: client);
      _uploadClient = null;
      if (!mounted) return;
      setState(() {
        _transferDone = bytes.length;
        _transferName = null;
      });
      _toast('已上传 ${picked.name}');
      await _list(_path);
    } on _TransferCancelled {
      if (!mounted) return;
      setState(() => _transferName = null);
      _toast(AppStrings.of(context).browserUploadCancelled);
      await _list(_path);
    } catch (e) {
      _uploadClient = null;
      if (!mounted) return;
      setState(() => _transferName = null);
      _toast(_cancelRequested ? AppStrings.of(context).browserUploadCancelled : '上传失败：$e');
    } finally {
      _uploadClient = null;
    }
  }

  void _cancelTransfer() {
    setState(() => _cancelRequested = true);
    // 上传是单个 PUT，中断连接
    _uploadClient?.close();
  }

  /// 返回：子目录先回上级；到根目录（或回上级失败）时「再按一次」退出。
  Future<void> _handleBack() async {
    if (_path != '/' && _path.isNotEmpty) {
      final before = _path;
      await _list(_parentPath);
      if (_path != before) return;
    }
    final now = DateTime.now();
    final last = _lastBackAt;
    if (last != null && now.difference(last) <= const Duration(seconds: 2)) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _lastBackAt = now;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('再按一次返回退出'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _delete(WebdavEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.of(context).commonDelete),
        content: Text(AppStrings.of(context).browserDeleteConfirmTemplate.replaceAll('{name}', entry.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of(context).browserCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.of(context).browserDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _client.delete(entry.href);
      if (!mounted) return;
      _toast(AppStrings.of(context).browserDeletedTemplate.replaceAll('{name}', entry.name));
      await _list(_path);
    } catch (e) {
      if (!mounted) return;
      _toast(AppStrings.of(context).browserDeleteFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }

  Future<void> _mkdir() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.of(context).browserNewFolder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: AppStrings.of(context).browserFolderName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.of(context).browserCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(AppStrings.of(context).browserCreate),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final target = _path.isEmpty ? name : '$_path/$name';
      await _client.mkdir(target);
      if (!mounted) return;
      await _list(_path);
    } catch (e) {
      if (!mounted) return;
      _toast(AppStrings.of(context).browserCreateFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _fmt(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final transferring = _transferName != null;
    final progress =
        _transferTotal <= 0 ? null : (_transferDone / _transferTotal).clamp(0.0, 1.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('WebDAV · ${widget.username}'),
            Text(
              _displayPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).browserNewFolder,
            onPressed: _loading ? null : _mkdir,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          IconButton(
            tooltip: '上传',
            onPressed: _loading ? null : _upload,
            icon: const Icon(Icons.upload_file_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (transferring)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _transferUpload
                                ? Icons.upload_rounded
                                : Icons.download_rounded,
                            size: 16,
                            color: tokens.accent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_transferUpload ? "上传" : "下载"} $_transferName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall
                                  ?.copyWith(color: tokens.textPrimary),
                            ),
                          ),
                          Text(
                            progress == null
                                ? ''
                                : '${(progress * 100).round()}%',
                            style: text.labelSmall
                                ?.copyWith(color: tokens.textSecondary),
                          ),
                          IconButton(
                            tooltip: '取消',
                            visualDensity: VisualDensity.compact,
                            onPressed: _cancelTransfer,
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: tokens.textSecondary),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: tokens.track,
                            color: tokens.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_fmt(_transferDone)} / ${_fmt(_transferTotal)}',
                        style: text.labelSmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  size: 40, color: tokens.danger),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: text.bodyMedium
                                    ?.copyWith(color: tokens.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => _list(_path),
                                child: Text(AppStrings.of(context).browserRetry),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final hasParent = _path.isNotEmpty;
                          final itemCount = (hasParent ? 1 : 0) +
                              _entries.length +
                              (_entries.isEmpty ? 1 : 0);
                          return ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(12, 8, 12, 24),
                            itemCount: itemCount,
                            itemBuilder: (context, index) {
                              if (hasParent && index == 0) {
                                return ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  leading: Icon(Icons.arrow_upward_rounded,
                                      size: 22, color: tokens.accent),
                                  title: Text('返回上级',
                                      style: text.bodyMedium?.copyWith(
                                          color: tokens.textPrimary)),
                                  onTap: () => _list(_parentPath),
                                );
                              }
                              final i = hasParent ? index - 1 : index;
                              if (i < _entries.length) {
                                final entry = _entries[i];
                                return RemoteEntryTile(
                                  name: entry.name,
                                  isDirectory: entry.isDirectory,
                                  iconColor: entry.isDirectory
                                      ? tokens.accent
                                      : tokens.textSecondary,
                                  textColor: tokens.textPrimary,
                                  subtitle: entry.isDirectory
                                      ? AppStrings.of(context).browserFolder
                                      : _fmt(entry.size),
                                  onTap: entry.isDirectory
                                      ? () => _list(entry.href)
                                      : () => _showEntryActions(entry),
                                  onLongPress: () => _showEntryActions(entry),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 40),
                                child: Center(
                                  child: Text(
                                    AppStrings.of(context).browserEmptyDir,
                                    style: text.bodyMedium?.copyWith(
                                        color: tokens.textSecondary),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    ),
  );
  }
}
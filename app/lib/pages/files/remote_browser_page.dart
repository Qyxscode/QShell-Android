import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/download_helper.dart';
import '../../services/files/ftp_fs.dart';
import '../../services/files/remote_fs.dart';
import '../../services/files/smb_fs.dart';
import '../../services/files/webdav_fs.dart';
import 'file_icon.dart';
import 'file_actions.dart';

/// 通用远程文件浏览器：SFTP 之外的 FTP / WebDAV / SMB 共用。
class RemoteBrowserPage extends StatefulWidget {
  const RemoteBrowserPage({super.key, required this.server});

  final RemoteServer server;

  @override
  State<RemoteBrowserPage> createState() => _RemoteBrowserPageState();
}

class _RemoteBrowserPageState extends State<RemoteBrowserPage> {
  RemoteFs? _fs;
  String _path = '';
  List<RemoteEntry> _entries = const <RemoteEntry>[];
  bool _loading = true;
  String? _error;

  DateTime? _lastBackAt;
  String? _transferName;
  int _transferTotal = 0;
  int _transferDone = 0;
  bool _transferUpload = false;
  bool _cancelRequested = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _fs?.dispose();
    super.dispose();
  }

  String get _kindLabel => switch (widget.server.kind) {
        'webdav' => 'WebDAV',
        'ftp' => 'FTP',
        'smb' => 'SMB',
        _ => widget.server.kind.toUpperCase(),
      };

  String get _displayPath => _path.isEmpty ? '/' : '/$_path';

  String get _parentPath {
    if (_path.isEmpty) return '';
    final index = _path.lastIndexOf('/');
    if (index <= 0) return '';
    return _path.substring(0, index);
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final server = widget.server;
      final fs = switch (server.kind) {
        'webdav' => await WebdavFs.connect(server),
        'ftp' => await FtpFs.connect(server),
        'smb' => await SmbFs.connect(server),
        // 协议不支持：用文案模板，避免在 await 之后直接取 context
        _ => throw Exception(server.kind),
      };
      _fs = fs;
      await _list('');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppStrings.of(context).browserConnectFailedTemplate.replaceAll('{msg}', '$e');
      });
    }
  }

  Future<void> _list(String path) async {
    final fs = _fs;
    if (fs == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await fs.list(path);
      entries.sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
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
        _error = AppStrings.of(context).browserReadDirFailedTemplate.replaceAll('{msg}', '$e');
      });
    }
  }

  /// 单击 / 长按文件：操作菜单。
  Future<void> _showEntryActions(RemoteEntry entry) async {
    final action = await showFileActionSheet(
      context,
      name: entry.name,
      isDirectory: entry.isDirectory,
      subtitle: entry.isDirectory ? AppStrings.of(context).browserFolder : _fmtSize(entry.size),
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

  Future<void> _open(RemoteEntry entry) async {
    final fs = _fs;
    if (fs == null) return;
    setState(() {
      _transferName = entry.name;
      _transferTotal = entry.size;
      _transferDone = 0;
      _transferUpload = false;
      _cancelRequested = false;
    });
    try {
      await downloadToCacheAndOpen(entry.name, (localPath) async {
        await fs.download(
          entry.path,
          localPath,
          onProgress: (received, total) {
            if (!mounted) return;
            setState(() {
              _transferDone = received;
              if (total > 0) _transferTotal = total;
            });
          },
          isCancelled: () => _cancelRequested,
        );
      });
    } on TransferCancelled {
      // 忽略
    } catch (e) {
      if (mounted) _toast(AppStrings.of(context).browserOpenFailedTemplate.replaceAll('{msg}', '$e'));
    } finally {
      if (mounted) setState(() => _transferName = null);
    }
  }

  Future<void> _rename(RemoteEntry entry) async {
    final fs = _fs;
    if (fs == null) return;
    final newName = await askNewName(context, entry.name);
    if (newName == null || !mounted) return;
    try {
      await fs.rename(entry, newName);
      if (!mounted) return;
      _toast(AppStrings.of(context).browserRenamedTemplate.replaceAll('{name}', newName));
      await _list(_path);
    } catch (e) {
      if (mounted) _toast(AppStrings.of(context).browserRenameFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }

  Future<void> _properties(RemoteEntry entry) {
    return showFileProperties(
      context,
      name: entry.name,
      path: entry.path,
      isDirectory: entry.isDirectory,
      sizeText: entry.isDirectory ? null : _fmtSize(entry.size),
    );
  }
  Future<void> _download(RemoteEntry entry) async {
    final fs = _fs;
    if (fs == null) return;
    setState(() {
      _transferName = entry.name;
      _transferTotal = entry.size;
      _transferDone = 0;
      _transferUpload = false;
      _cancelRequested = false;
    });
    try {
      final tempPath = await DownloadHelper.tempPath(entry.name);
      await fs.download(
        entry.path,
        tempPath,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _transferDone = received;
            if (total > 0) _transferTotal = total;
          });
        },
        isCancelled: () => _cancelRequested,
      );
      final finalPath = await DownloadHelper.finalize(tempPath, entry.name);
      if (!mounted) return;
      setState(() => _transferName = null);
      _toast('已下载 ${entry.name}\n$finalPath');
    } on TransferCancelled {
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
    final fs = _fs;
    if (fs == null) return;
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
      final target = _path.isEmpty ? picked.name : '$_path/${picked.name}';
      await fs.upload(
        target,
        bytes,
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() => _transferDone = sent);
        },
        isCancelled: () => _cancelRequested,
      );
      if (!mounted) return;
      setState(() => _transferName = null);
      _toast(AppStrings.of(context).browserUploadedTemplate.replaceAll('{name}', picked.name));
      await _list(_path);
    } on TransferCancelled {
      if (!mounted) return;
      setState(() => _transferName = null);
      _toast(AppStrings.of(context).browserUploadCancelled);
      await _list(_path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _transferName = null);
      _toast(AppStrings.of(context).browserUploadFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }

  Future<void> _delete(RemoteEntry entry) async {
    final fs = _fs;
    if (fs == null) return;
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
      await fs.delete(entry);
      if (!mounted) return;
      _toast(AppStrings.of(context).browserDeletedTemplate.replaceAll('{name}', entry.name));
      await _list(_path);
    } catch (e) {
      if (!mounted) return;
      _toast(AppStrings.of(context).browserDeleteFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }

  Future<void> _mkdir() async {
    final fs = _fs;
    if (fs == null) return;
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
      await fs.mkdir(target);
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

  String _fmtSize(int bytes) {
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
    final progress = _transferTotal <= 0
        ? null
        : (_transferDone / _transferTotal).clamp(0.0, 1.0);

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
            Text('$_kindLabel · ${widget.server.name}'),
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
            onPressed: _fs == null ? null : _mkdir,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          IconButton(
            tooltip: '上传',
            onPressed: _fs == null ? null : _upload,
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
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
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
                            onPressed: () =>
                                setState(() => _cancelRequested = true),
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
                        '${_fmtSize(_transferDone)} / ${_fmtSize(_transferTotal)}',
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
                                onPressed: _connect,
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
                                      : _fmtSize(entry.size),
                                  onTap: entry.isDirectory
                                      ? () => _list(entry.path)
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
}

import 'dart:io';

import 'image_preview_page.dart';
import 'package:path_provider/path_provider.dart';
import '../../design/glass_input_dialog.dart';
import '../../design/glass_dialog.dart';
import '../../design/glass_toast.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/download_helper.dart';
import '../../services/files/transfer_center.dart';
import '../../services/tools/sftp_service.dart';
import '../../widgets/transfer_panel.dart';

import 'file_icon.dart';
import 'file_actions.dart';
/// SFTP 浏览器：列目录、下载、上传、删除、新建目录。
class SftpBrowserPage extends StatefulWidget {
  const SftpBrowserPage({
    super.key,
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    this.keyPath,
    this.passphrase,
    this.proxyHost,
    this.proxyPort,
    this.proxyUser,
    this.proxyPwd,
  });

  final String host;
  final int port;
  final String user;
  final String password;

  // 跳板机
  final String? keyPath;
  final String? passphrase;

  final String? proxyHost;
  final int? proxyPort;
  final String? proxyUser;
  final String? proxyPwd;

  @override
  State<SftpBrowserPage> createState() => _SftpBrowserPageState();
}

class _SftpBrowserPageState extends State<SftpBrowserPage> {
  SftpService? _sftp;
  String _path = '/';
  List<SftpEntry> _entries = const <SftpEntry>[];
  bool _loading = true;
  String? _error;

  // 传输状态统一交给 TransferCenter，这里只留返回手势的时间戳
  DateTime? _lastBackAt;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _sftp?.close();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sftp = await SftpService.connect(
        host: widget.host,
        port: widget.port,
        user: widget.user,
        password: widget.password,
        keyPath: widget.keyPath,
        passphrase: widget.passphrase,
        proxyHost: widget.proxyHost,
        proxyPort: widget.proxyPort,
        proxyUser: widget.proxyUser,
        proxyPwd: widget.proxyPwd,
      );
      final home = await sftp.absolute('.');
      _sftp = sftp;
      await _list(home);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppStrings.of(context).browserConnectFailedTemplate.replaceAll('{msg}', '$e');
      });
    }
  }

  Future<void> _list(String path) async {
    final sftp = _sftp;
    if (sftp == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await sftp.list(path);
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

  String get _parentPath {
    if (_path == '/' || _path.isEmpty) return '/';
    final trimmed = _path.endsWith('/')
        ? _path.substring(0, _path.length - 1)
        : _path;
    final idx = trimmed.lastIndexOf('/');
    if (idx <= 0) return '/';
    return trimmed.substring(0, idx);
  }

  /// 单击 / 长按文件：弹出操作菜单（打开 / 下载 / 重命名 / 属性 / 删除）。
  Future<void> _showEntryActions(SftpEntry entry) async {
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

  /// 下载到缓存目录后用系统应用打开（视频走播放器、图片走看图等）。
  Future<void> _open(SftpEntry entry) async {
    final sftp = _sftp;
    if (sftp == null) return;
    final openTask = TransferCenter.instance.start(
      name: entry.name,
      upload: false,
      total: entry.size,
    );
    try {
      // 同目录图片一起带进图库
      final images = _entries
          .where((e) => !e.isDirectory && isPreviewableImage(e.name))
          .toList();
      var startIndex = images.indexWhere((e) => e.path == entry.path);
      if (startIndex < 0) {
        images.insert(0, entry);
        startIndex = 0;
      }
      final gallery = images
          .map(
            (e) => ImagePreviewItem(
              name: e.name,
              bytes: null,
              loader: () async {
                final tmp = File(
                  '${(await getTemporaryDirectory()).path}/${e.name}',
                );
                final sink = tmp.openWrite();
                try {
                  await sftp.downloadTo(
                    e.path,
                    (bytes, chunk) => sink.add(chunk),
                  );
                  await sink.flush();
                } finally {
                  await sink.close();
                }
                return tmp.readAsBytes();
              },
            ),
          )
          .toList();

      await downloadToCacheAndOpen(entry.name, (localPath) async {
        final sink = File(localPath).openWrite();
        try {
          await sftp.downloadTo(
            entry.path,
            (bytes, chunk) {
              if (openTask.cancelRequested) throw const _TransferCancelled();
              sink.add(chunk);
            },
            onProgress: (bytesRead) {
              TransferCenter.instance.update(openTask, done: bytesRead);
            },
          );
          await sink.flush();
        } finally {
          await sink.close();
        }
      }, context: context, gallery: gallery, galleryStart: startIndex);
      TransferCenter.instance.finish(openTask, TransferStatus.done);
    } on _TransferCancelled {
      TransferCenter.instance.finish(openTask, TransferStatus.cancelled);
    } catch (e) {
      TransferCenter.instance
          .finish(openTask, TransferStatus.failed, message: '$e');
      if (mounted) _toast(AppStrings.of(context).browserOpenFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }

  Future<void> _rename(SftpEntry entry) async {
    final sftp = _sftp;
    if (sftp == null) return;
    final newName = await askNewName(context, entry.name);
    if (newName == null || !mounted) return;
    try {
      final slash = entry.path.lastIndexOf('/');
      final dir = slash < 0 ? '' : entry.path.substring(0, slash + 1);
      await sftp.rename(entry.path, '$dir$newName');
      if (!mounted) return;
      _toast(AppStrings.of(context).browserRenamedTemplate.replaceAll('{name}', newName));
      await _list(_path);
    } catch (e) {
      if (mounted) _toast(AppStrings.of(context).browserRenameFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }

  Future<void> _properties(SftpEntry entry) {
    return showFileProperties(
      context,
      name: entry.name,
      path: entry.path,
      isDirectory: entry.isDirectory,
      sizeText: entry.isDirectory ? null : _fmtSize(entry.size),
      modifiedText: _modifiedText(entry.modified),
    );
  }
  Future<void> _download(SftpEntry entry) async {
    final sftp = _sftp;
    if (sftp == null) return;
    final name = entry.path.split('/').last;
    final task = TransferCenter.instance.start(
      name: name,
      upload: false,
      total: entry.size,
    );
    // 先写临时目录，完成后按设置决定落盘位置；
    // 临时名带上任务号，同名文件同时下载才不会互相覆盖
    final tempPath = await DownloadHelper.tempPath('${task.id}_$name');
    final target = File(tempPath);
    final sink = target.openWrite();
    try {
      var received = 0;
      await sftp.downloadTo(
        entry.path,
        (bytes, chunk) {
          if (task.cancelRequested) throw const _TransferCancelled();
          sink.add(chunk);
          received = bytes;
        },
        onProgress: (bytesRead) {
          TransferCenter.instance.update(task, done: bytesRead);
        },
      );
      await sink.flush();
      await sink.close();
      final finalPath = await DownloadHelper.finalize(tempPath, name);
      TransferCenter.instance
          .finish(task, TransferStatus.done, message: finalPath);
      if (!mounted) return;
      _toast('已下载 $name（${_fmtSize(received)}）\n$finalPath');
    } on _TransferCancelled {
      await sink.close();
      TransferCenter.instance.finish(task, TransferStatus.cancelled);
      if (!mounted) return;
      _toast('已取消下载 $name');
    } catch (e) {
      await sink.close();
      TransferCenter.instance
          .finish(task, TransferStatus.failed, message: '$e');
      if (!mounted) return;
      _toast(AppStrings.of(context).browserDownloadFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }

  Future<void> _upload() async {
    final sftp = _sftp;
    if (sftp == null) return;
    TransferTask? task;
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null) return;
      final localPath = picked.path;
      if (localPath == null) {
        if (mounted) _toast('无法读取所选文件');
        return;
      }
      final target = _path.endsWith('/')
          ? '$_path${picked.name}'
          : '$_path/${picked.name}';
      final localSize = await File(localPath).length();
      if (!mounted) return;
      final started = TransferCenter.instance.start(
        name: picked.name,
        upload: true,
        total: localSize,
      );
      task = started;
      // 流式上传：边读文件边写远端，大文件不会整份进内存
      await sftp.writeFile(
        target,
        localPath,
        onProgress: (sent, total) {
          TransferCenter.instance.update(started, done: sent, total: total);
        },
        isCancelled: () => started.cancelRequested,
      );
      TransferCenter.instance
          .finish(started, TransferStatus.done, message: target);
      if (!mounted) return;
      _toast('已上传 ${picked.name}（${_fmtSize(localSize)}）');
      await _list(_path);
    } on SftpUploadCancelled {
      if (task != null) {
        TransferCenter.instance.finish(task, TransferStatus.cancelled);
      }
      if (!mounted) return;
      _toast(AppStrings.of(context).browserUploadCancelled);
      await _list(_path);
    } catch (e) {
      if (task != null) {
        TransferCenter.instance
            .finish(task, TransferStatus.failed, message: '$e');
      }
      if (!mounted) return;
      _toast(AppStrings.of(context).browserUploadFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }

  Future<void> _delete(SftpEntry entry) async {
    final sftp = _sftp;
    if (sftp == null) return;
    final ok = await showGlassConfirm(
      context,
      title: AppStrings.of(context).commonDelete,
      message: AppStrings.of(context)
          .browserDeleteConfirmTemplate
          .replaceAll('{name}', entry.name),
      confirmText: AppStrings.of(context).browserDelete,
      cancelText: AppStrings.of(context).browserCancel,
      danger: true,
    );
    if (ok != true) return;
    try {
      await sftp.remove(entry.path);
      if (!mounted) return;
      _toast(AppStrings.of(context).browserDeletedTemplate.replaceAll('{name}', entry.name));
      await _list(_path);
    } catch (e) {
      if (!mounted) return;
      _toast(AppStrings.of(context).browserDeleteFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }

  Future<void> _mkdir() async {
    final sftp = _sftp;
    if (sftp == null) return;
    final name = await showGlassInput(
      context,
      title: AppStrings.of(context).browserNewFolder,
      hint: AppStrings.of(context).browserFolderName,
      confirmText: AppStrings.of(context).browserCreate,
      cancelText: AppStrings.of(context).browserCancel,
    );
    if (name == null || name.isEmpty) return;
    try {
      final target = _path.endsWith('/') ? '$_path$name' : '$_path/$name';
      await sftp.mkdir(target);
      if (!mounted) return;
      await _list(_path);
    } catch (e) {
      if (!mounted) return;
      _toast(AppStrings.of(context).browserCreateFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }

  void _toast(String message) {
    showGlassToast(context, message);
  }

  String _modifiedText(DateTime? time) {
    if (time == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
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
            Text('SFTP · ${widget.user}@${widget.host}'),
            Text(
              _path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).browserNewFolder,
            onPressed: _sftp == null ? null : _mkdir,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          IconButton(
            tooltip: '上传',
            onPressed: _sftp == null ? null : _upload,
            icon: const Icon(Icons.upload_file_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // 传输进度固定在顶部，支持同时多个任务
          const TransferPanel(),
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
                                style: text.bodyMedium?.copyWith(
                                    color: tokens.textSecondary),
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
                          final hasParent = _path != '/';
                          final itemCount = (hasParent ? 1 : 0) +
                              _entries.length +
                              (_entries.isEmpty ? 1 : 0);
                          return ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(12, 8, 12, 24),
                            itemCount: itemCount,
                            itemBuilder: (context, index) {
                              if (hasParent && index == 0) {
                                return ParentDirectoryTile(
                                  label: '返回上级',
                                  onTap: () => _list(_parentPath),
                                );
                              }
                              final i = hasParent ? index - 1 : index;
                              if (i < _entries.length) {
                                final entry = _entries[i];
                                final modified = _modifiedText(entry.modified);
                                return RemoteEntryTile(
                                  name: entry.name,
                                  isDirectory: entry.isDirectory,
                                  iconColor: entry.isDirectory
                                      ? tokens.accent
                                      : tokens.textSecondary,
                                  textColor: tokens.textPrimary,
                                  subtitle: entry.isDirectory
                                      ? modified
                                      : [
                                          _fmtSize(entry.size),
                                          if (modified.isNotEmpty) modified,
                                        ].join(' · '),
                                  onTap: entry.isDirectory
                                      ? () => _list(entry.path)
                                      : () => _showEntryActions(entry),
                                  onLongPress: () => _showEntryActions(entry),
                                );
                              }
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 40),
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
    showGlassToast(context, '再按一次返回退出');
  }
}

/// 传输被用户取消（用于从进度回调里中断下载/上传循环）。
class _TransferCancelled implements Exception {
  const _TransferCancelled();
}

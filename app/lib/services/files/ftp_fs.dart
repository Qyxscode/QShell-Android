import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';
import 'package:path_provider/path_provider.dart';

import 'remote_fs.dart';

/// FTP 的文件系统适配（基于 ftpconnect）。
class FtpFs implements RemoteFs {
  FtpFs(this._ftp);

  final FTPConnect _ftp;

  static Future<FtpFs> connect(RemoteServer server) async {
    final ftp = FTPConnect(
      server.host,
      port: server.port == 0 ? 21 : server.port,
      user: server.user,
      pass: server.pass,
      timeout: 20,
    );
    final ok = await ftp.connect();
    if (!ok) throw Exception('FTP 连接失败');
    return FtpFs(ftp);
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final target = path.isEmpty ? '/' : path;
    final changed = await _ftp.changeDirectory(target);
    if (!changed) throw Exception('无法进入目录 $target');
    final items = await _ftp.listDirectoryContent();
    return items
        .where((item) => item.name != '.' && item.name != '..')
        .map((item) => RemoteEntry(
              name: item.name,
              path: path.isEmpty ? item.name : '$path/${item.name}',
              isDirectory: item.type == FTPEntryType.dir,
              size: item.size ?? 0,
            ))
        .toList();
  }

  @override
  Future<void> download(
    String path,
    String localPath, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final file = File(localPath);
    final ok = await _ftp.downloadFile(
      path,
      file,
      onProgress: (progress, received, size) {
        if (isCancelled?.call() == true) throw const TransferCancelled();
        onProgress?.call(received, size);
      },
    );
    if (!ok) throw Exception('下载失败：$path');
  }

  @override
  Future<void> upload(
    String path,
    List<int> bytes, {
    void Function(int sent, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() == true) throw const TransferCancelled();
    // FTP 上传要求本地文件，先落到临时目录
    final dir = await getTemporaryDirectory();
    final name = path.split('/').last;
    final temp = File('${dir.path}/_ftp_upload_$name');
    await temp.writeAsBytes(bytes);
    try {
      final ok = await _ftp.uploadFile(
        temp,
        sRemoteName: path,
        onProgress: (progress, received, size) {
          if (isCancelled?.call() == true) throw const TransferCancelled();
          onProgress?.call(received, size);
        },
      );
      if (!ok) throw Exception('上传失败：$path');
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> delete(RemoteEntry entry) async {
    final ok = entry.isDirectory
        ? await _ftp.deleteDirectory(entry.path)
        : await _ftp.deleteFile(entry.path);
    if (!ok) throw Exception('删除失败：${entry.name}');
  }

  @override
  Future<void> rename(RemoteEntry entry, String newName) async {
    final slash = entry.path.lastIndexOf('/');
    final dir = slash < 0 ? '' : entry.path.substring(0, slash + 1);
    final ok = await _ftp.rename(entry.path, '$dir$newName');
    if (!ok) throw Exception('重命名失败：${entry.name}');
  }

  @override
  Future<void> mkdir(String path) async {
    final ok = await _ftp.makeDirectory(path);
    if (!ok) throw Exception('新建目录失败：$path');
  }

  @override
  Future<void> dispose() async {
    try {
      await _ftp.disconnect();
    } catch (_) {}
  }
}

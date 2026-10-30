import 'dart:io';
import 'dart:typed_data';

import 'package:dart_smb2/dart_smb2.dart';

import 'remote_fs.dart';

/// SMB/CIFS 的文件系统适配（基于 dart_smb2 / libsmb2）。
class SmbFs implements RemoteFs {
  SmbFs(this._pool);

  final Smb2Pool _pool;

  static Future<SmbFs> connect(RemoteServer server) async {
    if (server.share.isEmpty) {
      throw Exception('SMB 需要填共享名（share）');
    }
    final pool = await Smb2Pool.connect(
      host: server.host,
      share: server.share,
      user: server.user.isEmpty ? null : server.user,
      password: server.pass.isEmpty ? null : server.pass,
    );
    return SmbFs(pool);
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final items = await _pool.listDirectory(path);
    return items
        .where((item) => item.name != '.' && item.name != '..')
        .map((item) => RemoteEntry(
              name: item.name,
              path: path.isEmpty ? item.name : '$path/${item.name}',
              isDirectory: item.isDirectory,
              size: item.size,
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
    final sink = file.openWrite();
    try {
      final total = await _pool.fileSize(path);
      final stream = _pool.streamFile(
        path,
        onProgress: (received, size) {
          onProgress?.call(received, size > 0 ? size : total);
        },
      );
      await for (final chunk in stream) {
        if (isCancelled?.call() == true) throw const TransferCancelled();
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  @override
  Future<void> upload(
    String path,
    List<int> bytes, {
    void Function(int sent, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() == true) throw const TransferCancelled();
    await _pool.writeFile(path, Uint8List.fromList(bytes));
    onProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<void> delete(RemoteEntry entry) async {
    if (entry.isDirectory) {
      await _pool.rmdir(entry.path);
    } else {
      await _pool.deleteFile(entry.path);
    }
  }

  @override
  Future<void> rename(RemoteEntry entry, String newName) async {
    final slash = entry.path.lastIndexOf('/');
    final dir = slash < 0 ? '' : entry.path.substring(0, slash + 1);
    await _pool.rename(entry.path, '$dir$newName');
  }

  @override
  Future<void> mkdir(String path) => _pool.mkdir(path);

  @override
  Future<void> dispose() async {
    try {
      await _pool.disconnect();
    } catch (_) {}
  }
}

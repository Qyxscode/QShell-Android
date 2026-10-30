import 'dart:io';

import '../tools/webdav_client.dart';
import 'remote_fs.dart';

/// WebDAV 的文件系统适配。
class WebdavFs implements RemoteFs {
  WebdavFs(this._client);

  final WebdavClient _client;

  static Future<WebdavFs> connect(RemoteServer server) async {
    return WebdavFs(
      WebdavClient(
        baseUrl: server.host,
        username: server.user,
        password: server.pass,
      ),
    );
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final entries = await _client.list(path);
    return entries
        .map((entry) => RemoteEntry(
              name: entry.name,
              path: entry.href,
              isDirectory: entry.isDirectory,
              size: entry.size,
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
      final bytes = await _client.download(
        path,
        onProgress: (received, total) {
          if (isCancelled?.call() == true) throw const TransferCancelled();
          onProgress?.call(received, total);
        },
      );
      sink.add(bytes);
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
    await _client.upload(path, bytes);
    onProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<void> delete(RemoteEntry entry) => _client.delete(entry.path);

  @override
  Future<void> rename(RemoteEntry entry, String newName) {
    final slash = entry.path.lastIndexOf('/');
    final dir = slash < 0 ? '' : entry.path.substring(0, slash + 1);
    return _client.rename(entry.path, '$dir$newName');
  }

  @override
  Future<void> mkdir(String path) => _client.mkdir(path);

  @override
  Future<void> dispose() async {}
}

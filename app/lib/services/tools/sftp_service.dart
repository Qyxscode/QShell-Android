import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../ssh_connector.dart';

/// SFTP 目录项。
class SftpEntry {
  const SftpEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    this.modified,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
}

/// SFTP 会话（复用 dartssh2，和终端同一套 SSH 客户端）。
class SftpService {
  SftpService._(this._connection, this._sftp);

  final SshConnection _connection;
  final SftpClient _sftp;

  static Future<SftpService> connect({
    required String host,
    required int port,
    required String user,
    required String password,
    String? keyPath,
    String? passphrase,
    String? proxyHost,
    int? proxyPort,
    String? proxyUser,
    String? proxyPwd,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final connection = await SshConnector.connect(
      host: host,
      port: port,
      user: user,
      password: password,
      keyPath: keyPath,
      passphrase: passphrase,
      proxyHost: proxyHost,
      proxyPort: proxyPort,
      proxyUser: proxyUser,
      proxyPwd: proxyPwd,
      timeout: timeout,
    );
    final sftp = await connection.client.sftp();
    return SftpService._(connection, sftp);
  }

  /// 解析软链接后的绝对路径。
  Future<String> absolute(String path) => _sftp.absolute(path);

  Future<List<SftpEntry>> list(String path) async {
    final names = await _sftp.listdir(path);
    final entries = <SftpEntry>[];
    for (final item in names) {
      if (item.filename == '.' || item.filename == '..') continue;
      final mode = item.attr.mode?.value ?? 0;
      final isDir = (mode & 0xF000) == 0x4000;
      entries.add(
        SftpEntry(
          name: item.filename,
          path: path.endsWith('/') ? '$path${item.filename}' : '$path/${item.filename}',
          isDirectory: isDir,
          size: item.attr.size ?? 0,
          modified: item.attr.modifyTime == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  (item.attr.modifyTime ?? 0) * 1000),
        ),
      );
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  Future<void> remove(String path) => _sftp.remove(path);

  Future<void> mkdir(String path) => _sftp.mkdir(path);

  Future<void> rename(String oldPath, String newPath) =>
      _sftp.rename(oldPath, newPath);

  /// 下载到内存（小文件用；大文件请用 [downloadTo]）。
  Future<Uint8List> readAll(String path) async {
    final file = await _sftp.open(path, mode: SftpFileOpenMode.read);
    try {
      final chunks = <int>[];
      await for (final chunk in file.read()) {
        chunks.addAll(chunk);
      }
      return Uint8List.fromList(chunks);
    } finally {
      await file.close();
    }
  }

  /// 流式下载，边下边回调进度。
  Future<int> downloadTo(
    String path,
    void Function(int bytes, List<int> chunk) onChunk, {
    void Function(int bytesRead)? onProgress,
  }) async {
    var total = 0;
    final sink = _CallbackSink((chunk) {
      total += chunk.length;
      onChunk(total, chunk);
    });
    final written = await _sftp.download(
      path,
      sink,
      onProgress: onProgress,
    );
    await sink.close();
    return written;
  }

  Future<void> writeAll(
    String path,
    Uint8List bytes, {
    void Function(int sent)? onProgress,
  }) async {
    final file = await _sftp.open(
      path,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    try {
      const chunkSize = 512 * 1024;
      var offset = 0;
      while (offset < bytes.length) {
        final end = (offset + chunkSize) > bytes.length
            ? bytes.length
            : offset + chunkSize;
        await file.writeBytes(bytes.sublist(offset, end), offset: offset);
        offset = end;
        onProgress?.call(offset);
      }
      onProgress?.call(bytes.length);
    } finally {
      await file.close();
    }
  }

  Future<void> close() async {
    try {
      await _sftp.close();
    } catch (_) {}
    _connection.close();
  }
}

/// 把回调包装成 StreamSink。
class _CallbackSink implements StreamSink<List<int>> {
  _CallbackSink(this._onData);

  final void Function(List<int> chunk) _onData;
  final StreamController<void> _controller = StreamController<void>();

  @override
  void add(List<int> data) => _onData(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> close() => _controller.close();

  @override
  Future<void> get done => _controller.done;
}

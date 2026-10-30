import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 远程目录项（统一 SFTP / FTP / WebDAV / SMB 的表示）。
class RemoteEntry {
  const RemoteEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
  });

  final String name;

  /// 相对根目录的路径（'' 表示根）
  final String path;
  final bool isDirectory;
  final int size;
}

/// 传输被用户取消。
class TransferCancelled implements Exception {
  const TransferCancelled();
}

/// 统一的远程文件系统接口。
abstract class RemoteFs {
  Future<List<RemoteEntry>> list(String path);

  /// 下载到本地文件；[isCancelled] 返回 true 时抛 [TransferCancelled]。
  Future<void> download(
    String path,
    String localPath, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  });

  Future<void> upload(
    String path,
    List<int> bytes, {
    void Function(int sent, int total)? onProgress,
    bool Function()? isCancelled,
  });

  Future<void> delete(RemoteEntry entry);

  /// 重命名（[entry] 所在的同目录内改名）。
  Future<void> rename(RemoteEntry entry, String newName);

  Future<void> mkdir(String path);

  Future<void> dispose();
}

/// 保存的远程服务器配置（WebDAV / FTP / SMB）。
class RemoteServer {
  const RemoteServer({
    required this.kind,
    required this.name,
    required this.host,
    this.port = 0,
    this.share = '',
    this.user = '',
    this.pass = '',
  });

  /// webdav | ftp | smb
  final String kind;
  final String name;

  /// WebDAV 是完整 URL；FTP/SMB 是主机名
  final String host;
  final int port;

  /// SMB 专用
  final String share;
  final String user;
  final String pass;

  String get subtitle {
    switch (kind) {
      case 'webdav':
        return '$user@$host';
      case 'ftp':
        return '$user@$host:$port';
      case 'smb':
        return '\\\\$host\\$share';
      default:
        return host;
    }
  }

  RemoteServer copyWith({
    String? kind,
    String? name,
    String? host,
    int? port,
    String? share,
    String? user,
    String? pass,
  }) =>
      RemoteServer(
        kind: kind ?? this.kind,
        name: name ?? this.name,
        host: host ?? this.host,
        port: port ?? this.port,
        share: share ?? this.share,
        user: user ?? this.user,
        pass: pass ?? this.pass,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'name': name,
        'host': host,
        'port': port,
        'share': share,
        'user': user,
        'pass': pass,
      };

  factory RemoteServer.fromJson(Map<String, dynamic> json) => RemoteServer(
        kind: (json['kind'] as String?) ?? 'webdav',
        name: (json['name'] as String?) ?? '',
        host: (json['host'] as String?) ?? '',
        port: (json['port'] as num?)?.toInt() ?? 0,
        share: (json['share'] as String?) ?? '',
        user: (json['user'] as String?) ?? '',
        pass: (json['pass'] as String?) ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is RemoteServer &&
      other.kind == kind &&
      other.name == name &&
      other.host == host &&
      other.port == port &&
      other.share == share &&
      other.user == user &&
      other.pass == pass;

  @override
  int get hashCode =>
      Object.hash(kind, name, host, port, share, user, pass);
}

/// 远程服务器配置的本地存储（同一个 kind 可以有多条）。
class RemoteStore {
  static const _key = 'remote.servers';

  Future<List<RemoteServer>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const <RemoteServer>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((item) => RemoteServer.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const <RemoteServer>[];
    }
  }

  Future<List<RemoteServer>> save(List<RemoteServer> servers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(servers.map((server) => server.toJson()).toList()),
    );
    return servers;
  }

  Future<List<RemoteServer>> add(RemoteServer server) async {
    final servers = await load();
    return save(<RemoteServer>[...servers, server]);
  }

  Future<List<RemoteServer>> update(
    RemoteServer oldServer,
    RemoteServer newServer,
  ) async {
    final servers = await load();
    final index = servers.indexOf(oldServer);
    if (index < 0) return servers;
    final copy = <RemoteServer>[...servers];
    copy[index] = newServer;
    return save(copy);
  }

  Future<List<RemoteServer>> remove(RemoteServer server) async {
    final servers = await load();
    return save(
      servers.where((item) => item != server).toList(),
    );
  }
}

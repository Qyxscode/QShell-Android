import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

/// 一条 SSH 连接（可能带跳板机）。
class SshConnection {
  SshConnection(this.client, {this.jumpClient});

  final SSHClient client;

  /// 跳板机的 SSH 连接，关闭时一起关掉
  final SSHClient? jumpClient;

  void close() {
    client.close();
    jumpClient?.close();
  }
}

/// 建立 SSH 连接，支持跳板机（ProxyJump）和私钥登录。
///
/// 跳板实现：先连跳板机，用 direct-tcpip 通道转发到目标机的端口，
/// 再在这条通道上建立第二层 SSH（等价于 ssh -J）。
class SshConnector {
  SshConnector._();

  /// 从本地私钥文件构造认证方式；文件不存在或解析失败返回 null。
  static Future<List<SSHKeyPair>?> _loadKey(String? path, String? passphrase) async {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final pem = await file.readAsString();
      return SSHKeyPair.fromPem(pem, passphrase ?? '');
    } catch (_) {
      return null;
    }
  }

  static Future<SshConnection> connect({
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
    String? proxyKeyPath,
    String? proxyKeyPassphrase,
    Duration timeout = const Duration(seconds: 15),
    SSHPrintHandler? printDebug,
  }) async {
    final identity = await _loadKey(keyPath, passphrase);
    final proxyIdentity =
        await _loadKey(proxyKeyPath, proxyKeyPassphrase);

    SSHClient? jumpClient;
    SSHSocket socket;

    if ((proxyHost ?? '').isNotEmpty) {
      final jumpSocket = await SSHSocket.connect(
        proxyHost!,
        proxyPort ?? 22,
        timeout: timeout,
      );
      jumpClient = SSHClient(
        jumpSocket,
        username: (proxyUser ?? '').isEmpty ? user : proxyUser!,
        identities: proxyIdentity,
        onPasswordRequest: () async =>
            (proxyPwd ?? '').isEmpty ? password : proxyPwd!,
        printDebug: printDebug,
      );
      await jumpClient.authenticated;
      socket = await jumpClient.forwardLocal(host, port);
    } else {
      socket = await SSHSocket.connect(host, port, timeout: timeout);
    }

    final client = SSHClient(
      socket,
      username: user,
      identities: identity,
      onPasswordRequest: () async => password,
      printDebug: printDebug,
    );
    try {
      await client.authenticated;
    } catch (e) {
      client.close();
      jumpClient?.close();
      rethrow;
    }
    return SshConnection(client, jumpClient: jumpClient);
  }
}

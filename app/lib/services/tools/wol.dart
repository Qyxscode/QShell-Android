import 'dart:io';
import 'dart:typed_data';

/// Wake On LAN：构造并发送魔术包。
///
/// 魔术包 = 6 字节 0xFF + 目标 MAC 重复 16 次，共 102 字节，UDP 广播发出。
class WolService {
  /// 解析 MAC，支持 `AA:BB:CC:DD:EE:FF` / `AA-BB-...` / `AABBCCDDEEFF`。
  static Uint8List? parseMac(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .replaceAll('.', '');
    if (cleaned.length != 12) return null;
    final bytes = <int>[];
    for (var i = 0; i < 12; i += 2) {
      final value = int.tryParse(cleaned.substring(i, i + 2), radix: 16);
      if (value == null) return null;
      bytes.add(value);
    }
    return Uint8List.fromList(bytes);
  }

  static String formatMac(Uint8List mac) => mac
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');

  static Uint8List buildPacket(Uint8List mac) {
    final packet = Uint8List(6 + 16 * 6);
    for (var i = 0; i < 6; i++) {
      packet[i] = 0xFF;
    }
    for (var i = 0; i < 16; i++) {
      for (var j = 0; j < 6; j++) {
        packet[6 + i * 6 + j] = mac[j];
      }
    }
    return packet;
  }

  /// 发送魔术包；[broadcast] 常见是 255.255.255.255 或子网广播（如 192.168.1.255）。
  static Future<void> send({
    required String mac,
    String broadcast = '255.255.255.255',
    int port = 9,
  }) async {
    final macBytes = parseMac(mac);
    if (macBytes == null) {
      throw const FormatException('MAC 格式不对，示例 AA:BB:CC:DD:EE:FF');
    }
    final address = InternetAddress.tryParse(broadcast.trim());
    if (address == null) {
      throw const FormatException('广播地址格式不对，示例 192.168.1.255');
    }
    final packet = buildPacket(macBytes);
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      socket.send(packet, address, port);
      // 多播几次，UDP 不可靠
      for (var i = 0; i < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        socket.send(packet, address, port);
      }
    } finally {
      socket.close();
    }
  }
}

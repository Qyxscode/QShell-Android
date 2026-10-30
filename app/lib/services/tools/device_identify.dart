import 'dart:io';

/// 局域网设备类型识别结果。
class DeviceIdentity {
  const DeviceIdentity({
    required this.kind,
    required this.openPorts,
  });

  /// 推断的类型（路由器 / Windows / iPhone …）
  final String kind;

  /// 探测到的开放端口（特征端口）
  final List<int> openPorts;

  String get portsLabel => openPorts.isEmpty ? '' : openPorts.join(', ');
}

/// 按特征端口 + 主机名推断设备类型。
///
/// Android 读不到其他设备的 MAC，所以没法用 OUI 厂商库；
/// 这里用端口指纹做近似判断（PingTools 之类也是类似做法）。
class DeviceIdentifier {
  DeviceIdentifier._();

  /// 探测的特征端口
  static const List<int> probePorts = <int>[
    22, // SSH
    80, // HTTP
    443, // HTTPS
    445, // SMB
    139, // NetBIOS
    3389, // RDP
    62078, // iPhone 锁屏端口
    9100, // 打印
    515, // LPD 打印
    631, // IPP 打印
    53, // DNS
    5000, // Synology DSM
    5001, // Synology DSM (https)
    554, // RTSP 摄像头
    8080, // HTTP 备选
  ];

  static Future<bool> _probe(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 350),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<DeviceIdentity> identify(
    String ip, {
    String? hostname,
  }) async {
    final open = <int>[];
    await Future.wait(probePorts.map((port) async {
      if (await _probe(ip, port)) open.add(port);
    }));
    open.sort();
    return DeviceIdentity(
      kind: _infer(hostname ?? '', open),
      openPorts: open,
    );
  }

  static String _infer(String hostname, List<int> open) {
    bool has(int port) => open.contains(port);
    final name = hostname.toLowerCase();

    if (has(62078) || name.contains('iphone') || name.contains('ipad')) {
      return 'iphone';
    }
    if (has(3389)) return 'windows_rdp';
    if (has(445) || has(139)) return 'windows';
    if (has(9100) || has(515) || has(631)) return 'printer';
    if (has(5000) || has(5001)) return 'nas';
    if (name.contains('nas') ||
        name.contains('synology') ||
        name.contains('qnap') ||
        name.contains('freenas') ||
        name.contains('truenas')) {
      return 'nas';
    }
    if (has(554)) return 'camera';
    if (name.contains('router') ||
        name.contains('gateway') ||
        name.contains('openwrt') ||
        name.contains('miwifi') ||
        name.contains('tplink') ||
        name.contains('asus')) {
      return 'router';
    }
    if (has(53) && (has(80) || has(443))) return 'router';
    if (name.contains('android') || name.contains('phone')) return 'android';
    if (name.contains('printer') || name.contains('hp-')) return 'printer';
    if (has(22)) return 'linux';
    if (has(80) || has(443) || has(8080)) return 'web';
    return 'unknown';
  }
}

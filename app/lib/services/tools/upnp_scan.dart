import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 一个 SSDP 响应。
class SsdpDevice {
  const SsdpDevice({
    required this.ip,
    required this.st,
    required this.usn,
    required this.location,
    required this.server,
  });

  final String ip;
  final String st;
  final String usn;
  final String location;
  final String server;

  /// 从 LOCATION 里猜设备类型（够用就行）
  String get kind {
    final stLower = st.toLowerCase();
    if (stLower.contains('internetgatewaydevice')) return '网关';
    if (stLower.contains('wanipconnection')) return 'WAN 连接';
    if (stLower.contains('wanpppconnection')) return 'WAN PPP';
    if (stLower.contains('mediaserver')) return '媒体服务器';
    if (stLower.contains('mediarenderer')) return '媒体渲染器';
    if (stLower == 'upnp:rootdevice') return '根设备';
    if (stLower.contains('printer')) return '打印机';
    return st;
  }
}

/// SSDP 发现（UPnP）。
///
/// 向 239.255.255.250:1900 发 M-SEARCH 多播，收集响应。
/// 纯 Dart，不需要权限；同一 Wi-Fi 下一般能发现路由器和 NAS。
Stream<SsdpDevice> ssdpDiscover({
  Duration timeout = const Duration(seconds: 4),
}) {
  final controller = StreamController<SsdpDevice>();
  RawDatagramSocket? socket;
  var closed = false;

  Future<void> run() async {
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket!.broadcastEnabled = true;
      socket!.multicastHops = 4;
      // 加入 SSDP 多播组（部分网络需要）
      try {
        socket!.joinMulticast(InternetAddress('239.255.255.250'));
      } catch (_) {
        // 某些 ROM 不允许，忽略
      }

      final request = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 3\r\n'
          'ST: ssdp:all\r\n'
          '\r\n';
      final payload = utf8.encode(request);
      for (var i = 0; i < 3; i++) {
        socket!.send(payload, InternetAddress('239.255.255.250'), 1900);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      final seen = <String>{};
      final timer = Timer(timeout, () {
        closed = true;
        socket?.close();
      });

      socket!.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          final datagram = socket!.receive();
          if (datagram == null) return;
          final text = utf8.decode(datagram.data, allowMalformed: true);
          final headers = _parseHeaders(text);
          final location = headers['location'] ?? '';
          final st = headers['st'] ?? '';
          final usn = headers['usn'] ?? '';
          final server = headers['server'] ?? '';
          final ip = datagram.address.address;
          final key = '$ip|$st|$location';
          if (seen.add(key)) {
            controller.add(
              SsdpDevice(
                ip: ip,
                st: st,
                usn: usn,
                location: location,
                server: server,
              ),
            );
          }
        },
        onDone: () {
          timer.cancel();
        },
        onError: (Object _) {},
      );

      await Future<void>.delayed(timeout + const Duration(milliseconds: 400));
      timer.cancel();
      if (!closed) {
        closed = true;
        socket?.close();
      }
    } catch (e) {
      controller.addError(e);
    } finally {
      if (!controller.isClosed) await controller.close();
    }
  }

  run();
  return controller.stream;
}

Map<String, String> _parseHeaders(String raw) {
  final map = <String, String>{};
  final lines = const LineSplitter().convert(raw);
  for (final line in lines) {
    final idx = line.indexOf(':');
    if (idx <= 0) continue;
    final key = line.substring(0, idx).trim().toLowerCase();
    final value = line.substring(idx + 1).trim();
    if (key.isNotEmpty) map[key] = value;
  }
  return map;
}

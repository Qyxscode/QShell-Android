import 'dart:async';
import 'dart:io';

/// 端口探测结果。
enum PortState { open, closed, filtered }

class PortScanEvent {
  const PortScanEvent({
    required this.scanned,
    required this.total,
    this.port,
    this.state,
  });

  final int scanned;
  final int total;
  final int? port;
  final PortState? state;

  bool get isResult => port != null && state != null;
}

/// 常用端口（够覆盖运维常见服务）。
const Map<int, String> commonPorts = <int, String>{
  21: 'FTP',
  22: 'SSH',
  23: 'Telnet',
  25: 'SMTP',
  53: 'DNS',
  80: 'HTTP',
  110: 'POP3',
  143: 'IMAP',
  443: 'HTTPS',
  445: 'SMB',
  1433: 'MSSQL',
  1521: 'Oracle',
  3306: 'MySQL',
  3389: 'RDP',
  5432: 'PostgreSQL',
  5900: 'VNC',
  6379: 'Redis',
  8080: 'HTTP-Alt',
  8443: 'HTTPS-Alt',
  27017: 'MongoDB',
};

/// 端口扫描：TCP connect。
///
/// - 连上 = open
/// - 被拒绝（RST）= closed
/// - 超时 = filtered
///
/// 流式返回，扫到一个报一个。
Stream<PortScanEvent> scanPorts(
  String host,
  List<int> ports, {
  Duration timeout = const Duration(milliseconds: 600),
  int concurrency = 32,
}) {
  final controller = StreamController<PortScanEvent>();
  var next = 0;
  var scanned = 0;

  Future<void> run() async {
    final workers = List.generate(
      concurrency > ports.length ? ports.length : concurrency,
      (_) async {
        while (true) {
          final index = next++;
          if (index >= ports.length) return;
          final port = ports[index];
          final state = await _probe(host, port, timeout);
          scanned++;
          controller.add(
            PortScanEvent(
              scanned: scanned,
              total: ports.length,
              port: port,
              state: state,
            ),
          );
        }
      },
    );
    try {
      await Future.wait(workers);
      await controller.close();
    } catch (e) {
      await controller.close();
    }
  }

  run();
  return controller.stream;
}

Future<PortState> _probe(String host, int port, Duration timeout) async {
  Socket? socket;
  try {
    socket = await Socket.connect(host, port, timeout: timeout);
    return PortState.open;
  } on SocketException catch (e) {
    final code = e.osError?.errorCode;
    final msg = e.message.toLowerCase();
    if (code == 111 || msg.contains('refused') || msg.contains('reset')) {
      return PortState.closed;
    }
    return PortState.filtered;
  } catch (_) {
    return PortState.filtered;
  } finally {
    socket?.destroy();
  }
}

/// 解析端口输入：`80,443,8000-8100`。
List<int> parsePorts(String raw) {
  final result = <int>{};
  for (final part in raw.split(',')) {
    final token = part.trim();
    if (token.isEmpty) continue;
    if (token.contains('-')) {
      final pair = token.split('-');
      if (pair.length != 2) continue;
      final start = int.tryParse(pair[0].trim());
      final end = int.tryParse(pair[1].trim());
      if (start == null || end == null) continue;
      final lo = start < end ? start : end;
      final hi = start < end ? end : start;
      for (var p = lo; p <= hi && p <= 65535; p++) {
        if (p >= 1) result.add(p);
      }
    } else {
      final p = int.tryParse(token);
      if (p != null && p >= 1 && p <= 65535) result.add(p);
    }
  }
  final list = result.toList()..sort();
  return list;
}

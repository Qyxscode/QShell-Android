import 'dart:async';
import 'dart:io';

/// 一次 TCP ping 的结果。
class PingResult {
  const PingResult({
    required this.seq,
    this.rtt,
    this.error,
  });

  final int seq;
  final Duration? rtt;
  final String? error;

  bool get success => rtt != null;
}

/// Ping 汇总。
class PingSummary {
  const PingSummary({
    required this.sent,
    required this.received,
    required this.min,
    required this.max,
    required this.avg,
  });

  final int sent;
  final int received;
  final Duration? min;
  final Duration? max;
  final Duration? avg;

  int get lossPercent =>
      sent == 0 ? 0 : ((sent - received) * 100 / sent).round();
}

/// TCP ping。
///
/// Android 普通 App 没有 raw socket，ICMP 走不通，所以这里用 TCP connect 计时：
/// 连上或被拒绝（RST）都算「有响应」，只有超时算丢包。
/// 这对连通性判断已经够用，也是绝大多数手机 ping 工具的做法。
Stream<PingResult> tcpPing(
  String host, {
  int port = 443,
  int count = 4,
  Duration timeout = const Duration(seconds: 2),
  Duration interval = const Duration(milliseconds: 500),
}) {
  final controller = StreamController<PingResult>();
  var cancelled = false;

  Future<void> run() async {
    for (var i = 1; i <= count; i++) {
      if (cancelled) break;
      final sw = Stopwatch()..start();
      PingResult result;
      Socket? socket;
      try {
        socket = await Socket.connect(host, port, timeout: timeout);
        sw.stop();
        result = PingResult(seq: i, rtt: sw.elapsed);
      } on SocketException catch (e) {
        sw.stop();
        final code = e.osError?.errorCode;
        final msg = e.message.toLowerCase();
        if (code == 111 || msg.contains('refused') || msg.contains('reset')) {
          // 被拒绝也说明主机在线，有 RTT 概念
          result = PingResult(seq: i, rtt: sw.elapsed);
        } else {
          result = PingResult(seq: i, error: _friendly(e));
        }
      } catch (e) {
        sw.stop();
        result = PingResult(seq: i, error: _friendly(e));
      } finally {
        socket?.destroy();
      }
      controller.add(result);
      if (i < count) await Future<void>.delayed(interval);
    }
    await controller.close();
  }

  run();
  controller.onCancel = () {
    cancelled = true;
  };
  return controller.stream;
}

String _friendly(Object e) {
  final text = e.toString().toLowerCase();
  if (text.contains('timed out') || text.contains('timeout')) return '超时';
  if (text.contains('unreachable')) return '网络不可达';
  if (text.contains('refused')) return '拒绝';
  return '失败';
}

PingSummary summarizePing(List<PingResult> results) {
  final ok = results.where((r) => r.success).toList();
  if (ok.isEmpty) {
    return PingSummary(
      sent: results.length,
      received: 0,
      min: null,
      max: null,
      avg: null,
    );
  }
  Duration min = ok.first.rtt!;
  Duration max = ok.first.rtt!;
  var sum = 0;
  for (final r in ok) {
    final ms = r.rtt!.inMicroseconds;
    if (ms < min.inMicroseconds) min = r.rtt!;
    if (ms > max.inMicroseconds) max = r.rtt!;
    sum += ms;
  }
  return PingSummary(
    sent: results.length,
    received: ok.length,
    min: min,
    max: max,
    avg: Duration(microseconds: sum ~/ ok.length),
  );
}

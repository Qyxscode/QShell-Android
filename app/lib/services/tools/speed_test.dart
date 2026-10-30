import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// 测速阶段。
enum SpeedPhase { idle, latency, download, upload, done, failed }

/// 测速事件。
class SpeedEvent {
  const SpeedEvent({
    required this.phase,
    this.progress = 0,
    this.instantMbps = 0,
    this.message,
    this.result,
  });

  final SpeedPhase phase;

  /// 0~1
  final double progress;
  final double instantMbps;
  final String? message;
  final SpeedResult? result;
}

/// 测速结果。
class SpeedResult {
  const SpeedResult({
    required this.downloadMbps,
    required this.uploadMbps,
    required this.latencyMs,
    required this.downloadBytes,
    required this.uploadBytes,
  });

  final double downloadMbps;
  final double uploadMbps;
  final int latencyMs;
  final int downloadBytes;
  final int uploadBytes;
}

/// 测速节点。
class SpeedNode {
  const SpeedNode({
    required this.id,
    required this.name,
    required this.downloadUrl,
    required this.uploadUrl,
  });

  final String id;
  final String name;

  /// 形如 https://.../__down?bytes=25000000
  final String downloadUrl;
  final String uploadUrl;
}

/// 内置节点。Cloudflare 的测速接口不用 key，全球任播；
/// 国内直连可能不稳，需要挂代理或换自定义节点。
const List<SpeedNode> builtinSpeedNodes = <SpeedNode>[
  SpeedNode(
    id: 'cloudflare',
    name: 'Cloudflare',
    downloadUrl: 'https://speed.cloudflare.com/__down?bytes=25000000',
    uploadUrl: 'https://speed.cloudflare.com/__up',
  ),
];

const int _downloadBytes = 25000000; // 25 MB
const int _uploadBytes = 8000000; // 8 MB

/// 从用户填的下载 URL 推断要下多少字节。
///
/// 支持两种：
/// - 带 `bytes=` 参数（Cloudflare 风格）
/// - 普通静态文件（不知道大小，按 25MB 封顶）
int _downloadLimit(String url) {
  final match = RegExp(r'[?&]bytes=(\d+)').firstMatch(url);
  if (match != null) {
    final value = int.tryParse(match.group(1) ?? '');
    if (value != null && value > 0) return value;
  }
  return _downloadBytes;
}

/// 跑一次测速：延迟 → 下载 → 上传。
///
/// 纯 HTTP，不依赖原生；失败会通过 [SpeedEvent.message] 说明原因。
Stream<SpeedEvent> runSpeedTest(SpeedNode node) {
  final controller = StreamController<SpeedEvent>();
  final client = http.Client();
  var cancelled = false;

  Future<void> run() async {
    try {
      final downloadLimit = _downloadLimit(node.downloadUrl);

      // 1) 延迟：连发 3 次小请求取平均
      controller.add(const SpeedEvent(phase: SpeedPhase.latency, message: '测延迟…'));
      final latencies = <int>[];
      final latencyUrl = _latencyUrl(node.downloadUrl);
      for (var i = 0; i < 3; i++) {
        if (cancelled) break;
        final sw = Stopwatch()..start();
        final resp = await client
            .get(Uri.parse(latencyUrl))
            .timeout(const Duration(seconds: 8));
        sw.stop();
        if (resp.statusCode >= 400) {
          throw Exception('延迟测试返回 ${resp.statusCode}');
        }
        latencies.add(sw.elapsedMilliseconds);
      }
      final latency = latencies.isEmpty
          ? 0
          : (latencies.reduce((a, b) => a + b) / latencies.length).round();

      // 2) 下载
      controller.add(const SpeedEvent(
        phase: SpeedPhase.download,
        message: '下载测速中…',
      ));
      final downloadSw = Stopwatch()..start();
      final request = http.Request('GET', Uri.parse(node.downloadUrl));
      final streamed =
          await client.send(request).timeout(const Duration(seconds: 20));
      if (streamed.statusCode >= 400) {
        throw Exception('下载返回 ${streamed.statusCode}');
      }
      var received = 0;
      var lastTick = 0;
      await for (final chunk in streamed.stream) {
        if (cancelled) break;
        received += chunk.length;
        final elapsedMs = downloadSw.elapsedMilliseconds;
        if (elapsedMs - lastTick >= 150) {
          lastTick = elapsedMs;
          final mbps = _mbps(received, elapsedMs);
          controller.add(SpeedEvent(
            phase: SpeedPhase.download,
            progress: (received / downloadLimit).clamp(0.0, 1.0),
            instantMbps: mbps,
            message: '下载 ${mbps.toStringAsFixed(2)} Mbps',
          ));
        }
        if (received >= downloadLimit) break;
      }
      downloadSw.stop();
      final downloadMbps = _mbps(received, downloadSw.elapsedMilliseconds);

      // 3) 上传（没配上传地址就跳过）
      var uploadMbps = 0.0;
      var uploaded = 0;
      if (node.uploadUrl.isNotEmpty) {
        controller.add(const SpeedEvent(
          phase: SpeedPhase.upload,
          message: '上传测速中…',
        ));
        final payload = Uint8List.fromList(
          List<int>.generate(_uploadBytes, (_) => Random().nextInt(256)),
        );
        final uploadSw = Stopwatch()..start();
        final uploadRequest = http.Request('POST', Uri.parse(node.uploadUrl))
          ..bodyBytes = payload
          ..headers['Content-Type'] = 'application/octet-stream';
        final uploadResp = await client
            .send(uploadRequest)
            .timeout(const Duration(seconds: 40));
        await uploadResp.stream.drain<void>();
        uploadSw.stop();
        uploaded = _uploadBytes;
        uploadMbps = _mbps(uploaded, uploadSw.elapsedMilliseconds);
      }

      final result = SpeedResult(
        downloadMbps: downloadMbps,
        uploadMbps: uploadMbps,
        latencyMs: latency,
        downloadBytes: received,
        uploadBytes: uploaded,
      );
      controller.add(SpeedEvent(phase: SpeedPhase.done, result: result));
    } catch (e) {
      controller.add(SpeedEvent(
        phase: SpeedPhase.failed,
        message: _friendly(e),
      ));
    } finally {
      client.close();
      await controller.close();
    }
  }

  run();
  controller.onCancel = () {
    cancelled = true;
  };
  return controller.stream;
}

/// 延迟探测用的 URL：Cloudflare 风格就加 bytes=0，静态文件直接用原地址。
String _latencyUrl(String downloadUrl) {
  if (downloadUrl.contains('__down')) return 'https://speed.cloudflare.com/__down?bytes=0';
  return downloadUrl;
}

double _mbps(int bytes, int elapsedMs) {
  if (elapsedMs <= 0 || bytes <= 0) return 0;
  return bytes * 8 / (elapsedMs / 1000.0) / 1000000.0;
}

String _friendly(Object e) {
  final text = e.toString().toLowerCase();
  if (text.contains('timeout') || text.contains('timed out')) {
    return '连接超时：测速节点可能被墙，挂代理或换自定义节点';
  }
  if (text.contains('handshake') || text.contains('socket')) {
    return '网络错误：$e';
  }
  return '测速失败：$e';
}

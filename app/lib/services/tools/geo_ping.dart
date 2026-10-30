import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// 一个探测节点的结果。
class GeoPingNode {
  GeoPingNode({
    required this.id,
    required this.country,
    this.rtt,
    this.reached,
  });

  /// 节点 ID，如 us1.node.check-host.net
  final String id;

  /// 国家/地区（check-host 返回的英文名）
  final String country;

  /// 往返时间
  final Duration? rtt;

  /// 是否成功；null 表示还在等结果
  final bool? reached;

  bool get pending => reached == null;

  bool get ok => reached == true;

  String get label {
    final prefix = id.split('.').first;
    return '$prefix · $country';
  }
}

/// GeoPing：通过 check-host.net 的公开接口，从多个地理位置 ping 同一目标。
///
/// check-host 的流程是两段式：先发起请求拿到 request_id 和节点清单，
/// 再轮询 check-result 拿每个节点的延迟。
class GeoPingService {
  GeoPingService._();

  static const String _base = 'https://check-host.net';
  static const Duration _pollInterval = Duration(milliseconds: 1200);
  static const Duration _timeout = Duration(seconds: 18);

  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) QShell/1.0',
  };

  /// 发起探测并轮询到结束。
  ///
  /// [onUpdate] 每轮轮询后回调当前节点快照，用于边等边显示。
  static Future<List<GeoPingNode>> ping(
    String host, {
    int maxNodes = 12,
    void Function(List<GeoPingNode> nodes)? onUpdate,
  }) async {
    final start = Uri.parse(
      '$_base/check-ping?host=${Uri.encodeQueryComponent(host)}&max_nodes=$maxNodes',
    );
    final startResp = await http
        .get(start, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (startResp.statusCode != 200) {
      throw Exception('check-host 返回 ${startResp.statusCode}');
    }
    final startJson = jsonDecode(startResp.body) as Map<String, dynamic>;
    if (startJson['ok'] != 1) {
      throw Exception('check-host 拒绝了请求：${startJson['error'] ?? '未知错误'}');
    }
    final requestId = startJson['request_id'] as String;
    final rawNodes = startJson['nodes'] as Map<String, dynamic>? ?? const {};

    final nodes = <String, GeoPingNode>{
      for (final entry in rawNodes.entries)
        entry.key: GeoPingNode(
          id: entry.key,
          country: _countryOf(entry.value),
        ),
    };
    onUpdate?.call(_sorted(nodes.values));

    final deadline = DateTime.now().add(_timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_pollInterval);
      final resultUri = Uri.parse('$_base/check-result/$requestId');
      final resultResp = await http
          .get(resultUri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resultResp.statusCode != 200) continue;
      final data = jsonDecode(resultResp.body) as Map<String, dynamic>;

      var allDone = true;
      for (final entry in data.entries) {
        final node = nodes[entry.key];
        if (node == null || !node.pending) continue;
        final parsed = _parseNodeResult(entry.value);
        if (parsed == null) {
          allDone = false;
          continue;
        }
        nodes[entry.key] = GeoPingNode(
          id: node.id,
          country: node.country,
          rtt: parsed.$1,
          reached: parsed.$2,
        );
      }
      onUpdate?.call(_sorted(nodes.values));
      if (allDone) break;
    }

    // 超时还没有结果的标记为失败
    final finished = <GeoPingNode>[
      for (final node in nodes.values)
        node.pending
            ? GeoPingNode(id: node.id, country: node.country, reached: false)
            : node,
    ];
    return _sorted(finished);
  }

  static List<GeoPingNode> _sorted(Iterable<GeoPingNode> nodes) {
    final list = nodes.toList();
    list.sort((a, b) {
      // 成功的按延迟升序在前；失败的排后面；等待中的排最后
      if (a.ok && b.ok) {
        return (a.rtt ?? Duration.zero).compareTo(b.rtt ?? Duration.zero);
      }
      if (a.ok != b.ok) return a.ok ? -1 : 1;
      if (a.pending != b.pending) return a.pending ? 1 : -1;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  static String _countryOf(dynamic value) {
    if (value is List && value.length >= 2) {
      return value[1]?.toString() ?? '';
    }
    return '';
  }

  /// 返回 (平均延迟, 是否成功)；还没结果返回 null。
  static (Duration?, bool)? _parseNodeResult(dynamic value) {
    // 结构：[[[ok, time, ...], [ok, time, ...], ...]]
    if (value == null) return (null, false);
    if (value is! List || value.isEmpty) return null;
    final attempts = value.first;
    if (attempts == null) return (null, false);
    if (attempts is! List) return null;

    final rtts = <double>[];
    for (final attempt in attempts) {
      if (attempt is! List || attempt.length < 2) continue;
      // check-host 的状态是字符串 "OK"（个别接口用数字 1），两种都认
      final status = attempt[0];
      final ok = status == 'OK' ||
          status == 'ok' ||
          status == true ||
          status == 1;
      if (!ok) continue;
      final seconds = attempt[1];
      if (seconds is num) rtts.add(seconds.toDouble());
    }
    if (rtts.isEmpty) {
      // 有结果但全部失败
      return (null, false);
    }
    final avg = rtts.reduce((a, b) => a + b) / rtts.length;
    return (Duration(microseconds: (avg * 1e6).round()), true);
  }
}

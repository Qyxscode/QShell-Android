import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 测试方向。
enum IperfDirection {
  up('上行（手机 → 服务器）', <String>[]),
  down('下行（服务器 → 手机）', <String>['-R']),
  both('双向（--bidir）', <String>['--bidir']);

  const IperfDirection(this.label, this.args);

  final String label;
  final List<String> args;
}

/// 一次 iperf3 的参数。
class IperfOptions {
  const IperfOptions({
    required this.host,
    required this.port,
    this.udp = false,
    this.direction = IperfDirection.up,
    this.streams = 1,
    this.bandwidth = '100M',
    this.durationSeconds = 10,
  });

  final String host;
  final int port;
  final bool udp;
  final IperfDirection direction;
  final int streams;

  /// UDP 限速，形如 100M / 1G / 20M
  final String bandwidth;
  final int durationSeconds;

  IperfOptions copyWith({
    String? host,
    int? port,
    bool? udp,
    IperfDirection? direction,
    int? streams,
    String? bandwidth,
    int? durationSeconds,
  }) =>
      IperfOptions(
        host: host ?? this.host,
        port: port ?? this.port,
        udp: udp ?? this.udp,
        direction: direction ?? this.direction,
        streams: streams ?? this.streams,
        bandwidth: bandwidth ?? this.bandwidth,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );

  List<String> toArgs() => <String>[
        '-c', host,
        '-p', '$port',
        '-t', '$durationSeconds',
        '-J',
        if (udp) ...<String>['-u', '-b', bandwidth],
        if (streams > 1) ...<String>['-P', '$streams'],
        ...direction.args,
      ];
}

/// 一次 iperf3 的结果。
class IperfResult {
  const IperfResult({
    this.sentMbps,
    this.receivedMbps,
    this.retransmits,
    this.jitterMs,
    this.lostPercent,
    this.lostPackets,
    this.isUdp = false,
    this.bidirectional = false,
    this.raw = '',
  });

  /// 客户端 → 服务器
  final double? sentMbps;

  /// 服务器 → 客户端
  final double? receivedMbps;
  final int? retransmits;
  final double? jitterMs;
  final double? lostPercent;
  final int? lostPackets;
  final bool isUdp;
  final bool bidirectional;
  final String raw;

  /// 主展示值：双向取两边较大值，单向取有值的那一边。
  double? get primaryMbps {
    if (bidirectional) {
      final a = sentMbps ?? 0;
      final b = receivedMbps ?? 0;
      return a > b ? a : b;
    }
    return sentMbps ?? receivedMbps;
  }

  String get verdict {
    final value = primaryMbps ?? 0;
    if (isUdp) {
      final loss = lostPercent ?? 0;
      if (loss > 5) return '丢包偏高（$loss%），链路可能拥塞或限速';
      if (loss > 0) return '有轻微丢包（$loss%），可用但不算干净';
      return 'UDP 无损，抖动 ${jitterMs?.toStringAsFixed(2) ?? "-"} ms';
    }
    final retry = retransmits ?? 0;
    if (retry > 500) return '重传很多（$retry），链路质量差或丢包严重';
    if (retry > 50) return '有重传（$retry），链路可能有轻微损失';
    if (value > 500) return '千兆级吞吐，链路很好';
    if (value > 100) return '百兆级吞吐，正常';
    if (value > 20) return '普通家宽水平';
    return '偏低，可能是 WiFi 信号差、限速或远端瓶颈';
  }
}

/// 快捷预设：点一下把参数填好，之后仍可手动改。
class IperfQuickPreset {
  const IperfQuickPreset({
    required this.name,
    required this.description,
    required this.udp,
    required this.direction,
    this.streams = 1,
    this.bandwidth = '100M',
  });

  final String name;
  final String description;
  final bool udp;
  final IperfDirection direction;
  final int streams;
  final String bandwidth;

  IperfOptions applyTo(IperfOptions base) => base.copyWith(
        udp: udp,
        direction: direction,
        streams: streams,
        bandwidth: bandwidth,
      );
}

const List<IperfQuickPreset> iperfQuickPresets = <IperfQuickPreset>[
  IperfQuickPreset(
    name: 'TCP 上行',
    description: '单流，手机发数据',
    udp: false,
    direction: IperfDirection.up,
  ),
  IperfQuickPreset(
    name: 'TCP 下行',
    description: '单流，服务器发数据（-R）',
    udp: false,
    direction: IperfDirection.down,
  ),
  IperfQuickPreset(
    name: 'TCP 双向',
    description: '同时跑上下行（--bidir）',
    udp: false,
    direction: IperfDirection.both,
  ),
  IperfQuickPreset(
    name: '4 流并发',
    description: '4 条 TCP 流（-P 4）',
    udp: false,
    direction: IperfDirection.up,
    streams: 4,
  ),
  IperfQuickPreset(
    name: 'UDP 100M',
    description: '限速 100 Mbps，看抖动丢包',
    udp: true,
    direction: IperfDirection.up,
    bandwidth: '100M',
  ),
  IperfQuickPreset(
    name: 'UDP 500M',
    description: '限速 500 Mbps',
    udp: true,
    direction: IperfDirection.up,
    bandwidth: '500M',
  ),
  IperfQuickPreset(
    name: 'UDP 双向',
    description: '双向 UDP，各 100 Mbps',
    udp: true,
    direction: IperfDirection.both,
    bandwidth: '100M',
  ),
];

/// 跑一次 iperf3。
Future<IperfResult> runIperf({
  required String binaryPath,
  required IperfOptions options,
}) async {
  final args = options.toArgs();
  final result = await Process.run(binaryPath, args).timeout(
        Duration(seconds: options.durationSeconds + 25),
      );

  if (result.exitCode != 0) {
    final err = (result.stderr as String).trim();
    final out = (result.stdout as String).trim();
    throw Exception(
      err.isNotEmpty
          ? err
          : (out.isNotEmpty ? out : 'iperf3 退出码 ${result.exitCode}'),
    );
  }

  final raw = result.stdout as String;
  try {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final end = data['end'] as Map<String, dynamic>?;
    if (end == null) throw const FormatException('没有 end 字段');

    final sum = end['sum'] as Map<String, dynamic>?;
    final sumSent = end['sum_sent'] as Map<String, dynamic>?;
    final sumReceived = end['sum_received'] as Map<String, dynamic>?;
    final isUdp = sum != null && sum['jitter_ms'] != null;

    double? sentMbps;
    double? receivedMbps;
    if (isUdp) {
      final bps = (sum['bits_per_second'] as num?)?.toDouble();
      sentMbps = bps == null ? null : bps / 1000000;
    } else {
      final sentBps = (sumSent?['bits_per_second'] as num?)?.toDouble();
      final recvBps = (sumReceived?['bits_per_second'] as num?)?.toDouble();
      switch (options.direction) {
        case IperfDirection.up:
          sentMbps = sentBps == null ? null : sentBps / 1000000;
        case IperfDirection.down:
          receivedMbps = recvBps == null ? null : recvBps / 1000000;
        case IperfDirection.both:
          sentMbps = sentBps == null ? null : sentBps / 1000000;
          receivedMbps = recvBps == null ? null : recvBps / 1000000;
      }
    }

    return IperfResult(
      sentMbps: sentMbps,
      receivedMbps: receivedMbps,
      retransmits: (sumSent?['retransmits'] as num?)?.toInt(),
      jitterMs: (sum?['jitter_ms'] as num?)?.toDouble(),
      lostPercent: (sum?['lost_percent'] as num?)?.toDouble(),
      lostPackets: (sum?['lost_packets'] as num?)?.toInt(),
      isUdp: isUdp,
      bidirectional: options.direction == IperfDirection.both,
      raw: raw,
    );
  } catch (e) {
    throw Exception('解析 iperf3 输出失败：$e');
  }
}

/// 友好的错误文案。
String iperfErrorText(Object e) {
  final text = e.toString().toLowerCase();
  if (text.contains('connection refused')) {
    return '连不上 iperf3 服务器：确认服务端已启动、端口对得上';
  }
  if (text.contains('unable to connect') || text.contains('timed out')) {
    return '连接超时：检查地址端口、防火墙是否放行 5201';
  }
  if (text.contains('busy') || text.contains('server is busy')) {
    return '服务器正忙：已经有人在上面跑测试，稍后再试';
  }
  if (text.contains('different version')) {
    return '服务端 iperf3 版本与客户端不兼容';
  }
  return '测试失败：${e.toString().replaceFirst('Exception: ', '')}';
}

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// 一条 DNS 记录。
class DnsRecord {
  const DnsRecord({
    required this.type,
    required this.value,
    this.ttl = 0,
  });

  final String type;
  final String value;
  final int ttl;
}

class DnsLookupResult {
  const DnsLookupResult({
    required this.server,
    required this.records,
    required this.elapsed,
    this.error,
  });

  final String server;
  final List<DnsRecord> records;
  final Duration elapsed;
  final String? error;
}

/// 支持的查询类型。
const Map<String, int> dnsTypes = <String, int>{
  'A': 1,
  'NS': 2,
  'CNAME': 5,
  'MX': 15,
  'TXT': 16,
  'AAAA': 28,
};

/// 常见公共 DNS（国内优先）。
const List<(String, String)> dnsServers = <(String, String)>[
  ('223.5.5.5', '阿里 DNS'),
  ('119.29.29.29', '腾讯 DNS'),
  ('1.1.1.1', 'Cloudflare'),
  ('8.8.8.8', 'Google'),
];

/// 最小可用的 DNS 查询客户端（UDP 53）。
///
/// 只做正向查询和 A/AAAA/NS/CNAME/MX/TXT 解析，够运维排查用。
Future<DnsLookupResult> dnsLookup(
  String name, {
  String server = '223.5.5.5',
  List<String> types = const <String>['A', 'AAAA'],
  Duration timeout = const Duration(seconds: 5),
}) async {
  final stopwatch = Stopwatch()..start();
  final records = <DnsRecord>[];
  final labels = _encodeName(name);
  if (labels == null) {
    return DnsLookupResult(
      server: server,
      records: const <DnsRecord>[],
      elapsed: stopwatch.elapsed,
      error: '域名格式不对',
    );
  }

  for (final typeName in types) {
    final type = dnsTypes[typeName];
    if (type == null) continue;
    try {
      final found = await _query(name, labels, server, type, timeout);
      records.addAll(found);
    } catch (e) {
      // 单个类型失败不影响其它类型
      if (records.isEmpty) {
        stopwatch.stop();
        return DnsLookupResult(
          server: server,
          records: const <DnsRecord>[],
          elapsed: stopwatch.elapsed,
          error: _friendly(e),
        );
      }
    }
  }

  stopwatch.stop();
  return DnsLookupResult(
    server: server,
    records: records,
    elapsed: stopwatch.elapsed,
  );
}

Future<List<DnsRecord>> _query(
  String name,
  List<int> encodedName,
  String server,
  int type,
  Duration timeout,
) async {
  final random = Random();
  final id = random.nextInt(0xFFFF);

  final builder = BytesBuilder();
  builder.addByte((id >> 8) & 0xFF);
  builder.addByte(id & 0xFF);
  builder.addByte(0x01); // RD
  builder.addByte(0x00);
  builder.addByte(0x00);
  builder.addByte(0x01); // QDCOUNT = 1
  builder.addByte(0x00);
  builder.addByte(0x00);
  builder.addByte(0x00);
  builder.addByte(0x00);
  builder.addByte(0x00);
  builder.addByte(0x00);
  builder.add(encodedName);
  builder.addByte((type >> 8) & 0xFF);
  builder.addByte(type & 0xFF);
  builder.addByte(0x00);
  builder.addByte(0x01); // IN

  final packet = builder.toBytes();

  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  try {
    socket.send(packet, InternetAddress(server), 53);
    final completer = Completer<Uint8List>();
    late StreamSubscription sub;
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('查询超时'));
      }
    });
    sub = socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        if (datagram.data.length < 12) return;
        final respId = (datagram.data[0] << 8) | datagram.data[1];
        if (respId != id) return;
        if (!completer.isCompleted) completer.complete(datagram.data);
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );
    try {
      final data = await completer.future;
      timer.cancel();
      return _parseResponse(data, name);
    } finally {
      await sub.cancel();
      timer.cancel();
    }
  } finally {
    socket.close();
  }
}

List<DnsRecord> _parseResponse(Uint8List data, String queryName) {
  final rcode = data[3] & 0x0F;
  if (rcode != 0) {
    throw FormatException(_rcodeText(rcode));
  }
  final ancount = (data[6] << 8) | data[7];
  if (ancount == 0) {
    throw const FormatException('没有记录');
  }

  var offset = 12;
  // 跳过 question 区
  final qdcount = (data[4] << 8) | data[5];
  for (var i = 0; i < qdcount; i++) {
    final skip = _skipName(data, offset);
    offset = skip + 4; // qtype + qclass
  }

  final records = <DnsRecord>[];
  for (var i = 0; i < ancount; i++) {
    final nameResult = _readName(data, offset);
    offset = nameResult.$2;
    if (offset + 10 > data.length) break;
    final type = (data[offset] << 8) | data[offset + 1];
    final ttl = (data[offset + 4] << 24) |
        (data[offset + 5] << 16) |
        (data[offset + 6] << 8) |
        data[offset + 7];
    final rdLength = (data[offset + 8] << 8) | data[offset + 9];
    final rdataOffset = offset + 10;
    if (rdataOffset + rdLength > data.length) break;

    final typeName = _typeName(type);
    final value = _readRdata(data, type, rdataOffset, rdLength);
    if (value != null) {
      records.add(DnsRecord(type: typeName, value: value, ttl: ttl));
    }
    offset = rdataOffset + rdLength;
  }

  if (records.isEmpty) {
    throw const FormatException('返回里没有可解析的记录');
  }
  return records;
}

String? _readRdata(Uint8List data, int type, int offset, int length) {
  switch (type) {
    case 1: // A
      if (length != 4) return null;
      return '${data[offset]}.${data[offset + 1]}.${data[offset + 2]}.${data[offset + 3]}';
    case 28: // AAAA
      if (length != 16) return null;
      final parts = <String>[];
      for (var i = 0; i < 16; i += 2) {
        parts.add(((data[offset + i] << 8) | data[offset + i + 1])
            .toRadixString(16));
      }
      return parts.join(':');
    case 2: // NS
    case 5: // CNAME
      return _readName(data, offset).$1;
    case 15: // MX
      final preference = (data[offset] << 8) | data[offset + 1];
      final host = _readName(data, offset + 2).$1;
      return '$preference $host';
    case 16: // TXT
      final builder = StringBuffer();
      var pos = offset;
      final end = offset + length;
      while (pos < end) {
        final len = data[pos];
        pos++;
        if (pos + len > end) break;
        builder.write(String.fromCharCodes(data.sublist(pos, pos + len)));
        pos += len;
      }
      return builder.toString();
    default:
      return null;
  }
}

String _typeName(int type) {
  for (final entry in dnsTypes.entries) {
    if (entry.value == type) return entry.key;
  }
  return 'TYPE$type';
}

String _rcodeText(int rcode) {
  switch (rcode) {
    case 1:
      return '查询格式错误';
    case 2:
      return '服务器故障';
    case 3:
      return '域名不存在（NXDOMAIN）';
    case 4:
      return '该类型不支持';
    case 5:
      return '服务器拒绝';
    default:
      return 'DNS 返回错误码 $rcode';
  }
}

/// 跳过域名（支持压缩指针），返回跳过后的偏移。
int _skipName(Uint8List data, int offset) {
  while (offset < data.length) {
    final len = data[offset];
    if (len == 0) return offset + 1;
    if (len & 0xC0 == 0xC0) return offset + 2;
    offset += len + 1;
  }
  return offset;
}

/// 读取域名，返回 (域名, 新偏移)。
(String, int) _readName(Uint8List data, int offset) {
  final parts = <String>[];
  var pos = offset;
  var jumps = 0;
  var nextOffset = offset;
  var jumped = false;

  while (pos < data.length) {
    final len = data[pos];
    if (len == 0) {
      pos++;
      if (!jumped) nextOffset = pos;
      break;
    }
    if (len & 0xC0 == 0xC0) {
      if (pos + 1 >= data.length) break;
      final pointer = ((len & 0x3F) << 8) | data[pos + 1];
      if (!jumped) nextOffset = pos + 2;
      jumped = true;
      pos = pointer;
      jumps++;
      if (jumps > 20) break;
      continue;
    }
    if (pos + 1 + len > data.length) break;
    parts.add(String.fromCharCodes(data.sublist(pos + 1, pos + 1 + len)));
    pos += len + 1;
    if (!jumped) nextOffset = pos;
  }
  return (parts.join('.'), nextOffset);
}

List<int>? _encodeName(String name) {
  final cleaned = name.trim().replaceAll(RegExp(r'^\.+|\.+$'), '');
  if (cleaned.isEmpty) return null;
  final builder = BytesBuilder();
  for (final label in cleaned.split('.')) {
    final bytes = label.codeUnits;
    if (bytes.length > 63) return null;
    builder.addByte(bytes.length);
    builder.add(bytes);
  }
  builder.addByte(0);
  return builder.toBytes();
}

String _friendly(Object e) {
  final text = e.toString().toLowerCase();
  if (text.contains('timeout')) return '查询超时，检查网络或换个 DNS';
  if (text.contains('nxdomain')) return '域名不存在（NXDOMAIN）';
  if (text.contains('format')) return e.toString().replaceFirst('FormatException: ', '');
  return '查询失败：$e';
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// mDNS / Bonjour 发现结果：IP → 推断出来的设备类型。
class MdnsResult {
  const MdnsResult({required this.ip, required this.kind, required this.services});

  final String ip;
  final String kind;
  final List<String> services;
}

/// 极简 mDNS 扫描器。
///
/// 向 224.0.0.251:5353 发 `_services._dns-sd._udp.local` 的 PTR 查询，
/// 收集响应里的 PTR / SRV / A 记录，按服务类型推断设备类别。
class MdnsScanner {
  MdnsScanner._();

  static const _group = '224.0.0.251';
  static const _port = 5353;

  /// 服务类型 → 设备类型
  static const Map<String, String> _serviceKinds = <String, String>{
    '_airplay._tcp': 'airplay',
    '_raop._tcp': 'airplay',
    '_companion-link._tcp': 'apple',
    '_googlecast._tcp': 'cast',
    '_ipp._tcp': 'printer',
    '_ipps._tcp': 'printer',
    '_printer._tcp': 'printer',
    '_pdl-datastream._tcp': 'printer',
    '_smb._tcp': 'nas',
    '_afpovertcp._tcp': 'apple',
    '_ssh._tcp': 'linux',
    '_sftp-ssh._tcp': 'linux',
    '_http._tcp': 'web',
    '_miio._udp': 'mijia',
    '_hap._tcp': 'homekit',
    '_spotify-connect._tcp': 'speaker',
    '_sonos._tcp': 'speaker',
    '_nfs._tcp': 'nas',
    '_workstation._tcp': 'workstation',
  };

  static String _kindFor(String service) {
    final lower = service.toLowerCase();
    for (final entry in _serviceKinds.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return '';
  }

  /// 跑一次 mDNS 发现，返回按 IP 归并的结果。
  static Future<List<MdnsResult>> scan({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _port,
        reuseAddress: true,
      );
      socket.multicastHops = 2;
      try {
        socket.joinMulticast(InternetAddress(_group));
      } catch (_) {
        // 加入组失败也继续，多数情况下仍能收到单播响应
      }
      socket.send(_buildQuery(), InternetAddress(_group), _port);

      final ipToServices = <String, Set<String>>{};
      final completer = Completer<void>();
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket?.receive();
        if (datagram == null) return;
        try {
          _parsePacket(datagram.data, datagram.address.address, ipToServices);
        } catch (_) {
          // 单条包解析失败忽略
        }
      });
      Timer(timeout, () {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
      await sub.cancel();

      final results = <MdnsResult>[];
      for (final entry in ipToServices.entries) {
        // 选第一个能识别的服务作为类型
        String kind = '';
        for (final service in entry.value) {
          final k = _kindFor(service);
          if (k.isNotEmpty) {
            kind = k;
            break;
          }
        }
        if (kind.isEmpty && entry.value.isEmpty) continue;
        results.add(
          MdnsResult(
            ip: entry.key,
            kind: kind.isEmpty ? 'bonjour' : kind,
            services: entry.value.toList(),
          ),
        );
      }
      return results;
    } catch (_) {
      return const <MdnsResult>[];
    } finally {
      try {
        socket?.close();
      } catch (_) {}
    }
  }

  static Uint8List _buildQuery() {
    final builder = BytesBuilder();
    builder.add(<int>[0x00, 0x00]); // ID
    builder.add(<int>[0x00, 0x00]); // Flags: standard query
    builder.add(<int>[0x00, 0x01]); // QDCOUNT
    builder.add(<int>[0x00, 0x00]); // ANCOUNT
    builder.add(<int>[0x00, 0x00]); // NSCOUNT
    builder.add(<int>[0x00, 0x00]); // ARCOUNT
    for (final part in '_services._dns-sd._udp.local'.split('.')) {
      final bytes = utf8.encode(part);
      builder.addByte(bytes.length);
      builder.add(bytes);
    }
    builder.addByte(0); // 名字结束
    builder.add(<int>[0x00, 0x0C]); // QTYPE: PTR
    builder.add(<int>[0x00, 0x01]); // QCLASS: IN
    return builder.toBytes();
  }

  /// 解析一个 mDNS 响应包，把 PTR/SRV/A 信息写进 [out]。
  static void _parsePacket(
    Uint8List data,
    String sourceIp,
    Map<String, Set<String>> out,
  ) {
    if (data.length < 12) return;
    final qdCount = (data[4] << 8) | data[5];
    final anCount = (data[6] << 8) | data[7];
    final arCount = (data[10] << 8) | data[11];

    var offset = 12;
    // 跳过问题区
    for (var i = 0; i < qdCount; i++) {
      offset = _skipName(data, offset);
      offset += 4; // QTYPE + QCLASS
      if (offset > data.length) return;
    }

    final records = anCount + arCount;
    for (var i = 0; i < records; i++) {
      if (offset >= data.length) break;
      final nameResult = _readName(data, offset);
      offset = nameResult.$2;
      if (offset + 10 > data.length) break;
      final type = (data[offset] << 8) | data[offset + 1];
      final rdLength = (data[offset + 8] << 8) | data[offset + 9];
      offset += 10;
      if (offset + rdLength > data.length) break;
      final rdataOffset = offset;

      switch (type) {
        case 12: // PTR：服务类型
          final target = _readName(data, rdataOffset);
          out.putIfAbsent(sourceIp, () => <String>{}).add(target.$1);
        case 1: // A：IPv4
          if (rdLength == 4) {
            final ip = '${data[rdataOffset]}.${data[rdataOffset + 1]}.'
                '${data[rdataOffset + 2]}.${data[rdataOffset + 3]}';
            // 记录名里常带服务类型，一并归到该 IP
            out.putIfAbsent(ip, () => <String>{}).add(nameResult.$1);
          }
        case 33: // SRV：实例指向主机
          final target = _readName(data, rdataOffset + 6);
          out.putIfAbsent(sourceIp, () => <String>{}).add(nameResult.$1);
          out.putIfAbsent(sourceIp, () => <String>{}).add(target.$1);
      }

      offset = rdataOffset + rdLength;
    }
  }

  /// 跳过一个（可能压缩的）名字，返回新偏移。
  static int _skipName(Uint8List data, int offset) {
    var o = offset;
    while (o < data.length) {
      final len = data[o];
      if (len == 0) return o + 1;
      if ((len & 0xC0) == 0xC0) return o + 2;
      o += 1 + len;
    }
    return o;
  }

  /// 读一个名字（处理 0xC0 压缩指针），返回 (名字, 新偏移)。
  static (String, int) _readName(Uint8List data, int offset) {
    final parts = <String>[];
    var o = offset;
    var jumped = false;
    var nextOffset = offset;
    var guard = 0;

    while (o < data.length && guard++ < 64) {
      final len = data[o];
      if (len == 0) {
        o += 1;
        if (!jumped) nextOffset = o;
        break;
      }
      if ((len & 0xC0) == 0xC0) {
        if (o + 1 >= data.length) break;
        final pointer = ((len & 0x3F) << 8) | data[o + 1];
        if (!jumped) nextOffset = o + 2;
        jumped = true;
        o = pointer;
        continue;
      }
      if (o + 1 + len > data.length) break;
      parts.add(utf8.decode(data.sublist(o + 1, o + 1 + len), allowMalformed: true));
      o += 1 + len;
      if (!jumped) nextOffset = o;
    }
    return (parts.join('.'), nextOffset);
  }
}

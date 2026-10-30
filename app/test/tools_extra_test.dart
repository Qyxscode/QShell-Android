import 'package:flutter_test/flutter_test.dart';
import 'package:qshell/services/tools/ping_service.dart';
import 'package:qshell/services/tools/wol.dart';

void main() {
  group('WoL', () {
    test('解析多种 MAC 写法', () {
      final a = WolService.parseMac('AA:BB:CC:DD:EE:FF')!;
      final b = WolService.parseMac('aa-bb-cc-dd-ee-ff')!;
      final c = WolService.parseMac('AABBCCDDEEFF')!;
      expect(a, b);
      expect(b, c);
      expect(a.length, 6);
      expect(a.first, 0xAA);
      expect(a.last, 0xFF);
    });

    test('非法 MAC 返回 null', () {
      expect(WolService.parseMac('AA:BB:CC'), isNull);
      expect(WolService.parseMac('GG:BB:CC:DD:EE:FF'), isNull);
      expect(WolService.parseMac(''), isNull);
    });

    test('魔术包结构与长度', () {
      final mac = WolService.parseMac('01:02:03:04:05:06')!;
      final packet = WolService.buildPacket(mac);
      expect(packet.length, 102);
      for (var i = 0; i < 6; i++) {
        expect(packet[i], 0xFF);
      }
      for (var i = 0; i < 16; i++) {
        for (var j = 0; j < 6; j++) {
          expect(packet[6 + i * 6 + j], mac[j]);
        }
      }
    });

    test('格式化回标准写法', () {
      final mac = WolService.parseMac('aa:bb:cc:dd:ee:0f')!;
      expect(WolService.formatMac(mac), 'AA:BB:CC:DD:EE:0F');
    });
  });

  group('Ping 汇总', () {
    test('全部成功', () {
      final results = <PingResult>[
        const PingResult(seq: 1, rtt: Duration(milliseconds: 10)),
        const PingResult(seq: 2, rtt: Duration(milliseconds: 20)),
        const PingResult(seq: 3, rtt: Duration(milliseconds: 30)),
      ];
      final summary = summarizePing(results);
      expect(summary.sent, 3);
      expect(summary.received, 3);
      expect(summary.lossPercent, 0);
      expect(summary.min!.inMilliseconds, 10);
      expect(summary.max!.inMilliseconds, 30);
      expect(summary.avg!.inMilliseconds, 20);
    });

    test('部分丢包', () {
      final results = <PingResult>[
        const PingResult(seq: 1, rtt: Duration(milliseconds: 10)),
        const PingResult(seq: 2, error: '超时'),
        const PingResult(seq: 3, rtt: Duration(milliseconds: 20)),
        const PingResult(seq: 4, error: '超时'),
      ];
      final summary = summarizePing(results);
      expect(summary.received, 2);
      expect(summary.lossPercent, 50);
    });

    test('全部失败', () {
      final results = <PingResult>[
        const PingResult(seq: 1, error: '超时'),
      ];
      final summary = summarizePing(results);
      expect(summary.received, 0);
      expect(summary.min, isNull);
      expect(summary.lossPercent, 100);
    });
  });
}

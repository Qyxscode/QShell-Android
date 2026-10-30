import 'package:flutter_test/flutter_test.dart';
import 'package:qshell/services/tools/ip_calculator.dart';
import 'package:qshell/services/tools/port_scanner.dart';

void main() {
  group('IP 计算器', () {
    test('/24 常见网段', () {
      final r = calculateIpv4('192.168.1.0/24')!;
      expect(r.network, '192.168.1.0');
      expect(r.broadcast, '192.168.1.255');
      expect(r.mask, '255.255.255.0');
      expect(r.firstHost, '192.168.1.1');
      expect(r.lastHost, '192.168.1.254');
      expect(r.hostCount, 254);
      expect(r.isPrivate, isTrue);
    });

    test('/32 单主机', () {
      final r = calculateIpv4('8.8.8.8/32')!;
      expect(r.prefix, 32);
      expect(r.network, '8.8.8.8');
      expect(r.hostCount, 1);
      expect(r.isPrivate, isFalse);
    });

    test('/31 点对点', () {
      final r = calculateIpv4('10.0.0.0/31')!;
      expect(r.hostCount, 2);
      expect(r.firstHost, '10.0.0.0');
      expect(r.lastHost, '10.0.0.1');
    });

    test('掩码写法', () {
      final r = calculateIpv4('172.16.5.10 255.255.0.0')!;
      expect(r.prefix, 16);
      expect(r.network, '172.16.0.0');
    });

    test('/0 全零网段', () {
      final r = calculateIpv4('0.0.0.0/0')!;
      expect(r.mask, '0.0.0.0');
      expect(r.broadcast, '255.255.255.255');
    });

    test('非法输入返回 null', () {
      expect(calculateIpv4(''), isNull);
      expect(calculateIpv4('300.1.1.1/24'), isNull);
      expect(calculateIpv4('1.2.3.4/33'), isNull);
      expect(calculateIpv4('abc/24'), isNull);
    });
  });

  group('端口解析', () {
    test('逗号与区间', () {
      expect(parsePorts('80,443,8000-8002'), [80, 443, 8000, 8001, 8002]);
    });

    test('去重与排序', () {
      expect(parsePorts('443,80,443'), [80, 443]);
    });

    test('非法输入被忽略', () {
      expect(parsePorts('abc, 70000, -5, 22'), [22]);
    });
  });
}

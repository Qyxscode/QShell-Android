import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qshell/services/qshell_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sampleJson = '''
{
  "version": "1.1",
  "devices": [
    {
      "group": "VPS",
      "hosts": [
        {"name": "东京", "protocol": "ssh", "host": "1.2.3.4", "port": 2281, "user": "root", "pwd": "x"},
        {"name": "香港", "protocol": "ssh", "host": "5.6.7.8", "port": 22, "user": "root", "pwd": "y"}
      ]
    },
    {
      "group": "本地",
      "hosts": [
        {"name": "PVE", "protocol": "ssh", "host": "192.168.1.2", "port": 22, "user": "root", "pwd": "z"},
        {"name": "网络设备", "protocol": "telnet", "host": "192.168.1.1", "port": 23, "user": "admin", "pwd": "k"}
      ]
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = QShellConfigStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('解析纯 JSON 配置', () async {
    final groups = await store.importFromBytes(utf8.encode(_sampleJson));
    expect(groups.length, 2);
    expect(groups[0].name, 'VPS');
    expect(groups[0].hosts.length, 2);
    expect(groups[0].hosts[0].host, '1.2.3.4');
    expect(groups[0].hosts[0].port, 2281);
    expect(groups[1].hosts[1].isSsh, isFalse);
    expect(groups[1].hosts[1].protocol, 'telnet');
  });

  test('解析备份 zip（qshell_config.json）', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'qshell_config.json',
          utf8.encode(_sampleJson).length,
          utf8.encode(_sampleJson),
        ),
      );
    final bytes = ZipEncoder().encode(archive);

    final groups = await store.importFromBytes(bytes);
    expect(groups.length, 2);
    expect(groups[1].hosts.length, 2);
  });

  test('zip 里没有配置文件时报错', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile('readme.txt', 5, utf8.encode('hello')),
      );
    final bytes = ZipEncoder().encode(archive);

    expect(
      () => store.importFromBytes(bytes),
      throwsA(isA<FormatException>()),
    );
  });
}

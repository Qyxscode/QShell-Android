import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 桌面版 QShell 的一条连接配置。
class QShellHost {
  const QShellHost({
    required this.name,
    required this.protocol,
    required this.host,
    required this.port,
    required this.user,
    this.password = '',
    this.keyPath,
    this.passphrase,
    this.group = '',
    this.proxyHost,
    this.proxyPort,
    this.proxyUser,
    this.proxyPwd,
    this.proxyKey,
    this.proxyPassphrase,
  });

  final String name;
  final String protocol;
  final String host;
  final int port;
  final String user;
  final String password;
  final String? keyPath;

  /// 私钥密码短语（加密私钥才需要）
  final String? passphrase;

  /// 所属分组名（编辑时改它等于把连接挪到别的组）
  final String group;

  // ---- 跳板机（ProxyJump）----
  final String? proxyHost;
  final int? proxyPort;
  final String? proxyUser;
  final String? proxyPwd;
  final String? proxyKey;
  final String? proxyPassphrase;

  bool get isSsh => protocol == 'ssh';

  /// 是否配置了跳板
  bool get hasProxy => (proxyHost ?? '').isNotEmpty;

  /// 跳板摘要，用于界面展示
  String? get proxyLabel {
    if (!hasProxy) return null;
    final user = (proxyUser ?? '').isEmpty ? '' : '${proxyUser!}@';
    return '经跳板 $user${proxyHost!}:${proxyPort ?? 22}';
  }

  String get subtitle => '$user@$host:$port';

  QShellHost copyWith({
    String? name,
    String? protocol,
    String? host,
    int? port,
    String? user,
    String? password,
    String? keyPath,
    String? passphrase,
    String? group,
    String? proxyHost,
    int? proxyPort,
    String? proxyUser,
    String? proxyPwd,
    String? proxyKey,
    String? proxyPassphrase,
  }) =>
      QShellHost(
        name: name ?? this.name,
        protocol: protocol ?? this.protocol,
        host: host ?? this.host,
        port: port ?? this.port,
        user: user ?? this.user,
        password: password ?? this.password,
        keyPath: keyPath ?? this.keyPath,
        passphrase: passphrase ?? this.passphrase,
        group: group ?? this.group,
        proxyHost: proxyHost ?? this.proxyHost,
        proxyPort: proxyPort ?? this.proxyPort,
        proxyUser: proxyUser ?? this.proxyUser,
        proxyPwd: proxyPwd ?? this.proxyPwd,
        proxyKey: proxyKey ?? this.proxyKey,
        proxyPassphrase: proxyPassphrase ?? this.proxyPassphrase,
      );
}


/// 一条备忘录（快捷命令）：对应桌面版右侧面板的 memo 标签页。
class QShellMemo {
  const QShellMemo({required this.name, required this.cmd});

  final String name;
  final String cmd;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'cmd': cmd,
      };
}

/// 备忘录分组。
class QShellMemoGroup {
  const QShellMemoGroup({required this.group, required this.items});

  final String group;
  final List<QShellMemo> items;
}
/// 分组。
class QShellGroup {
  const QShellGroup({required this.name, required this.hosts});

  final String name;
  final List<QShellHost> hosts;
}

/// 读取 / 导入桌面版配置（config.json 或备份 zip）。
///
/// 桌面版备份 zip 里只有一个文件：`qshell_config.json`（早期是 `config.json`），
/// 内容就是完整的配置 JSON。
class QShellConfigStore {
  static const _kKey = 'qshell.config_json';

  /// 桌面版 managed_hosts（主机管理）在手机端的展示分组名
  static const String managedGroupName = '主机管理';

  // ---------- 读取 ----------

  Future<List<QShellGroup>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return const <QShellGroup>[];
    try {
      return _parseJson(raw);
    } catch (_) {
      return const <QShellGroup>[];
    }
  }

  Future<bool> hasConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    return raw != null && raw.isNotEmpty;
  }

  /// 导出用的原始配置 JSON（没有导入过就从当前连接重建一份）。
  Future<String> exportRawJson() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw != null && raw.isNotEmpty) return raw;
    final groups = await load();
    return jsonEncode(<String, dynamic>{
      'version': '1.1',
      'devices': <Map<String, dynamic>>[
        for (final group in groups)
          <String, dynamic>{
            'group': group.name,
            'is_standalone_host': false,
            'hosts': <Map<String, dynamic>>[
              for (final host in group.hosts) _hostToJson(host),
            ],
          },
      ],
    });
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }

  // ---------- 导入 ----------

  /// 从文件字节导入；自动识别 zip 与纯 JSON。
  Future<List<QShellGroup>> importFromBytes(List<int> bytes) async {
    final rawJson = _extractJson(bytes);
    // 先解析验证，避免存进去一个坏配置
    final groups = _parseJson(rawJson);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, rawJson);
    return groups;
  }

  // ---------- 增删（直接改存储的 JSON，导入的配置也一样能改） ----------

  /// 新增一条连接；分组取 `host.group`，为空就落到「我的连接」。
  Future<List<QShellGroup>> addHost(QShellHost host) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _loadMap(prefs);
    final group = host.group.trim().isEmpty ? '我的连接' : host.group.trim();
    final devices = (map['devices'] as List?)?.toList() ?? <dynamic>[];

    Map<String, dynamic>? target;
    for (final device in devices) {
      if (device is Map && (device['group'] as String?) == group) {
        target = device.cast<String, dynamic>();
        break;
      }
    }
    if (target == null) {
      target = <String, dynamic>{
        'group': group,
        'is_standalone_host': false,
        'hosts': <dynamic>[],
      };
      devices.add(target);
    }

    final hosts = (target['hosts'] as List?)?.toList() ?? <dynamic>[];
    hosts.add(_hostToJson(host));
    target['hosts'] = hosts;
    map['devices'] = devices;

    final raw = jsonEncode(map);
    await prefs.setString(_kKey, raw);
    return _parseJson(raw);
  }


  // ---------- 备忘录 ----------

  /// 读取桌面版 config.json 里的 memos。
  Future<List<QShellMemoGroup>> loadMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _loadMap(prefs);
    final raw = map['memos'];
    if (raw is! List) return const <QShellMemoGroup>[];
    final groups = <QShellMemoGroup>[];
    for (final group in raw) {
      if (group is! Map) continue;
      final name = (group['group'] as String?)?.trim() ?? '';
      final itemsRaw = group['items'];
      final items = <QShellMemo>[];
      if (itemsRaw is List) {
        for (final item in itemsRaw) {
          if (item is! Map) continue;
          final cmd = (item['cmd'] as String?) ?? '';
          if (cmd.isEmpty) continue;
          items.add(QShellMemo(
            name: (item['name'] as String?)?.trim() ?? '',
            cmd: cmd,
          ));
        }
      }
      groups.add(QShellMemoGroup(group: name, items: items));
    }
    return groups;
  }

  /// 整体写回 memos（分组层级与桌面版一致）。
  Future<void> saveMemos(List<QShellMemoGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _loadMap(prefs);
    map['memos'] = <dynamic>[
      for (final group in groups)
        <String, dynamic>{
          'group': group.group,
          'items': <dynamic>[
            for (final item in group.items) item.toJson(),
          ],
        },
    ];
    await prefs.setString(_kKey, jsonEncode(map));
  }
  Map<String, dynamic> _hostToJson(QShellHost host) => <String, dynamic>{
        'name': host.name,
        'protocol': host.protocol,
        'host': host.host,
        'port': host.port,
        'user': host.user,
        'pwd': host.password,
        'key_path': host.keyPath,
        if ((host.passphrase ?? '').isNotEmpty) 'passphrase': host.passphrase,
        // 跳板机（有才写，避免给没配跳板的连接凭空加字段）
        if (host.hasProxy) ...<String, dynamic>{
          'proxy_host': host.proxyHost,
          if (host.proxyPort != null) 'proxy_port': host.proxyPort,
          if ((host.proxyUser ?? '').isNotEmpty)
            'proxy_user': host.proxyUser,
          if ((host.proxyPwd ?? '').isNotEmpty) 'proxy_pwd': host.proxyPwd,
          if ((host.proxyKey ?? '').isNotEmpty) 'proxy_key': host.proxyKey,
          if ((host.proxyPassphrase ?? '').isNotEmpty)
            'proxy_passphrase': host.proxyPassphrase,
        },
      };

  /// 修改一条连接（按 host + port + user 定位）。
  /// 如果 `newHost.group` 和原来不同，等于把连接移动到新分组。
  Future<List<QShellGroup>> updateHost(
    QShellHost oldHost,
    QShellHost newHost,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _loadMap(prefs);
    final devices = (map['devices'] as List?)?.toList() ?? <dynamic>[];

    // 先摊平成 (group, hostJson)，方便移动分组
    final flattened = <(String, Map<String, dynamic>)>[];
    for (final device in devices) {
      if (device is! Map) continue;
      final group = (device['group'] as String?) ?? '未分组';
      final hosts = device['hosts'];
      if (hosts is! List) continue;
      for (final item in hosts) {
        if (item is Map) {
          flattened.add((group, item.cast<String, dynamic>()));
        }
      }
    }

    final targetGroup = newHost.group.trim().isEmpty
        ? (oldHost.group.trim().isEmpty ? '我的连接' : oldHost.group.trim())
        : newHost.group.trim();

    final rebuilt = <(String, Map<String, dynamic>)>[];
    var replaced = false;
    for (final (group, item) in flattened) {
      final matched = !replaced &&
          item['host'] == oldHost.host &&
          (item['port'] as num?)?.toInt() == oldHost.port &&
          item['user'] == oldHost.user;
      if (matched) {
        replaced = true;
        rebuilt.add((
          targetGroup,
          <String, dynamic>{...item, ..._hostToJson(newHost)},
        ));
      } else {
        rebuilt.add((group, item));
      }
    }

    map['devices'] = _groupDevices(rebuilt);
    final raw = jsonEncode(map);
    await prefs.setString(_kKey, raw);
    return _parseJson(raw);
  }

  /// 删除一条连接（按 host + port + user 匹配）；组空了就把组也删掉。
  Future<List<QShellGroup>> removeHost(QShellHost host) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _loadMap(prefs);
    final devices = (map['devices'] as List?)?.toList() ?? <dynamic>[];

    final flattened = <(String, Map<String, dynamic>)>[];
    for (final device in devices) {
      if (device is! Map) continue;
      final group = (device['group'] as String?) ?? '未分组';
      final hosts = device['hosts'];
      if (hosts is! List) continue;
      for (final item in hosts) {
        if (item is! Map) continue;
        final matched = item['host'] == host.host &&
            (item['port'] as num?)?.toInt() == host.port &&
            item['user'] == host.user;
        if (!matched) {
          flattened.add((group, item.cast<String, dynamic>()));
        }
      }
    }

    map['devices'] = _groupDevices(flattened);
    final raw = jsonEncode(map);
    await prefs.setString(_kKey, raw);
    return _parseJson(raw);
  }

  List<Map<String, dynamic>> _groupDevices(
    List<(String, Map<String, dynamic>)> flattened,
  ) {
    final order = <String>[];
    final buckets = <String, List<dynamic>>{};
    for (final (group, item) in flattened) {
      if (!buckets.containsKey(group)) {
        order.add(group);
        buckets[group] = <dynamic>[];
      }
      buckets[group]!.add(item);
    }
    return [
      for (final group in order)
        if (buckets[group]!.isNotEmpty)
          <String, dynamic>{
            'group': group,
            'is_standalone_host': false,
            'hosts': buckets[group]!,
          },
    ];
  }

  Map<String, dynamic> _loadMap(SharedPreferences prefs) {
    final existing = prefs.getString(_kKey);
    if (existing == null || existing.isEmpty) {
      return <String, dynamic>{'version': '1.1', 'devices': <dynamic>[]};
    }
    final decoded = jsonDecode(existing);
    if (decoded is! Map) {
      return <String, dynamic>{'version': '1.1', 'devices': <dynamic>[]};
    }
    return decoded.cast<String, dynamic>();
  }

  String _extractJson(List<int> bytes) {
    final isZip = bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
    if (!isZip) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    final file = archive.findFile('qshell_config.json') ??
        archive.findFile('config.json');
    if (file == null) {
      throw const FormatException('备份包里没有 qshell_config.json / config.json');
    }
    final content = file.readBytes();
    if (content == null) {
      throw const FormatException('备份包内的配置文件读取失败');
    }
    return utf8.decode(content, allowMalformed: true);
  }

  List<QShellGroup> _parseJson(String raw) {
    final map = jsonDecode(raw);
    if (map is! Map) throw const FormatException('配置不是合法的 JSON 对象');
    final devices = map['devices'];
    if (devices is! List) throw const FormatException('配置里没有 devices 字段');

    final groups = <QShellGroup>[];
    for (final device in devices) {
      if (device is! Map) continue;
      final groupName = (device['group'] as String?)?.trim();
      final resolvedGroup =
          (groupName == null || groupName.isEmpty) ? '未分组' : groupName;
      final hostsRaw = device['hosts'];
      if (hostsRaw is! List) continue;
      final hosts = <QShellHost>[];
      for (final h in hostsRaw) {
        if (h is! Map) continue;
        final host = (h['host'] as String?)?.trim();
        if (host == null || host.isEmpty) continue;
        hosts.add(
          QShellHost(
            name: (h['name'] as String?)?.trim().isNotEmpty == true
                ? h['name'] as String
                : host,
            protocol: (h['protocol'] as String?) ?? 'ssh',
            host: host,
            port: (h['port'] as num?)?.toInt() ?? 22,
            user: (h['user'] as String?) ?? '',
            password: (h['pwd'] as String?) ?? '',
            keyPath: h['key_path'] as String?,
            passphrase: h['passphrase'] as String?,
            group: resolvedGroup,
            proxyHost: (h['proxy_host'] as String?)?.trim(),
            proxyPort: (h['proxy_port'] as num?)?.toInt(),
            proxyUser: (h['proxy_user'] as String?)?.trim(),
            proxyPwd: h['proxy_pwd'] as String?,
            proxyKey: h['proxy_key'] as String?,
            proxyPassphrase: h['proxy_passphrase'] as String?,
          ),
        );
      }
      if (hosts.isEmpty) continue;
      if (hosts.isEmpty) continue;
      groups.add(QShellGroup(name: resolvedGroup, hosts: hosts));
    }

    // 桌面版没规定 devices 与 managed_hosts 互斥，同一台主机可能两边都有。
    // 用 host:port 去重，避免同一台机器在列表里出现两次。
    final seen = <String>{
      for (final group in groups)
        for (final host in group.hosts) '${host.host}:${host.port}',
    };
    // 这里把它作为额外分组追加，命名为「主机管理」，只读展示。
    final managed = map['managed_hosts'];
    if (managed is List && managed.isNotEmpty) {
      final hosts = <QShellHost>[];
      for (final h in managed) {
        if (h is! Map) continue;
        final host = (h['host'] as String?)?.trim();
        if (host == null || host.isEmpty) continue;
        final port = (h['port'] as num?)?.toInt() ?? 22;
        if (!seen.add('$host:$port')) continue;
        hosts.add(
          QShellHost(
            name: (h['name'] as String?)?.trim().isNotEmpty == true
                ? h['name'] as String
                : host,
            protocol: (h['protocol'] as String?) ?? 'ssh',
            host: host,
            port: (h['port'] as num?)?.toInt() ?? 22,
            user: (h['user'] as String?) ?? '',
            password: (h['pwd'] as String?) ?? '',
            keyPath: h['key_path'] as String?,
            passphrase: h['passphrase'] as String?,
            group: managedGroupName,
            proxyHost: (h['proxy_host'] as String?)?.trim(),
            proxyPort: (h['proxy_port'] as num?)?.toInt(),
            proxyUser: (h['proxy_user'] as String?)?.trim(),
            proxyPwd: h['proxy_pwd'] as String?,
            proxyKey: h['proxy_key'] as String?,
            proxyPassphrase: h['proxy_passphrase'] as String?,
          ),
        );
      }
      if (hosts.isNotEmpty) {
        groups.add(QShellGroup(name: managedGroupName, hosts: hosts));
      }
    }
    return groups;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 主页链路信息的一次快照。
@immutable
class NetworkSnapshot {
  const NetworkSnapshot({
    required this.updatedAt,
    this.kinds = const <ConnectivityResult>[],
    this.localIp,
    this.interfaceName,
    this.publicIp,
    this.region,
    this.directIp,
    this.gatewayV4,
    this.gatewayV6,
    this.publicIpV6,
    this.error,
  });

  final DateTime updatedAt;
  final List<ConnectivityResult> kinds;
  final String? localIp;
  final String? interfaceName;
  final String? publicIp;
  final String? region;

  /// 绕开代理探到的直连出口 IP（与 [publicIp] 不一致说明在走代理）
  final String? directIp;

  /// 默认网关（上级设备）IPv4 地址
  final String? gatewayV4;

  /// 默认网关 IPv6 地址（通常是 fe80:: 链路本地地址）
  final String? gatewayV6;

  /// 公网 IPv6 地址（IPv6 可用时才有）
  final String? publicIpV6;

  final String? error;

  /// 网卡的友好名称：wlan0 → WiFi、rmnet_data3 → 移动网络、eth0 → 以太网。
  /// 直接显示内核接口名（rmnet_data3 之类）对用户没意义。
  String? get interfaceLabel {
    final name = interfaceName;
    if (name == null || name.isEmpty) return null;
    final lower = name.toLowerCase();
    if (lower.startsWith('wlan')) return 'WiFi';
    if (lower.startsWith('rmnet') || lower.startsWith('ccmni')) {
      return '移动网络';
    }
    if (lower.startsWith('eth')) return '以太网';
    if (lower.startsWith('p2p')) return 'WiFi 直连';
    if (lower.startsWith('tun') || lower.startsWith('ppp')) return 'VPN';
    return name;
  }

  /// 是否正在走代理（直连出口与代理出口不一致）。
  bool get viaProxy =>
      directIp != null && publicIp != null && directIp != publicIp;

  bool get online => kinds.any((k) => k != ConnectivityResult.none);

  String get kindLabel {
    if (kinds.isEmpty || kinds.contains(ConnectivityResult.none)) return '离线';
    if (kinds.contains(ConnectivityResult.wifi)) return 'Wi-Fi';
    if (kinds.contains(ConnectivityResult.mobile)) return '移动网络';
    if (kinds.contains(ConnectivityResult.ethernet)) return '有线';
    if (kinds.contains(ConnectivityResult.vpn)) return 'VPN';
    return kinds.first.name;
  }
}

/// 公网信息（IP + 地区）。
@immutable
class PublicIpInfo {
  const PublicIpInfo({required this.ip, this.region});

  final String ip;
  final String? region;
}

/// 主页数据源。
///
/// 公网信息走多源回退 + 缓存，避免单个免费接口限流（ipapi.co 的 429 就是这么来的）：
/// 1. ipinfo.io（带城市/地区，额度较宽）
/// 2. cloudflare trace（基本不限流，只有国家代码）
/// 3. ipify（只保证能拿到 IP）
class NetworkInfoService {
  NetworkInfoService({
    http.Client? client,
    Future<String?> Function()? directIpProvider,
    Future<Map<String, String>> Function()? gatewayProvider,
  })  : _client = client ?? http.Client(),
        // ignore: prefer_initializing_formals
        _directIpProvider = directIpProvider,
        // ignore: prefer_initializing_formals
        _gatewayProvider = gatewayProvider;

  final http.Client _client;

  /// 直连出口 IP 的探测（需要原生通道绑定物理网络），由外部注入。
  final Future<String?> Function()? _directIpProvider;

  /// 默认网关的探测（原生通道，返回 v4/v6），由外部注入。
  final Future<Map<String, String>> Function()? _gatewayProvider;
  final Connectivity _connectivity = Connectivity();

  /// 缓存 10 分钟；网络切换时会强制刷新。
  static const Duration _cacheTtl = Duration(minutes: 10);

  /// 两次探测的最小间隔，防止页面反复刷新把额度刷光。
  static const Duration _minInterval = Duration(seconds: 15);

  PublicIpInfo? _publicCache;
  DateTime? _publicAt;
  DateTime? _lastAttempt;
  String? _directIpCache;
  DateTime? _directIpAt;
  String? _publicV6Cache;
  DateTime? _publicV6At;

  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  Future<List<ConnectivityResult>> currentConnectivity() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (_) {
      return const <ConnectivityResult>[ConnectivityResult.none];
    }
  }

  /// [force] = true 时忽略最小间隔（网络切换/手动刷新），但仍用缓存。
  /// [bypassCache] = true 时连缓存也不用（网络切换后公网 IP 可能已变）。
  Future<NetworkSnapshot> refresh({
    bool force = false,
    bool bypassCache = false,
  }) async {
    final kinds = await currentConnectivity();
    final (localIp, iface) = await _localIPv4();

    String? publicIp;
    String? publicIpV6;
    String? region;
    String? directIp;
    String? gatewayV4;
    String? gatewayV6;
    String? error;

    if (_gatewayProvider != null) {
      final gateways = await _gatewayProvider();
      gatewayV4 = gateways['v4'];
      gatewayV6 = gateways['v6'];
    }

    if (kinds.any((k) => k != ConnectivityResult.none)) {
      final cached = bypassCache ? null : _usableCache();
      if (cached != null) {
        publicIp = cached.ip;
        region = cached.region;
      } else {
        final tooSoon = !force &&
            _lastAttempt != null &&
            DateTime.now().difference(_lastAttempt!) < _minInterval;
        if (tooSoon) {
          publicIp = _publicCache?.ip;
          region = _publicCache?.region;
          error = '公网信息刷新过于频繁，稍后自动重试';
        } else {
          _lastAttempt = DateTime.now();
          final info = await _fetchPublicInfo();
          if (info != null) {
            _publicCache = info;
            _publicAt = DateTime.now();
            publicIp = info.ip;
            region = info.region;
          } else {
            error = '公网信息获取失败（接口暂不可用）';
            // 失败时尽量展示上一次成功的值
            publicIp = _publicCache?.ip;
            region = _publicCache?.region;
          }
        }
      }
      // 直连出口：走物理网络探测，用来把「代理 IP」和「国内直连 IP」分开
      final directCached = !bypassCache &&
          _directIpCache != null &&
          _directIpAt != null &&
          DateTime.now().difference(_directIpAt!) < _cacheTtl;
      if (directCached) {
        directIp = _directIpCache;
      } else if (_directIpProvider != null) {
        final probed = await _directIpProvider();
        if (probed != null && probed.isNotEmpty) {
          _directIpCache = probed;
          _directIpAt = DateTime.now();
          directIp = probed;
        } else {
          directIp = _directIpCache;
        }
      }

      // 公网 IPv6：单独探测（只有链路真正支持 IPv6 时才有值）
      final v6Cached = !bypassCache &&
          _publicV6Cache != null &&
          _publicV6At != null &&
          DateTime.now().difference(_publicV6At!) < _cacheTtl;
      if (v6Cached) {
        publicIpV6 = _publicV6Cache;
      } else {
        final probed = await _fetchPublicIpv6();
        if (probed != null && probed.isNotEmpty) {
          _publicV6Cache = probed;
          _publicV6At = DateTime.now();
          publicIpV6 = probed;
        } else {
          publicIpV6 = _publicV6Cache;
        }
      }
    }

    return NetworkSnapshot(
      updatedAt: DateTime.now(),
      kinds: kinds,
      localIp: localIp,
      interfaceName: iface,
      publicIp: publicIp,
      publicIpV6: publicIpV6,
      region: region,
      directIp: directIp,
      gatewayV4: gatewayV4,
      gatewayV6: gatewayV6,
      error: error,
    );
  }

  /// 只用 IPv6 的网络端点（无 IPv6 连通性时会直接失败）
  Future<String?> _fetchPublicIpv6() async {
    final endpoints = <String>[
      'https://api6.ipify.org?format=json',
      'https://v6.ident.me/.json',
    ];
    for (final endpoint in endpoints) {
      try {
        final resp = await _client
            .get(Uri.parse(endpoint), headers: const {
              'Accept': 'application/json',
            })
            .timeout(const Duration(seconds: 5));
        if (resp.statusCode != 200) continue;
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final ip = data['ip'] as String?;
        if (ip != null && ip.isNotEmpty) return ip;
      } catch (_) {
        // 换下一个端点
      }
    }
    return null;
  }

  PublicIpInfo? _usableCache() {
    final cached = _publicCache;
    final at = _publicAt;
    if (cached == null || at == null) return null;
    if (DateTime.now().difference(at) > _cacheTtl) return null;
    return cached;
  }

  Future<PublicIpInfo?> _fetchPublicInfo() async {
    final providers = <Future<PublicIpInfo?> Function()>[
      _fromIpinfo,
      _fromCloudflareTrace,
      _fromIpify,
      _fromIpip,
    ];
    for (final provider in providers) {
      try {
        final info = await provider();
        if (info != null && info.ip.isNotEmpty) return info;
      } catch (_) {
        // 换下一个源
      }
    }
    return null;
  }

  Future<PublicIpInfo?> _fromIpinfo() async {
    final resp = await _client
        .get(
          Uri.parse('https://ipinfo.io/json'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 6));
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final ip = data['ip'] as String?;
    if (ip == null || ip.isEmpty) return null;
    final country = data['country'] as String?;
    final regionName = data['region'] as String?;
    final city = data['city'] as String?;
    final parts = <String>[
      if (country != null && country.isNotEmpty) country,
      if (regionName != null &&
          regionName.isNotEmpty &&
          regionName != city)
        regionName,
      if (city != null && city.isNotEmpty) city,
    ];
    return PublicIpInfo(
      ip: ip,
      region: parts.isEmpty ? null : parts.join(' · '),
    );
  }

  Future<PublicIpInfo?> _fromCloudflareTrace() async {
    final resp = await _client
        .get(Uri.parse('https://www.cloudflare.com/cdn-cgi/trace'))
        .timeout(const Duration(seconds: 6));
    if (resp.statusCode != 200) return null;
    final map = <String, String>{};
    for (final line in resp.body.split('\n')) {
      final idx = line.indexOf('=');
      if (idx <= 0) continue;
      map[line.substring(0, idx)] = line.substring(idx + 1).trim();
    }
    final ip = map['ip'];
    if (ip == null || ip.isEmpty) return null;
    return PublicIpInfo(ip: ip, region: map['loc']);
  }

  Future<PublicIpInfo?> _fromIpify() async {
    final resp = await _client
        .get(Uri.parse('https://api.ipify.org?format=json'))
        .timeout(const Duration(seconds: 6));
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final ip = data['ip'] as String?;
    if (ip == null || ip.isEmpty) return null;
    return PublicIpInfo(ip: ip);
  }

  /// 国内可达的兜底源，返回文本：
  /// `当前 IP：1.2.3.4  来自于：中国 广东 深圳  电信`
  Future<PublicIpInfo?> _fromIpip() async {
    final resp = await _client
        .get(
          Uri.parse('https://myip.ipip.net/'),
          headers: const {'Accept': 'text/plain'},
        )
        .timeout(const Duration(seconds: 6));
    if (resp.statusCode != 200) return null;
    final body = resp.body;
    final ipMatch =
        RegExp(r'IP[：: ]\s*([0-9a-fA-F.:]+)').firstMatch(body);
    final ip = ipMatch?.group(1);
    if (ip == null || ip.isEmpty) return null;
    final regionMatch = RegExp(r'来自于[：:]\s*(.+)').firstMatch(body);
    final region = regionMatch?.group(1)?.trim();
    return PublicIpInfo(
      ip: ip,
      region: (region == null || region.isEmpty) ? null : region,
    );
  }

  Future<(String?, String?)> _localIPv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      interfaces.sort((a, b) {
        int score(NetworkInterface i) {
          final n = i.name.toLowerCase();
          if (n.startsWith('wlan')) return 0;
          if (n.startsWith('rmnet') || n.startsWith('ap')) return 1;
          if (n.startsWith('eth')) return 2;
          return 3;
        }

        return score(a).compareTo(score(b));
      });
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return (addr.address, iface.name);
          }
        }
      }
    } catch (_) {
      // 忽略，返回空
    }
    return (null, null);
  }

  void dispose() => _client.close();
}

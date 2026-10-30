import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// 一次 traceroute 的跳数。
class TraceHop {
  const TraceHop({
    required this.ttl,
    this.address,
    this.rttMs,
    this.reached = false,
    this.error,
  });

  final int ttl;
  final String? address;
  final double? rttMs;
  final bool reached;

  /// 该跳的诊断信息（拿不到地址时用来判断原因）
  final String? error;
}

/// traceroute 结果。
class TracerouteResult {
  const TracerouteResult({this.hops = const <TraceHop>[], this.error});

  final List<TraceHop> hops;

  /// 整体失败原因（比如 IP_TTL 不被支持）
  final String? error;
}

/// Wi-Fi 连接信息。
class WifiInfo {
  const WifiInfo({
    this.bssid = '',
    this.linkSpeed = 0,
    this.standard = 0,
    this.channelWidth = 0,
    required this.ssid,
    required this.rssi,
    required this.level,
    required this.frequency,
  });

  final String ssid;
  final int rssi;

  /// 0~100
  final int level;
  final int frequency;

  final String bssid;

  /// Mbps
  final int linkSpeed;

  /// WifiManager 常量（0 未知，1.. 对应 802.11 标准）
  final int standard;

  /// 信道带宽（MHz）
  final int channelWidth;
}

/// 一张 SIM 卡的蜂窝信号。
class CellularInfo {
  const CellularInfo({
    required this.slot,
    required this.carrier,
    required this.level,
    required this.percent,
    this.dbm,
    this.rsrp,
    this.rsrq,
    this.sinr,
    this.nrRsrp,
    this.nrRsrq,
    this.nrSinr,
    this.networkType,
    this.roaming = false,
    this.mcc,
    this.mnc,
    this.operatorName = '',
    this.cellType,
    this.tac,
    this.pci,
    this.cellId,
    this.arfcn,
    this.band,
    this.neighbors = const <CellNeighbor>[],
  });

  /// 卡槽（1 起）
  final int slot;
  final String carrier;

  /// 0~4
  final int level;

  /// 0~100
  final int percent;
  final int? dbm;

  /// LTE 参考信号接收功率
  final int? rsrp;

  /// LTE 参考信号接收质量
  final int? rsrq;

  /// LTE 信噪比
  final int? sinr;

  /// 5G NR 的 SS-RSRP
  final int? nrRsrp;
  final int? nrRsrq;
  final int? nrSinr;
  final int? networkType;
  final bool roaming;

  // ---- 运营商 ----
  final String? mcc;
  final String? mnc;
  final String operatorName;

  // ---- 服务小区 ----
  /// NR / LTE
  final String? cellType;
  final int? tac;
  final int? pci;
  final int? cellId;
  final int? arfcn;
  final int? band;

  /// 邻小区
  final List<CellNeighbor> neighbors;

  /// 当前主用制式的 RSRP（优先 5G，其次 LTE）
  int? get primaryRsrp => nrRsrp ?? rsrp;

  /// 当前主用制式的 RSRQ
  int? get primaryRsrq => nrRsrq ?? rsrq;

  /// 当前主用制式的 SINR
  int? get primarySinr => nrSinr ?? sinr;

  String get cellTypeLabel => cellType ?? (nrRsrp != null ? 'NR' : 'LTE');
}

/// 最近一次已知位置。
class LocationInfo {
  const LocationInfo({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.altitude,
    required this.speed,
    required this.provider,
    required this.time,
  });

  final double lat;
  final double lng;

  /// 水平精度（米）
  final double accuracy;

  /// 海拔（米）
  final double altitude;

  /// 速度（米/秒）
  final double speed;

  /// gps / network / passive
  final String provider;
  final DateTime time;
}

/// 邻小区。
class CellNeighbor {
  const CellNeighbor({
    required this.type,
    this.pci,
    this.rsrp,
    this.rsrq,
    this.sinr,
    this.band,
  });

  final String type;
  final int? pci;
  final int? rsrp;
  final int? rsrq;
  final int? sinr;
  final int? band;
}

/// 扫描到的 Wi-Fi 热点。
class WifiScanResult {
  const WifiScanResult({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.level,
    required this.frequency,
    required this.capabilities,
    this.channelWidth = 0,
    this.standard = 0,
    this.centerFreq = 0,
  });

  final String ssid;
  final String bssid;
  final int rssi;

  /// 0~100
  final int level;
  final int frequency;
  final String capabilities;

  /// 信道带宽（MHz）
  final int channelWidth;

  /// wifiStandard 常量
  final int standard;

  /// 中心频率（用于宽信道判定）
  final int centerFreq;
}

/// 局域网内探测到的设备。
class LanDevice {
  const LanDevice({required this.ip, required this.mac});

  final String ip;

  /// 可能为空：Android 10+ 不保证能读到其他设备的 MAC
  final String mac;
}

/// 一次局域网扫描的结果。
class LanScanResult {
  const LanScanResult({this.selfIp, this.devices = const <LanDevice>[]});

  final String? selfIp;
  final List<LanDevice> devices;
}

/// 局域网扫描的流式事件。
sealed class LanScanEvent {
  const LanScanEvent();
}

class LanScanStarted extends LanScanEvent {
  const LanScanStarted({required this.selfIp, required this.subnet});

  final String selfIp;
  final String subnet;
}

class LanScanProgress extends LanScanEvent {
  const LanScanProgress({required this.scanned, required this.total});

  final int scanned;
  final int total;
}

class LanScanFound extends LanScanEvent {
  const LanScanFound(this.device);

  final LanDevice device;
}

class LanScanDone extends LanScanEvent {
  const LanScanDone({required this.count});

  final int count;
}

class LanScanFailed extends LanScanEvent {
  const LanScanFailed(this.message);

  final String message;
}

/// 设备累计流量（字节）。
class TrafficInfo {
  const TrafficInfo({required this.rx, required this.tx});

  final int rx;
  final int tx;

  int get total => rx + tx;
}

/// 单个应用的流量（近 24 小时）。
class AppTraffic {
  const AppTraffic({
    required this.packageName,
    required this.label,
    required this.uid,
    required this.rx,
    required this.tx,
    this.icon,
  });

  final String packageName;
  final String label;
  final int uid;
  final int rx;
  final int tx;
  final Uint8List? icon;

  int get total => rx + tx;
}

/// 系统级信息通道（Material You 取色、链路、信号、流量、权限）。
///
/// 不用 dynamic_color 插件：它的新版本依赖 material_ui 包，与 Flutter SDK
/// 的 ColorScheme 类型不兼容；旧版本的 androidx 依赖又跟当前 compileSdk 打架。
/// 自己取系统资源更稳，将来换 MD4 也只换这一层。
class SystemService {
  static const MethodChannel _channel = MethodChannel('qshell/system');

  /// Traceroute 流式事件通道（每跳一条）
  static const EventChannel _traceChannel =
      EventChannel('qshell/traceroute');

  /// 系统壁纸取色后的强调色；Android 12 以下返回 null。
  static Future<Color?> systemAccentColor() async {
    try {
      final value = await _channel.invokeMethod<int>('systemAccentColor');
      if (value == null) return null;
      return Color(value);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<int?> androidSdkInt() async {
    try {
      return await _channel.invokeMethod<int>('androidSdkInt');
    } catch (_) {
      return null;
    }
  }

  /// 走物理网络（Wi-Fi / 蜂窝）探测出口 IP，用于绕过 VPN/TUN 代理。
  static Future<String?> directPublicIp() async {
    try {
      return await _channel
          .invokeMethod<String>('directPublicIp')
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      return null;
    }
  }

  /// 默认网关 IP（IPv4 / IPv6 各一条，优先物理网络）。
  static Future<Map<String, String>> defaultGateways() async {
    try {
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('defaultGateways');
      if (raw == null) return const <String, String>{};
      return <String, String>{
        for (final entry in raw.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } catch (_) {
      return const <String, String>{};
    }
  }

  /// 当前 Wi-Fi 连接（未连接或没权限时返回 null）。
  static Future<WifiInfo?> wifiInfo() async {
    try {
      final raw =
          await _channel.invokeMethod<Map<Object?, Object?>>('wifiInfo');
      if (raw == null) return null;
      final rawSsid = ((raw['ssid'] as String?) ?? '').replaceAll('"', '');
      final ssid = rawSsid.contains('<unknown') || rawSsid == '0x'
          ? ''
          : rawSsid;
      return WifiInfo(
        ssid: ssid,
        rssi: (raw['rssi'] as int?) ?? -127,
        level: (raw['level'] as int?) ?? 0,
        frequency: (raw['frequency'] as int?) ?? 0,
        bssid: (raw['bssid'] as String?) ?? '',
        linkSpeed: (raw['linkSpeed'] as int?) ?? 0,
        standard: (raw['standard'] as int?) ?? 0,
        channelWidth: (raw['channelWidth'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// 各 SIM 卡的蜂窝信号（需要 READ_PHONE_STATE）。
  static Future<List<CellularInfo>> cellularInfo() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('cellularInfo');
      if (raw == null) return const <CellularInfo>[];
      return raw
          .whereType<Map<Object?, Object?>>()
          .map(
            (m) => CellularInfo(
              slot: (m['slot'] as int?) ?? 0,
              carrier: (m['carrier'] as String?) ?? '',
              level: (m['level'] as int?) ?? 0,
              percent: (m['percent'] as int?) ?? 0,
              dbm: m['dbm'] as int?,
              rsrp: m['rsrp'] as int?,
              rsrq: m['rsrq'] as int?,
              sinr: m['sinr'] as int?,
              nrRsrp: m['nrRsrp'] as int?,
              nrRsrq: m['nrRsrq'] as int?,
              nrSinr: m['nrSinr'] as int?,
              networkType: m['networkType'] as int?,
              roaming: (m['roaming'] as bool?) ?? false,
              mcc: m['mcc'] as String?,
              mnc: m['mnc'] as String?,
              operatorName: (m['operatorName'] as String?) ?? '',
              cellType: m['cellType'] as String?,
              tac: m['tac'] as int?,
              pci: m['pci'] as int?,
              cellId: m['cellId'] as int?,
              arfcn: m['arfcn'] as int?,
              band: m['band'] as int?,
              neighbors: (m['neighbors'] as List<Object?>? ?? const [])
                  .whereType<Map<Object?, Object?>>()
                  .map(
                    (n) => CellNeighbor(
                      type: (n['type'] as String?) ?? '',
                      pci: n['pci'] as int?,
                      rsrp: n['rsrp'] as int?,
                      rsrq: n['rsrq'] as int?,
                      sinr: n['sinr'] as int?,
                      band: n['band'] as int?,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList();
    } catch (_) {
      return const <CellularInfo>[];
    }
  }

  /// 周边 Wi-Fi 扫描（需要 NEARBY_WIFI_DEVICES / 位置权限；系统有频率限制）。
  static Future<List<WifiScanResult>> wifiScan() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('wifiScan');
      if (raw == null) return const <WifiScanResult>[];
      return raw
          .whereType<Map<Object?, Object?>>()
          .map(
            (m) => WifiScanResult(
              ssid: (m['ssid'] as String?) ?? '',
              bssid: (m['bssid'] as String?) ?? '',
              rssi: (m['rssi'] as int?) ?? -127,
              level: (m['level'] as int?) ?? 0,
              frequency: (m['frequency'] as int?) ?? 0,
              capabilities: (m['capabilities'] as String?) ?? '',
              channelWidth: (m['channelWidth'] as int?) ?? 0,
              standard: (m['standard'] as int?) ?? 0,
              centerFreq: (m['centerFreq'] as int?) ?? 0,
            ),
          )
          .toList();
    } catch (_) {
      return const <WifiScanResult>[];
    }
  }

  static Future<bool> hasWifiPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasWifiPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestWifiPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestWifiPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 流式扫描局域网：边扫边推，扫到一个显示一个。
  ///
  /// 用 TCP connect 探测（Dart 侧完成，不依赖原生）：
  /// 连上或被「拒绝连接」都说明主机在线（RST 也来自主机），
  /// 只有超时/不可达才算离线。这样不需要 raw socket，也不需要读 ARP 表
  /// （Android 10+ 普通 App 读 /proc/net/arp 会被拒绝）。
  static Stream<LanScanEvent> lanScanStream() {
    final controller = StreamController<LanScanEvent>();

    Future<void> run() async {
      try {
        final selfIp = await _localIpv4();
        if (selfIp == null) {
          controller.add(const LanScanFailed('没有可用的局域网 IPv4 地址'));
          await controller.close();
          return;
        }
        final parts = selfIp.split('.');
        if (parts.length != 4) {
          controller.add(LanScanFailed('IPv4 地址异常：$selfIp'));
          await controller.close();
          return;
        }
        final base = '${parts[0]}.${parts[1]}.${parts[2]}';
        controller.add(LanScanStarted(selfIp: selfIp, subnet: '$base.0/24'));

        final targets = <String>[
          selfIp,
          for (var i = 1; i <= 254; i++)
            if ('$base.$i' != selfIp) '$base.$i',
        ];

        var next = 0;
        var scanned = 0;
        var found = 0;
        final workers = List.generate(48, (_) async {
          while (true) {
            final index = next++;
            if (index >= targets.length) return;
            final ip = targets[index];
            final alive = ip == selfIp || await _probeHost(ip);
            if (alive) {
              found++;
              controller.add(LanScanFound(LanDevice(ip: ip, mac: '')));
            }
            scanned++;
            if (scanned % 8 == 0) {
              controller.add(LanScanProgress(scanned: scanned, total: targets.length));
            }
          }
        });

        await Future.wait(workers);
        controller.add(LanScanProgress(scanned: targets.length, total: targets.length));
        controller.add(LanScanDone(count: found));
        await controller.close();
      } catch (e) {
        controller.add(LanScanFailed('扫描失败：$e'));
        await controller.close();
      }
    }

    run();
    return controller.stream;
  }

  static Future<String?> _localIpv4() async {
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
          if (n.startsWith('eth')) return 1;
          if (n.startsWith('rmnet') || n.startsWith('ap')) return 2;
          return 3;
        }

        return score(a).compareTo(score(b));
      });
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {
      // 忽略
    }
    return null;
  }

  /// 常见端口探测：连通或被拒绝都算在线。
  static Future<bool> _probeHost(String ip) async {
    const ports = <int>[9, 80, 443, 22, 8080];
    for (final port in ports) {
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 300),
        );
        socket.destroy();
        return true;
      } on SocketException catch (e) {
        final code = e.osError?.errorCode;
        final msg = e.message.toLowerCase();
        if (code == 111 || msg.contains('refused') || msg.contains('reset')) {
          // 有响应 = 主机在线
          return true;
        }
        // 超时/网络不可达：换下一个端口再试
      } catch (_) {
        // 忽略
      }
    }
    return false;
  }

  /// 设备累计收发字节。
  static Future<TrafficInfo?> trafficInfo() async {
    try {
      final raw =
          await _channel.invokeMethod<Map<Object?, Object?>>('trafficInfo');
      if (raw == null) return null;
      return TrafficInfo(
        rx: (raw['rx'] as int?) ?? 0,
        tx: (raw['tx'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// 保存到系统「下载」目录（Android 10+），返回 content URI；失败返回 null。
  static Future<String?> saveToDownloads(String name, List<int> bytes) async {
    try {
      return await _channel.invokeMethod<String>('saveToDownloads', {
        'name': name,
        'bytes': Uint8List.fromList(bytes),
      });
    } catch (_) {
      return null;
    }
  }

  /// 启动/更新终端保活前台服务；[names] 是当前已连接的终端名称。
  static Future<void> startKeepAlive([List<String> names = const []]) async {
    try {
      await _channel.invokeMethod<void>('startKeepAlive', {'names': names});
    } catch (_) {
      // 忽略：部分 ROM 不允许前台服务，不影响主流程
    }
  }

  /// 停止终端保活服务。
  static Future<void> stopKeepAlive() async {
    try {
      await _channel.invokeMethod<void>('stopKeepAlive');
    } catch (_) {}
  }

  /// 流式 traceroute：每测完一跳就产出一条事件。
  static Stream<TraceHop> tracerouteStream(
    String host, {
    int maxHops = 16,
  }) {
    return _traceChannel
        .receiveBroadcastStream(<String, Object>{
          'host': host,
          'maxHops': maxHops,
        })
        .map((event) {
          final map = (event as Map).cast<Object?, Object?>();
          return TraceHop(
            ttl: (map['ttl'] as int?) ?? 0,
            address: map['address'] as String?,
            rttMs: (map['rtt'] as num?)?.toDouble(),
            reached: (map['reached'] as bool?) ?? false,
            error: map['error'] as String?,
          );
        });
  }

  /// 是否已授予位置权限。
  static Future<bool> hasLocationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasLocationPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestLocationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestLocationPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 最近一次已知位置；没权限或没记录返回 null。
  static Future<LocationInfo?> locationInfo() async {
    try {
      final raw =
          await _channel.invokeMethod<Map<Object?, Object?>>('locationInfo');
      if (raw == null) return null;
      return LocationInfo(
        lat: (raw['lat'] as num?)?.toDouble() ?? 0,
        lng: (raw['lng'] as num?)?.toDouble() ?? 0,
        accuracy: (raw['accuracy'] as num?)?.toDouble() ?? 0,
        altitude: (raw['altitude'] as num?)?.toDouble() ?? 0,
        speed: (raw['speed'] as num?)?.toDouble() ?? 0,
        provider: (raw['provider'] as String?) ?? '',
        time: DateTime.fromMillisecondsSinceEpoch(
          (raw['time'] as int?) ?? 0,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// 是否已授予「使用情况访问」权限（per-app 流量统计需要）。
  static Future<bool> hasUsageAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 跳到系统设置里的「使用情况访问」页面。
  static Future<void> openUsageAccess() async {
    try {
      await _channel.invokeMethod<void>('openUsageAccess');
    } catch (_) {
      // 忽略：部分 ROM 没有这个设置页
    }
  }

  /// 近 24 小时每个应用的流量（含后台），按总量降序。
  static Future<List<AppTraffic>> appTraffic() async {
    try {
      final raw = await _channel
          .invokeMethod<List<Object?>>('appTraffic')
          .timeout(const Duration(seconds: 15));
      if (raw == null) return const <AppTraffic>[];
      return raw
          .whereType<Map<Object?, Object?>>()
          .map((item) => AppTraffic(
                packageName: (item['package'] as String?) ?? '',
                label: (item['label'] as String?) ?? '',
                uid: (item['uid'] as int?) ?? 0,
                rx: (item['rx'] as int?) ?? 0,
                tx: (item['tx'] as int?) ?? 0,
                icon: item['icon'] as Uint8List?,
              ))
          .toList();
    } catch (_) {
      return const <AppTraffic>[];
    }
  }

  /// 反向 DNS（PTR）解析设备名；拿不到返回 null。
  static Future<String?> resolveHostname(String ip) async {
    try {
      return await _channel
          .invokeMethod<String>('resolveHostname', {'ip': ip})
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  /// 真 ICMP ping（非特权 ping socket）。不可用时返回 null，调用方降级到 TCP。
  static Future<List<double>?> icmpPing(String host, {int count = 4}) async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'icmpPing',
        {'host': host, 'count': count},
      );
      final list = raw?['rtts'];
      if (list is List) {
        return list.map((e) => (e as num?)?.toDouble() ?? -1.0).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 真 traceroute（TTL 递增），返回跳数列表与错误信息。
  static Future<TracerouteResult> traceroute(
    String host, {
    int maxHops = 16,
  }) async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'traceroute',
        {'host': host, 'maxHops': maxHops},
      );
      if (raw == null) return const TracerouteResult(error: '没有返回数据');
      final hopsRaw = raw['hops'];
      final hops = <TraceHop>[];
      if (hopsRaw is List) {
        for (final item in hopsRaw) {
          if (item is! Map) continue;
          hops.add(
            TraceHop(
              ttl: (item['ttl'] as int?) ?? 0,
              address: item['address'] as String?,
              rttMs: (item['rtt'] as num?)?.toDouble(),
              reached: (item['reached'] as bool?) ?? false,
              error: item['error'] as String?,
            ),
          );
        }
      }
      return TracerouteResult(
        hops: hops,
        error: raw['error'] as String?,
      );
    } on PlatformException catch (e) {
      return TracerouteResult(error: e.message ?? e.code);
    } catch (e) {
      return TracerouteResult(error: e.toString());
    }
  }

  /// iperf3 可执行文件路径（null 表示这台设备/ABI 没带进来）。
  static Future<String?> iperfPath() async {
    try {
      return await _channel.invokeMethod<String>('iperfPath');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasPhonePermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPhonePermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestPhonePermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPhonePermission') ??
          false;
    } catch (_) {
      return false;
    }
  }
}

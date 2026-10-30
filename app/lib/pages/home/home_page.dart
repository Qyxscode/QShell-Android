import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../services/network_info_service.dart';
import '../../i18n/app_strings.dart';
import '../../services/system_service.dart';
import '../../shell/app_shell.dart';
import '../../widgets/settings_action.dart';
import 'cellular_detail_page.dart';
import 'wifi_scan_page.dart';
import 'node_detail_page.dart';
import 'traffic_detail_page.dart';
import 'widgets/metric_card.dart';
import 'widgets/topology_card.dart';

/// 主页：网络状态总览。
///
/// 已接：链路类型、本机 IP、网关 v4/v6、公网 v4/v6、直连出口、
/// Wi-Fi 信号、蜂窝信号（双卡）、设备流量；每秒采样一次。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final NetworkInfoService _service = NetworkInfoService(
    directIpProvider: SystemService.directPublicIp,
    gatewayProvider: SystemService.defaultGateways,
  );

  NetworkSnapshot? _snapshot;
  bool _loading = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _ticker;
  int _ticks = 0;

  WifiInfo? _wifi;
  List<CellularInfo> _cells = const <CellularInfo>[];
  TrafficInfo? _traffic;
  int? _lastTrafficTotal;
  bool _permissionsRequested = false;

  // 每秒一个点，保留 10 分钟
  static const int _seriesLength = 600;
  final List<double> _wifiSeries = <double>[];
  final List<double> _cellSeries = <double>[];
  final List<double> _trafficSeries = <double>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _ensurePermissions();
    // 网络切换时公网 IP 会变，直接绕过缓存重新探测
    _sub = _service.onConnectivityChanged
        .listen((_) => _load(force: true, bypassCache: true));
    _sampleSignal();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _sampleSignal());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ticker ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => _sampleSignal(),
      );
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _ticker?.cancel();
    _resumeTimer?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    _resumeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    super.dispose();
  }

  Future<void> _ensurePermissions() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;
    // 电话权限：蜂窝信号；Wi-Fi 权限（附近设备/位置）：SSID 与周边扫描
    await SystemService.requestPhonePermission();
    await SystemService.requestWifiPermission();
    if (mounted) _sampleSignal();
  }

  /// 每秒采样：WiFi / 流量并行取，蜂窝 3 秒一次（allCellInfo 较重）
  /// 每秒采样。WiFi / 流量各自到齐就刷新，蜂窝单独异步补，
  /// 避免 allCellInfo（慢）把另外两条曲线也拖住。
  int _cellTick = 0;
  bool _pageActive = true;
  Timer? _resumeTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 切到别的 tab 时暂停采样：PageView 保活会保留本页，
    // 每秒 setState 会让滑动帧率变差。
    final index = ActivePage.of(context);
    final active = index == null || index == 0;
    if (active == _pageActive) return;
    _pageActive = active;
    _resumeTimer?.cancel();
    if (active) {
      // 等切换动画结束再恢复采样，避免和滑动动画抢帧
      _resumeTimer = Timer(const Duration(milliseconds: 360), () {
        if (!mounted || !_pageActive) return;
        _ticker ??= Timer.periodic(
          const Duration(seconds: 1),
          (_) => _sampleSignal(),
        );
        _sampleSignal();
      });
    } else {
      _ticker?.cancel();
    _resumeTimer?.cancel();
      _ticker = null;
    }
  }


  void _sampleSignal() {
    final sampleCells = _cellTick < 3 || _cellTick % 3 == 0;
    _cellTick++;
    _sampleFast();
    if (sampleCells) _sampleCells();
  }

  Future<void> _sampleFast() async {
    final wifiFuture = SystemService.wifiInfo();
    final trafficFuture = SystemService.trafficInfo();
    final wifi = await wifiFuture;
    final traffic = await trafficFuture;
    if (!mounted) return;
    setState(() {
      _wifi = wifi;
      _push(_wifiSeries, (wifi?.level ?? 0).toDouble());
      if (traffic != null) {
        _traffic = traffic;
        final total = traffic.total;
        final delta =
            _lastTrafficTotal == null ? 0.0 : (total - _lastTrafficTotal!);
        _lastTrafficTotal = total;
        _push(_trafficSeries, delta < 0 ? 0 : delta.toDouble());
      }
      _ticks++;
    });
  }

  Future<void> _sampleCells() async {
    final cells = await SystemService.cellularInfo();
    if (!mounted) return;
    setState(() {
      _cells = cells;
      _push(
        _cellSeries,
        cells.isEmpty ? 0 : cells.first.percent.toDouble(),
      );
    });
  }
  void _push(List<double> series, double value) {
    series.add(value);
    if (series.length > _seriesLength) series.removeAt(0);
  }

  Future<void> _load({bool force = false, bool bypassCache = false}) async {
    if (mounted) setState(() => _loading = true);
    final snapshot = await _service.refresh(
      force: force,
      bypassCache: bypassCache,
    );
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  void _openNode(String node, AppStrings strings) {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    switch (node) {
      case 'local':
        _pushNode(
          NodeDetailPage(
            kind: 'local',
            title: strings.homeLocal,
            ip: snapshot.localIp,
            facts: <(String, String)>[
              (strings.homeNetworkType, snapshot.interfaceLabel ?? strings.commonUnknown),
              (strings.homePublicIpv4, snapshot.publicIp ?? strings.commonNotObtained),
              (strings.homePublicIpv6, snapshot.publicIpV6 ?? strings.commonNone),
            ],
          ),
        );
      case 'gateway':
        _pushNode(
          NodeDetailPage(
            kind: 'gateway',
            title: strings.homeUpstream,
            ip: snapshot.gatewayV4 ?? snapshot.gatewayV6,
            facts: <(String, String)>[
              (strings.homeGatewayIpv4, snapshot.gatewayV4 ?? strings.commonNotObtained),
              (strings.homeGatewayIpv6, snapshot.gatewayV6 ?? strings.commonNone),
              (strings.homeLocalIp, snapshot.localIp ?? strings.commonNotObtained),
            ],
          ),
        );
      case 'direct':
        _pushNode(
          NodeDetailPage(
            kind: 'direct',
            title: strings.homeDirectExit,
            ip: snapshot.directIp,
            facts: <(String, String)>[
              (strings.homeExplanation, strings.homeExplanationDesc),
            ],
          ),
        );
      case 'public':
        _pushNode(
          NodeDetailPage(
            kind: 'public',
            title: snapshot.viaProxy ? strings.homeProxyExit : strings.homePublic,
            ip: snapshot.publicIp ?? snapshot.publicIpV6,
            facts: <(String, String)>[
              (strings.homeRegion, snapshot.region ?? strings.commonUnknown),
              (strings.homeDirectExit, snapshot.directIp ?? strings.commonNotProbed),
            ],
          ),
        );
    }
  }

  void _pushNode(NodeDetailPage page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final strings = AppStrings.of(context);
    final snapshot = _snapshot;

    final wifi = _wifi;
    final cells = _cells;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('QShell'),
            Text(
              snapshot == null
                  ? strings.homeNetworkStatus
                  : '${snapshot.kindLabel} · ${_fmtTime(snapshot.updatedAt)} 更新',
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).commonRefresh,
            onPressed: _loading ? null : () => _load(force: true),
            icon: _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.accent,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SettingsAction(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            TopologyCard(
              snapshot: snapshot ?? _emptySnapshot(),
              onTapNode: (node) => _openNode(node, strings),
            ),
            const SizedBox(height: 12),
            // 两张卡等高
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: MetricCard(
                      icon: Icons.signal_cellular_alt_rounded,
                      title: strings.homeCell,
                      accent: tokens.highlight,
                      value: _cellPercent(),
                      unit: cells.isEmpty ? null : '%',
                      caption: _cellCaption(strings),
                      series: _cellSeries,
                      // 蜂窝有 0~100 上限：用水位表达绝对占比，比折线直观
                      progress: cells.isEmpty ? 0.0 : cells.first.percent / 100,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CellularDetailPage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      icon: Icons.wifi_rounded,
                      title: strings.homeWifi,
                      accent: tokens.accent,
                      value: wifi == null ? '--' : '${wifi.level}',
                      unit: wifi == null ? null : '%',
                      caption: wifi == null
                          ? strings.homeNotConnectedWifi
                          : (wifi.ssid.isEmpty ? strings.homeSsidPermission : wifi.ssid),
                      series: _wifiSeries,
                      progress: (wifi?.level ?? 0) / 100,
                      onTap: () async {
                        // 没权限时点击先去授权，避免进去还是看不到设备
                        final granted = await SystemService.hasWifiPermission();
                        if (!granted) {
                          await SystemService.requestWifiPermission();
                          _sampleSignal();
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const WifiScanPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MetricCard(
              icon: Icons.swap_vert_rounded,
              title: strings.homeTraffic,
              accent: tokens.success,
              value: _trafficValue(),
              unit: _trafficUnit(),
              caption: _trafficCaption(),
              series: _trafficSeries,
              // 流量用速度做水位：256 KB/s 约半满，更快时接近满格
              progress: _trafficProgress(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TrafficDetailPage(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Footer(tokens: tokens, text: text, ticks: _ticks),
          ],
        ),
      ),
    );
  }

  NetworkSnapshot _emptySnapshot() => NetworkSnapshot(
        updatedAt: DateTime.now(),
        kinds: const <ConnectivityResult>[],
      );

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  String? _cellPercent() {
    if (_cells.isEmpty) return null;
    return '${_cells.first.percent}';
  }

  String _cellCaption(AppStrings strings) {
    if (_cells.isEmpty) return strings.homeWaitPermission;
    return _cells
        .map((c) => '${strings.cellSlotTemplate.replaceAll('{n}', '${c.slot}')} ${c.carrier} ${c.percent}%')
        .join(' · ');
  }

  String? _trafficValue() {
    final traffic = _traffic;
    if (traffic == null) return null;
    final (value, _) = _fmtBytes(traffic.total);
    return value;
  }

  String? _trafficUnit() {
    final traffic = _traffic;
    if (traffic == null) return null;
    final (_, unit) = _fmtBytes(traffic.total);
    return unit;
  }

  String? _trafficCaption() {
    final traffic = _traffic;
    if (traffic == null) return null;
    final (rx, rxUnit) = _fmtBytes(traffic.rx);
    final (tx, txUnit) = _fmtBytes(traffic.tx);
    return '↓ $rx$rxUnit · ↑ $tx$txUnit';
  }

  /// 流量水位：速度 / (速度 + 256KB)，512KB/s 约 2/3 满
  double _trafficProgress() {
    if (_trafficSeries.isEmpty) return 0;
    final speed = _trafficSeries.last;
    if (speed <= 0) return 0;
    return speed / (speed + 262144);
  }

  (String, String) _fmtBytes(int bytes) {
    if (bytes >= 1073741824) {
      return ((bytes / 1073741824).toStringAsFixed(2), 'GB');
    }
    if (bytes >= 1048576) {
      return ((bytes / 1048576).toStringAsFixed(1), 'MB');
    }
    if (bytes >= 1024) {
      return ((bytes / 1024).toStringAsFixed(0), 'KB');
    }
    return (bytes.toString(), 'B');
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.tokens, required this.text, required this.ticks});

  final AppTokens tokens;
  final TextTheme text;
  final int ticks;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: tokens.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          AppStrings.of(context).homeSamplingTemplate.replaceAll('{n}', '$ticks'),
          style: text.bodySmall?.copyWith(color: tokens.textSecondary),
        ),
      ],
    );
  }
}

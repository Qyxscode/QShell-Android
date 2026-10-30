import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/system_service.dart';
import '../../services/tools/device_identify.dart';
import '../../services/tools/mdns_scanner.dart';
import '../../widgets/settings_action.dart';

/// 当前 Wi-Fi / 局域网下探测到的设备（流式：扫到一个显示一个）。
class LanScanPage extends StatefulWidget {
  const LanScanPage({super.key});

  @override
  State<LanScanPage> createState() => _LanScanPageState();
}

class _LanScanPageState extends State<LanScanPage> {
  /// 自动扫描冷却：进页面 30 秒内不自动扫，避免反复进出把网络刷爆；
  /// 想立刻扫就点右上角刷新（不受冷却限制）。
  static const Duration _cooldown = Duration(seconds: 30);
  static const String _kLastScanKey = 'lan.last_scan_at';

  final List<LanDevice> _devices = <LanDevice>[];
  final Map<String, String> _names = <String, String>{};
  final Map<String, DeviceIdentity> _identities = <String, DeviceIdentity>{};
  StreamSubscription<LanScanEvent>? _sub;
  Timer? _cooldownTimer;
  DateTime? _cooldownUntil;
  String? _selfIp;
  String? _subnet;
  int _scanned = 0;
  int _total = 254;
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWithCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _initWithCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastScanKey);
    if (last != null) {
      final next = DateTime.fromMillisecondsSinceEpoch(last).add(_cooldown);
      if (DateTime.now().isBefore(next)) {
        setState(() => _cooldownUntil = next);
        _startCooldownTimer();
        return;
      }
    }
    _start();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final until = _cooldownUntil;
      if (until == null || DateTime.now().isAfter(until)) {
        timer.cancel();
        setState(() => _cooldownUntil = null);
        // 冷却结束自动开扫，不用用户再点一次
        _start();
      } else {
        setState(() {});
      }
    });
  }

  int get _cooldownRemaining {
    final until = _cooldownUntil;
    if (until == null) return 0;
    final diff = until.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  Future<void> _start() async {
    _cooldownTimer?.cancel();
    _sub?.cancel();
    setState(() {
      _devices.clear();
      _names.clear();
      _identities.clear();
      _scanning = true;
      _error = null;
      _scanned = 0;
      _total = 254;
      _cooldownUntil = null;
    });

    _sub = SystemService.lanScanStream().listen(
      (event) {
        if (!mounted) return;
        setState(() {
          switch (event) {
            case LanScanStarted(:final selfIp, :final subnet):
              _selfIp = selfIp;
              _subnet = subnet;
            case LanScanProgress(:final scanned, :final total):
              _scanned = scanned;
              _total = total;
            case LanScanFound(:final device):
              if (!_devices.any((d) => d.ip == device.ip)) {
                _devices.add(device);
                _sortDevices();
                // 设备名异步解析，先显示 IP
                _resolveName(device.ip);
                // 端口指纹识别设备类型
                _identify(device.ip);
              }
            case LanScanDone():
              _scanning = false;
              // mDNS 补一手：电视/音箱/打印机这类设备靠端口认不出来
              _scanBonjour();
              // 扫描期间没识别出来的，结束后补一轮（分批，避免并发过高）
              _identifyMissing();
              // 只有「完整扫完」才进入冷却：
              // 扫到一半退出页面不记录，下次进来可以直接重扫，避免误操作被卡 30 秒。
              _markScanCompleted();
            case LanScanFailed(:final message):
              _error = message;
              _scanning = false;
          }
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = AppStrings.of(context).lanScanErrorTemplate.replaceAll('{msg}', '$error');
          _scanning = false;
        });
      },
    );
  }

  Future<void> _markScanCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastScanKey, DateTime.now().millisecondsSinceEpoch);
  }

  void _sortDevices() {
    _devices.sort((a, b) {
      final pa = int.tryParse(a.ip.split('.').last) ?? 0;
      final pb = int.tryParse(b.ip.split('.').last) ?? 0;
      return pa.compareTo(pb);
    });
  }

  Future<void> _resolveName(String ip) async {
    final name = await SystemService.resolveHostname(ip);
    if (!mounted || name == null || name.isEmpty) return;
    setState(() => _names[ip] = name);
  }

  /// 端口指纹识别设备类型（异步，不阻塞扫描）

  Future<void> _identify(String ip) async {
    try {
      final identity = await DeviceIdentifier.identify(
        ip,
        hostname: _names[ip],
      );
      if (!mounted) return;
      setState(() {
        _identities[ip] = identity;
      });
    } catch (_) {
      // 忽略识别失败
    }
  }

  /// mDNS / Bonjour 扫描：识别电视、音箱、打印机这类不开放端口的设备。
  /// 扫描结束后补识别：只处理还没结果的设备，分批跑避免并发过高
  Future<void> _identifyMissing() async {
    final missing = _devices
        .where((device) => !_identities.containsKey(device.ip))
        .toList();
    for (var i = 0; i < missing.length; i += 5) {
      final batch = missing.skip(i).take(5).toList();
      await Future.wait(batch.map((device) => _identify(device.ip)));
    }
  }

  Future<void> _scanBonjour() async {
    try {
      final results = await MdnsScanner.scan();
      if (!mounted || results.isEmpty) return;
      setState(() {
        for (final result in results) {
          final existing = _identities[result.ip];
          // 端口指纹已经认出具体类型的就保留，只在「未知设备」时用 Bonjour 结果
          if (existing != null && existing.kind != AppStrings.of(context).lanUnknownDevice) continue;
          _identities[result.ip] = DeviceIdentity(
            kind: result.kind,
            openPorts: existing?.openPorts ?? const <int>[],
          );
          if (_names[result.ip] == null && result.services.isNotEmpty) {
            _names[result.ip] = result.services.first;
          }
        }
      });
    } catch (_) {
      // 忽略
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).lanTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).lanRescan,
            onPressed: _scanning ? null : _start,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SettingsAction(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Icon(Icons.lan_rounded, size: 16, color: tokens.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _selfIp == null
                      ? AppStrings.of(context).lanScanningSubnet
                      : AppStrings.of(context).lanSelfTemplate.replaceAll('{ip}', '$_selfIp').replaceAll('{subnet}', _subnet ?? "/24"),
                  style: text.bodySmall?.copyWith(color: tokens.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_cooldownUntil != null && !_scanning) ...[
            _CooldownBox(
              remaining: _cooldownRemaining,
              onScanNow: _start,
              tokens: tokens,
              text: text,
            ),
            const SizedBox(height: 12),
          ] else if (_scanning) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: _total == 0 ? null : _scanned / _total,
                minHeight: 4,
                backgroundColor: tokens.track,
                color: tokens.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.of(context).lanProgressTemplate.replaceAll('{a}', '$_scanned').replaceAll('{b}', '$_total').replaceAll('{n}', '${_devices.length}'),
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: 12),
          ] else if (_error != null) ...[
            _ErrorBox(message: _error!, tokens: tokens, text: text),
            const SizedBox(height: 12),
          ] else if (_devices.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.devices_other_rounded,
                      size: 40, color: tokens.textDisabled),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.of(context).lanEmpty,
                    style:
                        text.bodyMedium?.copyWith(color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.of(context).lanEmptyDesc,
                    style: text.bodySmall?.copyWith(color: tokens.textDisabled),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              AppStrings.of(context).lanCountTemplate.replaceAll('{n}', '${_devices.length}'),
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: 10),
          ],
          for (final device in _devices) ...[
            _DeviceRow(
              device: device,
              name: _names[device.ip],
              identity: _identities[device.ip],
              isSelf: device.ip == _selfIp,
              tokens: tokens,
              text: text,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _CooldownBox extends StatelessWidget {
  const _CooldownBox({
    required this.remaining,
    required this.onScanNow,
    required this.tokens,
    required this.text,
  });

  final int remaining;
  final VoidCallback onScanNow;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.outlineSoft),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 18, color: tokens.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.of(context).lanCooldownTemplate.replaceAll('{n}', '$remaining'),
                  style: text.bodyMedium?.copyWith(color: tokens.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.of(context).lanCooldownDesc,
                  style: text.bodySmall?.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onScanNow,
            child: Text(AppStrings.of(context).lanScanNow),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({
    required this.message,
    required this.tokens,
    required this.text,
  });

  final String message;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.outlineSoft),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: tokens.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: text.bodySmall?.copyWith(color: tokens.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.isSelf,
    required this.tokens,
    required this.text,
    this.name,
    this.identity,
  });

  final LanDevice device;
  final String? name;
  final DeviceIdentity? identity;
  final bool isSelf;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final hasName = name != null && name!.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isSelf ? tokens.accentSoft : tokens.surfaceCardAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSelf ? Icons.smartphone_rounded : Icons.devices_rounded,
                size: 18,
                color: isSelf ? tokens.onAccentSoft : tokens.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          hasName ? name! : device.ip,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: tokens.accentSoft,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            AppStrings.of(context).homeLocal,
                            style: text.labelSmall?.copyWith(
                              color: tokens.onAccentSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasName) ...[
                    const SizedBox(height: 2),
                    Text(
                      device.ip,
                      style:
                          text.bodySmall?.copyWith(color: tokens.textSecondary),
                    ),
                  ],
                  if (identity != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: tokens.accentSoft,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            _deviceLabel(AppStrings.of(context), identity!.kind),
                            style: text.labelSmall?.copyWith(
                              color: tokens.onAccentSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (identity!.openPorts.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              identity!.portsLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall?.copyWith(
                                color: tokens.textDisabled,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.check_circle_rounded, size: 16, color: tokens.success),
          ],
        ),
      ),
    );
  }
}

String _deviceLabel(AppStrings strings, String kind) => switch (kind) {
        'iphone' => strings.deviceIphone,
        'windows_rdp' => strings.deviceWindowsRdp,
        'windows' => strings.deviceWindows,
        'printer' => strings.devicePrinter,
        'nas' => strings.deviceNas,
        'camera' => strings.deviceCamera,
        'router' => strings.deviceRouter,
        'android' => strings.deviceAndroid,
        'linux' => strings.deviceLinux,
        'web' => strings.deviceWeb,
        'airplay' => strings.deviceAirplay,
        'apple' => strings.deviceApple,
        'cast' => strings.deviceCast,
        'mijia' => strings.deviceMijia,
        'homekit' => strings.deviceHomekit,
        'speaker' => strings.deviceSpeaker,
        'workstation' => strings.deviceWorkstation,
        'bonjour' => strings.deviceBonjour,
        _ => strings.deviceUnknown,
      };

import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../widgets/tool_layout.dart';
import '../../services/tools/upnp_scan.dart';

/// UPnP 扫描：SSDP 多播发现网关 / NAS / 媒体服务器等。
class UpnpScanPage extends StatefulWidget {
  const UpnpScanPage({super.key});

  @override
  State<UpnpScanPage> createState() => _UpnpScanPageState();
}

class _UpnpScanPageState extends State<UpnpScanPage> {
  final List<SsdpDevice> _devices = <SsdpDevice>[];
  StreamSubscription<SsdpDevice>? _sub;
  bool _scanning = false;
  String? _error;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _scan() {
    _sub?.cancel();
    setState(() {
      _devices.clear();
      _scanning = true;
      _error = null;
    });
    _sub = ssdpDiscover().listen(
      (device) {
        if (!mounted) return;
        setState(() => _devices.add(device));
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _scanning = false;
          _error = '扫描出错：$e';
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _scanning = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPnP 扫描'),
        actions: [
          IconButton(
            tooltip: '重新扫描',
            onPressed: _scanning ? null : _scan,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ToolPrimaryButton(
            onPressed: _scanning ? null : _scan,
            label: AppStrings.of(context).commonStartScan,
            icon: Icons.cast_connected_rounded,
            loading: _scanning,
            loadingLabel: '发现中…',
          ),
          if (_scanning) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: tokens.track,
                color: tokens.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '已发现 ${_devices.length} 个服务…',
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            ToolNotice(message: _error!, error: true),
          ],
          if (!_scanning && _devices.isEmpty) ...[
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Icon(Icons.cast_rounded, size: 40, color: tokens.textDisabled),
                  const SizedBox(height: 12),
                  Text(
                    '没有发现设备',
                    style: text.bodyMedium
                        ?.copyWith(color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '可能是路由器关闭了 UPnP，或当前网络不支持多播',
                    style: text.bodySmall?.copyWith(color: tokens.textDisabled),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          if (_devices.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '共 ${_devices.length} 个服务',
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: 8),
            for (final device in _devices)
              _DeviceCard(device: device, tokens: tokens, text: text),
          ],
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.tokens,
    required this.text,
  });

  final SsdpDevice device;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.router_rounded, size: 18, color: tokens.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    device.kind,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  device.ip,
                  style:
                      text.bodySmall?.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
            if (device.location.isNotEmpty) ...[
              const SizedBox(height: 6),
              SelectableText(
                device.location,
                maxLines: 2,
                style: text.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            if (device.server.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                device.server,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(color: tokens.textDisabled),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
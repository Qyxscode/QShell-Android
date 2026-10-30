import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/system_service.dart';
import '../tools/ping_page.dart';
import '../tools/port_scan_page.dart';
import '../tools/upnp_page.dart';
import '../tools/whois_page.dart';

/// 链路拓扑节点下钻页：显示该节点的信息和可用的诊断工具。
class NodeDetailPage extends StatefulWidget {
  const NodeDetailPage({
    super.key,
    required this.kind,
    required this.title,
    this.ip,
    this.facts = const <(String, String)>[],
  });

  /// local / gateway / direct / public
  final String kind;
  final String title;
  final String? ip;

  /// 附加信息（标签, 值）
  final List<(String, String)> facts;

  @override
  State<NodeDetailPage> createState() => _NodeDetailPageState();
}

class _NodeDetailPageState extends State<NodeDetailPage> {
  String? _ptr;
  bool _loadingPtr = false;

  @override
  void initState() {
    super.initState();
    _loadPtr();
  }

  Future<void> _loadPtr() async {
    final ip = widget.ip;
    if (ip == null || ip.isEmpty) return;
    setState(() => _loadingPtr = true);
    final name = await SystemService.resolveHostname(ip);
    if (!mounted) return;
    setState(() {
      _ptr = name;
      _loadingPtr = false;
    });
  }

  void _copyIp() {
    final ip = widget.ip;
    if (ip == null || ip.isEmpty) return;
    Clipboard.setData(ClipboardData(text: ip));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(AppStrings.of(context).nodeCopiedTemplate.replaceAll('{ip}', ip))));
  }

  bool get _isGateway => widget.kind == 'gateway';

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final ip = widget.ip;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  Icon(
                    switch (widget.kind) {
                      'local' => Icons.smartphone_rounded,
                      'gateway' => Icons.router_rounded,
                      'direct' => Icons.alt_route_rounded,
                      _ => Icons.public_rounded,
                    },
                    color: tokens.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ip ?? AppStrings.of(context).commonNotObtained,
                          style: text.headlineSmall?.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.title,
                          style: text.bodySmall
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (ip != null && ip.isNotEmpty)
                    IconButton(
                      tooltip: AppStrings.of(context).commonCopy,
                      onPressed: _copyIp,
                      icon: Icon(Icons.copy_rounded,
                          size: 20, color: tokens.textSecondary),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.dns_outlined, color: tokens.accent),
                  title: Text(AppStrings.of(context).nodeReverseDns),
                  subtitle: Text(
                    _loadingPtr
                        ? AppStrings.of(context).commonQuerying
                        : (_ptr ?? AppStrings.of(context).nodePtrEmpty),
                    style: text.bodySmall
                        ?.copyWith(color: tokens.textSecondary),
                  ),
                ),
                for (final (label, value) in widget.facts)
                  if (value.trim().isNotEmpty) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading:
                          Icon(Icons.info_outline, color: tokens.accent),
                      title: Text(label),
                      subtitle: Text(
                        value,
                        style: text.bodySmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppStrings.of(context).nodeTools,
            style: text.titleSmall?.copyWith(
              color: tokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.network_ping_rounded, color: tokens.accent),
                  title: const Text('Ping'),
                  subtitle: Text(AppStrings.of(context).nodePingDesc),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: tokens.textDisabled),
                  onTap: ip == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PingPage(initialHost: ip),
                            ),
                          ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      Icon(Icons.travel_explore_rounded, color: tokens.accent),
                  title: const Text('端口扫描'),
                  subtitle: Text(AppStrings.of(context).nodePortScanDesc),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: tokens.textDisabled),
                  onTap: ip == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PortScanPage(initialHost: ip),
                            ),
                          ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.badge_outlined, color: tokens.accent),
                  title: const Text('Whois'),
                  subtitle: Text(AppStrings.of(context).nodeWhoisDesc),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: tokens.textDisabled),
                  onTap: ip == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => WhoisPage(initialHost: ip),
                            ),
                          ),
                ),
                if (_isGateway) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading:
                        Icon(Icons.cast_connected_rounded, color: tokens.accent),
                    title: const Text('UPnP 扫描'),
                    subtitle: Text(AppStrings.of(context).nodeUpnpDesc),
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: tokens.textDisabled),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const UpnpScanPage(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

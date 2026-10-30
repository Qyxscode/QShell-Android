import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/system_service.dart';
import '../../services/tools/ip_geo.dart';
import '../../widgets/tool_layout.dart';

/// Traceroute：用 ICMP + TTL 递增，逐跳拿地址。
class TraceroutePage extends StatefulWidget {
  const TraceroutePage({super.key, this.initialHost});

  final String? initialHost;

  @override
  State<TraceroutePage> createState() => _TraceroutePageState();
}

class _TraceroutePageState extends State<TraceroutePage> {
  late final TextEditingController _hostCtrl;

  final List<TraceHop> _hops = <TraceHop>[];
  StreamSubscription<TraceHop>? _sub;
  bool _running = false;
  String? _error;

  /// 每跳 IP 的归属地（异步补全）
  final Map<String, String> _geo = <String, String>{};

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: widget.initialHost ?? '');
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hostCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {    final host = _hostCtrl.text.trim();
    if (host.isEmpty) {
      setState(() => _error = '先填主机');
      return;
    }
    _sub?.cancel();
    setState(() {
      _hops.clear();
      _running = true;
      _error = null;
    });

    _sub = SystemService.tracerouteStream(host, maxHops: 16).listen(
      (hop) {
        if (!mounted) return;
        // 读一跳显示一跳
        setState(() => _hops.add(hop));
        // 有 IP 的话顺手查一下归属地（异步，不阻塞）
        final address = hop.address;
        if (address != null && address.isNotEmpty) {
          _lookupGeo(address);
        }
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _running = false;
          _error = '$e';
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _running = false;
          if (_hops.isEmpty) _error = '没有拿到任何跳的信息';
        });
      },
    );
  }

  Future<void> _lookupGeo(String ip) async {
    final text = await IpGeo.lookup(ip);
    if (text == null || !mounted) return;
    setState(() => _geo[ip] = text);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Traceroute')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ToolCard(
            children: [
              ToolField(
                label: AppStrings.of(context).commonHostLabel,
                controller: _hostCtrl,
                hint: 'IP 或域名',
                onSubmitted: (_) => _run(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ToolPrimaryButton(
            onPressed: _running ? null : _run,
            label: AppStrings.of(context).commonStartTraceroute,
            icon: Icons.route_rounded,
            loading: _running,
            loadingLabel: AppStrings.of(context).commonDetecting,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            ToolNotice(message: _error!, error: true),
          ],
          if (_hops.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final hop in _hops)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${hop.ttl}',
                        style: text.bodySmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hop.address ?? '*',
                            style: text.bodyMedium?.copyWith(
                              color: hop.address == null
                                  ? tokens.textDisabled
                                  : tokens.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (hop.address != null &&
                              _geo[hop.address] != null)
                            Text(
                              _geo[hop.address]!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall
                                  ?.copyWith(color: tokens.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    if (hop.rttMs != null)
                      Text(
                        '${hop.rttMs!.toStringAsFixed(1)} ms',
                        style: text.bodySmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    if (hop.error != null && hop.address == null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          hop.error!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall
                              ?.copyWith(color: tokens.textDisabled),
                        ),
                      ),
                    ],
                    if (hop.reached) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.flag_rounded,
                          size: 14, color: tokens.success),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
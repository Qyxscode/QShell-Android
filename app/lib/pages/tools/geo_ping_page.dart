import 'package:flutter/material.dart';
import '../../design/glass_card.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/tools/geo_ping.dart';
import '../../widgets/tool_layout.dart';

/// GeoPing：从 check-host.net 的多个地理节点同时探测目标。
class GeoPingPage extends StatefulWidget {
  const GeoPingPage({super.key, this.initialHost});

  final String? initialHost;

  @override
  State<GeoPingPage> createState() => _GeoPingPageState();
}

class _GeoPingPageState extends State<GeoPingPage> {
  late final TextEditingController _hostCtrl;
  List<GeoPingNode> _nodes = const <GeoPingNode>[];
  bool _running = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: widget.initialHost ?? '');
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) {
      setState(() => _error = '先填主机');
      return;
    }
    setState(() {
      _running = true;
      _error = null;
      _nodes = const <GeoPingNode>[];
    });
    try {
      final nodes = await GeoPingService.ping(
        host,
        onUpdate: (snapshot) {
          if (!mounted) return;
          setState(() => _nodes = snapshot);
        },
      );
      if (!mounted) return;
      setState(() {
        _nodes = nodes;
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = '探测失败：$e';
      });
    }
  }

  String _rttLabel(GeoPingNode node) {
    if (node.pending) return '等待…';
    if (!node.ok) return '超时';
    final ms = node.rtt!.inMilliseconds;
    return '$ms ms';
  }

  Color _rttColor(GeoPingNode node, AppTokens tokens) {
    if (node.pending) return tokens.textDisabled;
    if (!node.ok) return tokens.danger;
    final ms = node.rtt!.inMilliseconds;
    if (ms < 60) return tokens.success;
    if (ms < 150) return tokens.warning;
    return tokens.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final okCount = _nodes.where((node) => node.ok).length;

    return Scaffold(
      appBar: AppBar(title: const Text('GeoPing')),
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
            label: AppStrings.of(context).commonStartDetect,
            icon: Icons.public_rounded,
            loading: _running,
            loadingLabel: AppStrings.of(context).commonDetecting,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            ToolNotice(message: _error!, error: true),
          ],
          if (_running && _nodes.isEmpty) ...[
            const SizedBox(height: 16),
            ToolNotice(message: '正在向 check-host 申请探测节点…'),
          ],
          if (_nodes.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '节点结果（$okCount/${_nodes.length} 可用）',
                    style: text.labelMedium?.copyWith(
                      color: tokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_running)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GlassCard(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < _nodes.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: tokens.outlineSoft,
                      ),
                    _NodeRow(
                      node: _nodes[i],
                      label: _rttLabel(_nodes[i]),
                      color: _rttColor(_nodes[i], tokens),
                      tokens: tokens,
                      text: text,
                    ),
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

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.node,
    required this.label,
    required this.color,
    required this.tokens,
    required this.text,
  });

  final GeoPingNode node;
  final String label;
  final Color color;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          Icon(
            node.pending
                ? Icons.hourglass_empty_rounded
                : (node.ok
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded),
            size: 15,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              node.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(color: tokens.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: text.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

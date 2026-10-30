import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../widgets/tool_layout.dart';
import '../../services/tools/ip_calculator.dart';

/// IP 计算器：输入 CIDR 或「IP 掩码」，实时给出网段信息。
class IpCalculatorPage extends StatefulWidget {
  const IpCalculatorPage({super.key});

  @override
  State<IpCalculatorPage> createState() => _IpCalculatorPageState();
}

class _IpCalculatorPageState extends State<IpCalculatorPage> {
  final _controller = TextEditingController(text: '192.168.1.0/24');
  IpCalcResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recalc();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _recalc() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _result = null;
        _error = null;
      });
      return;
    }
    final result = calculateIpv4(text);
    setState(() {
      _result = result;
      _error = result == null ? '格式不对，试试 192.168.1.0/24 或 "192.168.1.10 255.255.255.0"' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('IP 计算器')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ToolCard(
            children: [
              ToolField(
                label: AppStrings.of(context).ipAddress,
                controller: _controller,
                hint: '192.168.1.0/24',
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            ToolNotice(message: _error!, error: true),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  children: [
                    _Row(AppStrings.of(context).ipAddress, result.address, tokens, text),
                    _Row(AppStrings.of(context).ipPrefix, '/${result.prefix}', tokens, text),
                    _Row(AppStrings.of(context).ipMask, result.mask, tokens, text),
                    _Row(AppStrings.of(context).ipWildcard, result.wildcard, tokens, text),
                    _Row(AppStrings.of(context).ipNetwork, result.network, tokens, text),
                    _Row(AppStrings.of(context).ipBroadcast, result.broadcast, tokens, text),
                    _Row(AppStrings.of(context).ipRange, '${result.firstHost} ~ ${result.lastHost}', tokens, text),
                    _Row(AppStrings.of(context).ipHosts, _formatCount(result.hostCount), tokens, text),
                    _Row(AppStrings.of(context).ipClass, result.className, tokens, text),
                    _Row(AppStrings.of(context).ipPrivate, result.isPrivate ? AppStrings.of(context).commonYes : AppStrings.of(context).commonNo, tokens, text),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '$count（约 ${(count / 1000000).toStringAsFixed(1)} 百万）';
    }
    return '$count';
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, this.tokens, this.text);

  final String label;
  final String value;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: text.bodyMedium?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
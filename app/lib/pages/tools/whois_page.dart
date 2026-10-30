import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/tools/whois_client.dart';
import '../../widgets/tool_layout.dart';

/// Whois 查询：IANA → refer 服务器，结果原文展示。
class WhoisPage extends StatefulWidget {
  const WhoisPage({super.key, this.initialHost});

  final String? initialHost;

  @override
  State<WhoisPage> createState() => _WhoisPageState();
}

class _WhoisPageState extends State<WhoisPage> {
  late final _controller = TextEditingController(text: widget.initialHost ?? '');
  final _client = WhoisClient();
  WhoisResult? _result;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _query() async {
    final target = _controller.text.trim();
    if (target.isEmpty) {
      setState(() => _error = AppStrings.of(context).whoisTargetRequired);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _client.query(target);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendly(e);
      });
    }
  }

  String _friendly(Object e) {
    final text = e.toString();
    if (text.contains('timed out') || text.contains('timeout')) {
      return AppStrings.of(context).whoisTimeout;
    }
    if (text.contains('refused')) {
      return AppStrings.of(context).whoisServerRefused;
    }
    if (text.contains('FormatException')) {
      return text.replaceFirst('FormatException: ', '');
    }
    return '查询失败：$text';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Whois'),
        actions: [
          if (result != null)
            IconButton(
              tooltip: AppStrings.of(context).whoisCopyResult,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: result.text));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppStrings.of(context).commonCopied)),
                );
              },
              icon: const Icon(Icons.copy_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ToolCard(
            children: [
              ToolField(
                label: AppStrings.of(context).whoisTarget,
                controller: _controller,
                hint: AppStrings.of(context).whoisTargetHint,
                onSubmitted: (_) => _query(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ToolPrimaryButton(
            onPressed: _loading ? null : _query,
            label: AppStrings.of(context).commonQuery,
            icon: Icons.search_rounded,
            loading: _loading,
            loadingLabel: AppStrings.of(context).commonQuerying,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ToolNotice(message: _error!, error: true),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.dns_outlined, size: 15, color: tokens.accent),
                const SizedBox(width: 6),
                Text(
                  AppStrings.of(context).whoisSourceTemplate.replaceAll('{server}', result.server),
                  style: text.bodySmall?.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tokens.outlineSoft),
              ),
              child: SelectableText(
                result.text,
                style: text.bodySmall?.copyWith(
                  color: tokens.textPrimary,
                  height: 1.45,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
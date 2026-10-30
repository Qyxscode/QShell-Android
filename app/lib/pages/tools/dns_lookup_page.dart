import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/tools/dns_lookup.dart';
import '../../widgets/tool_layout.dart';

/// DNS Lookup：自己发 DNS 查询，支持 A/AAAA/NS/CNAME/MX/TXT。
class DnsLookupPage extends StatefulWidget {
  const DnsLookupPage({super.key});

  @override
  State<DnsLookupPage> createState() => _DnsLookupPageState();
}

class _DnsLookupPageState extends State<DnsLookupPage> {
  final _nameCtrl = TextEditingController();
  final Set<String> _types = <String>{'A', 'AAAA'};
  final String _server = dnsServers.first.$1;

  DnsLookupResult? _result;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _query() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '先填域名');
      return;
    }
    if (_types.isEmpty) {
      setState(() => _error = '至少选一个记录类型');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    final result = await dnsLookup(
      name,
      server: _server,
      types: _types.toList(),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
      _error = result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('DNS Lookup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ToolCard(
            children: [
              ToolField(
                label: '域名',
                controller: _nameCtrl,
                hint: 'example.com',
                onSubmitted: (_) => _query(),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 52,
                      child: Text(
                        '类型',
                        style: text.bodySmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final type in dnsTypes.keys)
                          FilterChip(
                            label: Text(type),
                            selected: _types.contains(type),
                            visualDensity: VisualDensity.compact,
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _types.add(type);
                              } else {
                                _types.remove(type);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
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
            const SizedBox(height: 10),
            ToolNotice(message: _error!, error: true),
          ],
          if (result != null && result.records.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '结果（${result.records.length}）· ${result.elapsed.inMilliseconds} ms',
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: 8),
            for (final record in result.records)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.outlineSoft),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: tokens.accentSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        record.type,
                        style: text.labelSmall?.copyWith(
                          color: tokens.onAccentSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SelectableText(
                        record.value,
                        style: text.bodyMedium?.copyWith(
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    if (record.ttl > 0)
                      Text(
                        'TTL ${record.ttl}',
                        style: text.labelSmall
                            ?.copyWith(color: tokens.textDisabled),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
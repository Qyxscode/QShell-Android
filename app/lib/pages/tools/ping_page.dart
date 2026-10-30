import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/system_service.dart';
import '../../services/tools/ping_service.dart';
import '../../widgets/tool_layout.dart';

enum _PingMode { icmp, tcp }

/// Ping：默认走真 ICMP（非特权 ping socket），不可用时自动降级 TCP。
class PingPage extends StatefulWidget {
  const PingPage({super.key, this.initialHost});

  final String? initialHost;

  @override
  State<PingPage> createState() => _PingPageState();
}

class _PingPageState extends State<PingPage> {
  late final TextEditingController _hostCtrl;
  final _portCtrl = TextEditingController(text: '443');

  _PingMode _mode = _PingMode.icmp;
  StreamSubscription<PingResult>? _sub;
  final List<PingResult> _results = <PingResult>[];
  PingSummary? _summary;
  bool _running = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: widget.initialHost ?? '');
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) {
      setState(() => _error = AppStrings.of(context).commonHostRequired);
      return;
    }
    await _sub?.cancel();
    setState(() {
      _results.clear();
      _summary = null;
      _running = true;
      _error = null;
      _notice = null;
    });

    if (_mode == _PingMode.icmp) {
      final rtts = await SystemService.icmpPing(host, count: 4);
      if (!mounted) return;
      if (rtts == null) {
        // 该机型不支持非特权 ICMP，自动降级
        setState(() {
          _mode = _PingMode.tcp;
          _notice = AppStrings.of(context).pingIcmpFallback;
        });
        await _startTcp(host);
        return;
      }
      setState(() {
        _results.addAll([
          for (var i = 0; i < rtts.length; i++)
            rtts[i] >= 0
                ? PingResult(
                    seq: i + 1,
                    rtt: Duration(microseconds: (rtts[i] * 1000).round()),
                  )
                : PingResult(seq: i + 1, error: AppStrings.of(context).commonTimeout),
        ]);
        _summary = summarizePing(_results);
        _running = false;
      });
      return;
    }

    await _startTcp(host);
  }

  Future<void> _startTcp(String host) async {
    final port = int.tryParse(_portCtrl.text.trim()) ?? 443;
    _sub = tcpPing(
      host,
      port: port,
      count: 4,
      timeout: const Duration(seconds: 2),
      interval: const Duration(milliseconds: 400),
    ).listen(
      (result) {
        if (!mounted) return;
        setState(() => _results.add(result));
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _running = false;
          _summary = summarizePing(_results);
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _running = false;
          _error = '执行失败：$e';
        });
      },
    );
  }

  void _stop() {
    _sub?.cancel();
    setState(() {
      _running = false;
      _summary = summarizePing(_results);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ping'),
        actions: [
          if (_running)
            IconButton(
              tooltip: '停止',
              onPressed: _stop,
              icon: const Icon(Icons.stop_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ToolCard(
            children: [
              // 探测方式
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      AppStrings.of(context).pingMode,
                      style: text.bodySmall
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                  ),
                  for (final mode in _PingMode.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(mode == _PingMode.icmp ? 'ICMP' : 'TCP'),
                        selected: _mode == mode,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() {
                          _mode = mode;
                          _notice = null;
                          _error = null;
                        }),
                      ),
                    ),
                ],
              ),
              ToolField(
                label: AppStrings.of(context).commonHostLabel,
                controller: _hostCtrl,
                hint: 'IP 或域名',
              ),
              if (_mode == _PingMode.tcp)
                ToolField(
                  label: '端口',
                  controller: _portCtrl,
                  hint: '443',
                  keyboardType: TextInputType.number,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ToolPrimaryButton(
            onPressed: _running ? null : _start,
            label: AppStrings.of(context).commonStartPing,
            icon: Icons.network_ping_rounded,
            loading: _running,
            loadingLabel: AppStrings.of(context).commonDetecting,
          ),
          if (_notice != null) ...[
            const SizedBox(height: 10),
            ToolNotice(message: _notice!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            ToolNotice(message: _error!, error: true),
          ],
          if (summary != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  children: [
                    _Stat(
                      label: AppStrings.of(context).pingSentReceived,
                      value: '${summary.sent} / ${summary.received}',
                      tokens: tokens,
                      text: text,
                    ),
                    _Stat(
                      label: AppStrings.of(context).pingLoss,
                      value: '${summary.lossPercent}%',
                      tokens: tokens,
                      text: text,
                      color: summary.lossPercent == 0
                          ? tokens.success
                          : tokens.warning,
                    ),
                    _Stat(
                      label: AppStrings.of(context).pingMinAvgMax,
                      value: summary.min == null
                          ? '--'
                          : '${_ms(summary.min!)} / ${_ms(summary.avg!)} / ${_ms(summary.max!)}',
                      tokens: tokens,
                      text: text,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final r in _results)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        '#${r.seq}',
                        style: text.bodySmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.success ? _ms(r.rtt!) : (r.error ?? AppStrings.of(context).commonFailed),
                        style: text.bodyMedium?.copyWith(
                          color: r.success ? tokens.textPrimary : tokens.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      r.success
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      size: 16,
                      color: r.success ? tokens.success : tokens.danger,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _ms(Duration d) => '${d.inMilliseconds} ms';

}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.tokens,
    required this.text,
    this.color,
  });

  final String label;
  final String value;
  final AppTokens tokens;
  final TextTheme text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: text.bodySmall?.copyWith(color: tokens.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: text.bodyMedium?.copyWith(
              color: color ?? tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
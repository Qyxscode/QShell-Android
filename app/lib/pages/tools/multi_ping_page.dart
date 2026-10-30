import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../widgets/tool_layout.dart';
import '../../services/tools/ping_service.dart';
import '../../widgets/sparkline.dart';

/// 多设备 Ping：一行一个目标，同时探测并实时显示延迟 / 丢包 / 趋势。
class MultiPingPage extends StatefulWidget {
  const MultiPingPage({super.key});

  @override
  State<MultiPingPage> createState() => _MultiPingPageState();
}

class _TargetState {
  _TargetState(this.host, this.port);

  final String host;
  final int port;
  int sent = 0;
  int received = 0;
  Duration? lastRtt;
  bool? online;
  final List<double> series = <double>[];

  int get lossPercent =>
      sent == 0 ? 0 : ((sent - received) * 100 / sent).round();

  String get label => port == 443 ? host : '$host:$port';
}

class _MultiPingPageState extends State<MultiPingPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final List<_TargetState> _targets = <_TargetState>[];
  Timer? _timer;
  bool _running = false;
  String? _error;

  static const int _seriesLength = 40;

  @override
  void dispose() {
    _timer?.cancel();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _start() {
    final raw = _inputCtrl.text
        .split(RegExp(r'[\s,，]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (raw.isEmpty) {
      setState(() => _error = '先填至少一个目标');
      return;
    }
    final targets = <_TargetState>[];
    for (final item in raw.take(20)) {
      final parts = item.split(':');
      final host = parts[0].trim();
      final port = parts.length > 1 ? (int.tryParse(parts[1]) ?? 443) : 443;
      if (host.isEmpty) continue;
      targets.add(_TargetState(host, port));
    }
    if (targets.isEmpty) {
      setState(() => _error = '没有解析出有效目标');
      return;
    }
    _timer?.cancel();
    setState(() {
      _targets
        ..clear()
        ..addAll(targets);
      _running = true;
      _error = null;
    });
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    setState(() => _running = false);
  }

  Future<void> _tick() async {
    // 并发探测所有目标，每轮每个目标打一次
    await Future.wait(_targets.map(_probeOne));
  }

  Future<void> _probeOne(_TargetState target) async {
    if (!mounted) return;
    final sw = Stopwatch()..start();
    var ok = false;
    try {
      final results = await tcpPing(
        target.host,
        port: target.port,
        count: 1,
        timeout: const Duration(seconds: 2),
        interval: Duration.zero,
      ).toList();
      ok = results.isNotEmpty && results.first.success;
      final rtt = results.isNotEmpty ? results.first.rtt : null;
      if (!mounted) return;
      setState(() {
        target.sent++;
        if (ok && rtt != null) {
          target.received++;
          target.lastRtt = rtt;
          target.online = true;
          target.series.add(rtt.inMilliseconds.toDouble());
        } else {
          target.online = false;
          target.series.add(0);
        }
        if (target.series.length > _seriesLength) {
          target.series.removeRange(0, target.series.length - _seriesLength);
        }
      });
    } catch (_) {
      sw.stop();
      if (!mounted) return;
      setState(() {
        target.sent++;
        target.online = false;
        target.series.add(0);
        if (target.series.length > _seriesLength) {
          target.series.removeRange(0, target.series.length - _seriesLength);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('多设备 Ping'),
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            children: [
              TextField(
                controller: _inputCtrl,
                maxLines: 4,
                minLines: 3,
                autocorrect: false,
                enableSuggestions: false,
                style: text.bodyMedium?.copyWith(color: tokens.textPrimary),
                decoration: InputDecoration(
                  hintText: '一行一个目标，可带端口\n8.8.8.8\n1.1.1.1:443',
                  hintStyle:
                      text.bodySmall?.copyWith(color: tokens.textDisabled),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  filled: true,
                  fillColor: tokens.surfaceCardAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ToolPrimaryButton(
            onPressed: _running ? null : _start,
            label: AppStrings.of(context).commonStartDetect,
            icon: Icons.playlist_play_rounded,
            loading: _running,
            loadingLabel: AppStrings.of(context).commonDetecting,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            ToolNotice(message: _error!, error: true),
          ],
          if (_targets.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final target in _targets)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: target.online == null
                            ? tokens.textDisabled
                            : (target.online! ? tokens.success : tokens.danger),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              target.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium?.copyWith(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              target.online == null
                                  ? '等待探测'
                                  : '${target.lastRtt?.inMilliseconds ?? "-"} ms · 丢包 ${target.lossPercent}% · ${target.received}/${target.sent}',
                              style: text.labelSmall
                                  ?.copyWith(color: tokens.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (target.series.length >= 2)
                        SizedBox(
                          width: 70,
                          child: Sparkline(
                            values: target.series,
                            height: 28,
                            color: target.online == false
                                ? tokens.danger
                                : tokens.accent,
                            fill: false,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
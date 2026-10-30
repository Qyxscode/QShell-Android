import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../widgets/tool_layout.dart';
import '../../services/tools/port_scanner.dart';

enum _PortMode { common, custom, all }

/// 端口扫描：TCP connect，流式展示结果。
class PortScanPage extends StatefulWidget {
  const PortScanPage({super.key, this.initialHost});

  final String? initialHost;

  @override
  State<PortScanPage> createState() => _PortScanPageState();
}

class _PortScanPageState extends State<PortScanPage> {
  late final TextEditingController _hostCtrl =
      TextEditingController(text: widget.initialHost ?? '');
  final _customCtrl = TextEditingController();

  _PortMode _mode = _PortMode.common;
  Duration _timeout = const Duration(milliseconds: 600);

  StreamSubscription<PortScanEvent>? _sub;
  final List<(int, PortState)> _results = <(int, PortState)>[];
  bool _scanning = false;
  bool _showAll = false;
  int _scanned = 0;
  int _total = 0;
  String? _error;

  static const int _concurrency = 32;

  @override
  void dispose() {
    _sub?.cancel();
    _hostCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  List<int> get _selectedPorts => switch (_mode) {
        _PortMode.common => commonPorts.keys.toList()..sort(),
        _PortMode.custom => parsePorts(_customCtrl.text),
        _PortMode.all => <int>[for (var i = 1; i <= 65535; i++) i],
      };

  int get _estimatedSeconds {
    final count = _selectedPorts.length;
    if (count == 0) return 0;
    final concurrency = count > 2000 ? 128 : _concurrency;
    final perWorker = count / concurrency;
    return (perWorker * _timeout.inMilliseconds / 1000).ceil();
  }

  void _start() {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) {
      setState(() => _error = AppStrings.of(context).commonHostRequired);
      return;
    }
    final ports = _selectedPorts;
    if (ports.isEmpty) {
      setState(() => _error = AppStrings.of(context).portInvalidFormat);
      return;
    }

    _sub?.cancel();
    setState(() {
      _results.clear();
      _scanning = true;
      _scanned = 0;
      _total = ports.length;
      _error = null;
    });

    _sub = scanPorts(
      host,
      ports,
      timeout: _timeout,
      concurrency: ports.length > 2000 ? 128 : _concurrency,
    ).listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _scanned = event.scanned;
          if (event.isResult) {
            _results.add((event.port!, event.state!));
            _results.sort((a, b) => a.$1.compareTo(b.$1));
          }
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _scanning = false);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _scanning = false;
          _error = AppStrings.of(context).scanErrorTemplate.replaceAll('{msg}', '$e');
        });
      },
    );
  }

  void _stop() {
    _sub?.cancel();
    setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final openPorts = _results.where((r) => r.$2 == PortState.open).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).scanTitle),
        actions: [
          if (_scanning)
            IconButton(
              tooltip: AppStrings.of(context).settingsStopMonitor,
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
              ToolField(
                label: AppStrings.of(context).commonHostLabel,
                controller: _hostCtrl,
                hint: 'IP 或域名',
              ),
              // 端口范围
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      '范围',
                      style: text.bodySmall
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: SegmentedButton<_PortMode>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: [
                        ButtonSegment(
                            value: _PortMode.common, label: Text(AppStrings.of(context).portCommon)),
                        ButtonSegment(
                            value: _PortMode.custom, label: Text(AppStrings.of(context).portCustom)),
                        ButtonSegment(
                            value: _PortMode.all, label: Text(AppStrings.of(context).portAll)),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (value) => setState(() {
                        _mode = value.first;
                        _error = null;
                      }),
                    ),
                  ),
                ],
              ),
              if (_mode == _PortMode.custom)
                ToolField(
                  label: '端口',
                  controller: _customCtrl,
                  hint: '80,443,8000-8100',
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Text(
                    _mode == _PortMode.common
                        ? '常用端口 ${commonPorts.length} 个：${commonPorts.keys.join(", ")}'
                        : AppStrings.of(context).portAllHint,
                    style:
                        text.labelSmall?.copyWith(color: tokens.textSecondary),
                  ),
                ),
              // 超时
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: SizedBox(
                      width: 52,
                      child: Text(
                        AppStrings.of(context).commonTimeout,
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
                        for (final option in const <(String, Duration)>[
                          ('300ms', Duration(milliseconds: 300)),
                          ('600ms', Duration(milliseconds: 600)),
                          ('1s', Duration(seconds: 1)),
                          ('2s', Duration(seconds: 2)),
                        ])
                          ChoiceChip(
                            label: Text(option.$1),
                            selected: _timeout == option.$2,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) =>
                                setState(() => _timeout = option.$2),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_scanning && _selectedPorts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                AppStrings.of(context).portEstimateTemplate.replaceAll('{n}', '${_selectedPorts.length}').replaceAll('{t}', _prettyDuration(_estimatedSeconds)),
                style: text.labelSmall?.copyWith(color: tokens.textSecondary),
              ),
            ),
          ToolPrimaryButton(
            onPressed: _scanning ? null : _start,
            label: AppStrings.of(context).commonStartScan,
            icon: Icons.play_arrow_rounded,
            loading: _scanning,
            loadingLabel: AppStrings.of(context).commonScanning,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            ToolNotice(message: _error!, error: true),
          ],
          if (_scanning) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: _total == 0 ? null : _scanned / _total,
                minHeight: 4,
                backgroundColor: tokens.track,
                color: tokens.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.of(context).portScannedTemplate.replaceAll('{a}', '$_scanned').replaceAll('{b}', '$_total'),
              style: text.labelSmall?.copyWith(color: tokens.textSecondary),
            ),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.of(context).portOpenCountTemplate.replaceAll('{n}', '${openPorts.length}'),
                    style: text.labelMedium?.copyWith(
                      color: tokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_results.length > openPorts.length)
                  TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(_showAll ? AppStrings.of(context).portShowOpenOnly : AppStrings.of(context).portShowAll),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (port, state) in (_showAll ? _results : openPorts))
                  _PortChip(
                    port: port,
                    state: state,
                    tokens: tokens,
                    text: text,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  String _prettyDuration(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final minutes = (seconds / 60).ceil();
    return '$minutes 分钟';
  }

}

class _PortChip extends StatelessWidget {
  const _PortChip({
    required this.port,
    required this.state,
    required this.tokens,
    required this.text,
  });

  final int port;
  final PortState state;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      PortState.open => tokens.success,
      PortState.closed => tokens.textDisabled,
      PortState.filtered => tokens.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.surfaceCardAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$port',
        style: text.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

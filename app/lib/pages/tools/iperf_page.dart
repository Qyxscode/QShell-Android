import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/system_service.dart';
import '../../services/tools/iperf_service.dart';
import '../../widgets/tool_layout.dart';

/// iperf3：参数可自定义 + 快捷预设 + 双向测试。
class IperfPage extends StatefulWidget {
  const IperfPage({super.key, this.initialHost});

  final String? initialHost;

  @override
  State<IperfPage> createState() => _IperfPageState();
}

class _IperfPageState extends State<IperfPage> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _streamsCtrl;
  late final TextEditingController _bandwidthCtrl;
  late final TextEditingController _durationCtrl;

  bool _udp = false;
  IperfDirection _direction = IperfDirection.up;

  bool _running = false;
  String? _binaryPath;
  String? _error;
  IperfResult? _result;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: widget.initialHost ?? '');
    _portCtrl = TextEditingController(text: '5201');
    _streamsCtrl = TextEditingController(text: '1');
    _bandwidthCtrl = TextEditingController(text: '100M');
    _durationCtrl = TextEditingController(text: '10');
    _loadBinary();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _streamsCtrl.dispose();
    _bandwidthCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBinary() async {
    final path = await SystemService.iperfPath();
    if (!mounted) return;
    setState(() {
      _binaryPath = path;
      if (path == null) {
        _error = AppStrings.of(context).iperfNoBinary;
      }
    });
  }

  IperfOptions _buildOptions() => IperfOptions(
        host: _hostCtrl.text.trim(),
        port: int.tryParse(_portCtrl.text.trim()) ?? 5201,
        udp: _udp,
        direction: _direction,
        streams: (int.tryParse(_streamsCtrl.text.trim()) ?? 1).clamp(1, 64),
        bandwidth: _bandwidthCtrl.text.trim().isEmpty
            ? '100M'
            : _bandwidthCtrl.text.trim(),
        durationSeconds:
            (int.tryParse(_durationCtrl.text.trim()) ?? 10).clamp(1, 300),
      );

  void _applyPreset(IperfQuickPreset preset) {
    final options = preset.applyTo(_buildOptions());
    setState(() {
      _udp = options.udp;
      _direction = options.direction;
      _streamsCtrl.text = '${options.streams}';
      _bandwidthCtrl.text = options.bandwidth;
    });
  }

  Future<void> _run() async {
    final binary = _binaryPath;
    if (binary == null) return;
    final options = _buildOptions();
    if (options.host.isEmpty) {
      setState(() => _error = AppStrings.of(context).iperfServerRequired);
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await runIperf(binaryPath: binary, options: options);
      if (!mounted) return;
      setState(() {
        _result = result;
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = iperfErrorText(e);
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final result = _result;
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 10;

    return Scaffold(
      appBar: AppBar(title: const Text('iperf3')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ToolCard(
            children: [
              ToolField(
                label: AppStrings.of(context).iperfServer,
                controller: _hostCtrl,
                hint: AppStrings.of(context).sessionsHostHint,
              ),
              ToolField(
                label: AppStrings.of(context).commonPort,
                controller: _portCtrl,
                hint: '5201',
                keyboardType: TextInputType.number,
              ),
              // 协议
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      AppStrings.of(context).iperfProtocol,
                      style: text.bodySmall
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(value: false, label: Text('TCP')),
                        ButtonSegment(value: true, label: Text('UDP')),
                      ],
                      selected: {_udp},
                      onSelectionChanged: (value) =>
                          setState(() => _udp = value.first),
                    ),
                  ),
                ],
              ),
              // 方向
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      AppStrings.of(context).iperfDirection,
                      style: text.bodySmall
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: SegmentedButton<IperfDirection>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: [
                        for (final direction in IperfDirection.values)
                          ButtonSegment(
                            value: direction,
                            label: Text(switch (direction) {
                              IperfDirection.up => AppStrings.of(context).iperfUp,
                              IperfDirection.down => AppStrings.of(context).iperfDown,
                              IperfDirection.both => AppStrings.of(context).iperfBoth,
                            }),
                          ),
                      ],
                      selected: {_direction},
                      onSelectionChanged: (value) =>
                          setState(() => _direction = value.first),
                    ),
                  ),
                ],
              ),
              ToolField(
                label: AppStrings.of(context).iperfStreams,
                controller: _streamsCtrl,
                hint: '1',
                keyboardType: TextInputType.number,
              ),
              ToolField(
                label: AppStrings.of(context).iperfDuration,
                controller: _durationCtrl,
                hint: AppStrings.of(context).iperfSeconds,
                keyboardType: TextInputType.number,
              ),
              if (_udp)
                ToolField(
                  label: AppStrings.of(context).iperfBandwidth,
                  controller: _bandwidthCtrl,
                  hint: '100M / 1G',
                ),
            ],
          ),
          const SizedBox(height: 12),
          ToolSectionTitle(AppStrings.of(context).iperfPresets),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preset in iperfQuickPresets)
                ActionChip(
                  label: Text(preset.name),
                  tooltip: preset.description,
                  visualDensity: VisualDensity.compact,
                  onPressed: _running ? null : () => _applyPreset(preset),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ToolPrimaryButton(
            onPressed: _running ? null : _run,
            label: AppStrings.of(context).commonStartTest,
            icon: Icons.speed_rounded,
            loading: _running,
            loadingLabel: '测试中（${duration}s）…',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ToolNotice(message: _error!, error: true),
          ],
          if (result != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          result.primaryMbps?.toStringAsFixed(1) ?? '--',
                          style: text.displaySmall?.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Mbps',
                          style: text.titleMedium
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                    if (result.bidirectional) ...[
                      const SizedBox(height: 6),
                      Text(
                        '上行 ${result.sentMbps?.toStringAsFixed(1) ?? "--"} · 下行 ${result.receivedMbps?.toStringAsFixed(1) ?? "--"} Mbps',
                        style: text.bodySmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (!result.isUdp && result.retransmits != null)
                      _Stat(
                        label: AppStrings.of(context).iperfRetransmits,
                        value: '${result.retransmits}',
                        tokens: tokens,
                        text: text,
                      ),
                    if (result.isUdp) ...[
                      _Stat(
                        label: AppStrings.of(context).iperfJitter,
                        value:
                            '${result.jitterMs?.toStringAsFixed(2) ?? "--"} ms',
                        tokens: tokens,
                        text: text,
                      ),
                      _Stat(
                        label: AppStrings.of(context).iperfLoss,
                        value:
                            '${result.lostPercent?.toStringAsFixed(2) ?? "--"}%（${result.lostPackets ?? 0} 个）',
                        tokens: tokens,
                        text: text,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.surfaceCardAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        result.verdict,
                        style: text.bodySmall
                            ?.copyWith(color: tokens.textPrimary),
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.tokens,
    required this.text,
  });

  final String label;
  final String value;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

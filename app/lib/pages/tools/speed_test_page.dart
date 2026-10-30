import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../widgets/tool_layout.dart';
import '../../services/tools/speed_test.dart';

/// 网速测试：内置 Cloudflare + 自定义节点（推荐用自己的 VPS 测速文件）。
class SpeedTestPage extends StatefulWidget {
  const SpeedTestPage({super.key});

  @override
  State<SpeedTestPage> createState() => _SpeedTestPageState();
}

class _SpeedTestPageState extends State<SpeedTestPage> {
  static const _kCustomDownload = 'speed.custom_download';
  static const _kCustomUpload = 'speed.custom_upload';
  static const _kUseCustom = 'speed.use_custom';

  final _downloadCtrl = TextEditingController();
  final _uploadCtrl = TextEditingController();

  bool _useCustom = false;
  StreamSubscription<SpeedEvent>? _sub;
  SpeedPhase _phase = SpeedPhase.idle;
  double _progress = 0;
  double _instantMbps = 0;
  String? _message;
  SpeedResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _downloadCtrl.dispose();
    _uploadCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _useCustom = prefs.getBool(_kUseCustom) ?? false;
      _downloadCtrl.text = prefs.getString(_kCustomDownload) ?? '';
      _uploadCtrl.text = prefs.getString(_kCustomUpload) ?? '';
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseCustom, _useCustom);
    await prefs.setString(_kCustomDownload, _downloadCtrl.text.trim());
    await prefs.setString(_kCustomUpload, _uploadCtrl.text.trim());
  }

  SpeedNode? get _activeNode {
    if (!_useCustom) return builtinSpeedNodes.first;
    final download = _downloadCtrl.text.trim();
    if (download.isEmpty) return null;
    return SpeedNode(
      id: 'custom',
      name: '自定义',
      downloadUrl: download,
      uploadUrl: _uploadCtrl.text.trim(),
    );
  }

  Future<void> _start() async {
    final node = _activeNode;
    if (node == null) {
      setState(() => _error = AppStrings.of(context).speedCustomNodeRequired);
      return;
    }
    await _savePrefs();
    _sub?.cancel();
    setState(() {
      _phase = SpeedPhase.latency;
      _progress = 0;
      _instantMbps = 0;
      _message = AppStrings.of(context).speedPreparing;
      _result = null;
      _error = null;
    });
    _sub = runSpeedTest(node).listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _phase = event.phase;
          if (event.progress > 0) _progress = event.progress;
          if (event.instantMbps > 0) _instantMbps = event.instantMbps;
          if (event.message != null) _message = event.message;
          if (event.result != null) _result = event.result;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _phase = SpeedPhase.failed;
          _message = AppStrings.of(context).speedFailedTemplate.replaceAll('{msg}', '$e');
        });
      },
    );
  }

  void _stop() {
    _sub?.cancel();
    setState(() {
      _phase = SpeedPhase.idle;
      _message = AppStrings.of(context).speedStopped;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final running = _phase != SpeedPhase.idle &&
        _phase != SpeedPhase.done &&
        _phase != SpeedPhase.failed;
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).speedTitle),
        actions: [
          if (running)
            IconButton(
              tooltip: AppStrings.of(context).commonStop,
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
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      '节点',
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
                      segments: [
                        ButtonSegment(value: false, label: Text(AppStrings.of(context).speedCloudflare)),
                        ButtonSegment(value: true, label: Text(AppStrings.of(context).portCustom)),
                      ],
                      selected: {_useCustom},
                      onSelectionChanged: running
                          ? null
                          : (value) =>
                              setState(() => _useCustom = value.first),
                    ),
                  ),
                ],
              ),
              if (_useCustom) ...[
                ToolField(
                  label: AppStrings.of(context).speedDownload,
                  controller: _downloadCtrl,
                  hint: 'https://your-host/speedtest.bin',
                ),
                ToolField(
                  label: AppStrings.of(context).speedUpload,
                  controller: _uploadCtrl,
                  hint: AppStrings.of(context).speedUploadHint,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ToolPrimaryButton(
            onPressed: running ? null : _start,
            label: AppStrings.of(context).commonStartSpeed,
            icon: Icons.speed_rounded,
            loading: running,
            loadingLabel: _phaseLabel(),
          ),
          if (running) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 6,
                backgroundColor: tokens.track,
                color: tokens.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _message ?? '',
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
            if (_instantMbps > 0) ...[
              const SizedBox(height: 12),
              Text(
                '${_instantMbps.toStringAsFixed(2)} Mbps',
                style: text.headlineMedium?.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
          if (result != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  children: [
                    _Metric(
                      icon: Icons.download_rounded,
                      label: AppStrings.of(context).speedDownload,
                      value: '${result.downloadMbps.toStringAsFixed(2)} Mbps',
                      tokens: tokens,
                      text: text,
                    ),
                    if (result.uploadBytes > 0) ...[
                      const SizedBox(height: 12),
                      _Metric(
                        icon: Icons.upload_rounded,
                        label: AppStrings.of(context).speedUpload,
                        value: '${result.uploadMbps.toStringAsFixed(2)} Mbps',
                        tokens: tokens,
                        text: text,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _Metric(
                      icon: Icons.timer_outlined,
                      label: '延迟',
                      value: '${result.latencyMs} ms',
                      tokens: tokens,
                      text: text,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: text.bodySmall?.copyWith(color: tokens.danger)),
          ],
          if (_phase == SpeedPhase.failed && _message != null) ...[
            const SizedBox(height: 12),
            Text(_message!,
                style: text.bodySmall?.copyWith(color: tokens.danger)),
          ],
        ],
      ),
    );
  }

  String _phaseLabel() => switch (_phase) {
        SpeedPhase.latency => AppStrings.of(context).speedPhaseLatency,
        SpeedPhase.download => AppStrings.of(context).speedPhaseDownload,
        SpeedPhase.upload => AppStrings.of(context).speedPhaseUpload,
        _ => AppStrings.of(context).speedTesting,
      };

}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.tokens,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String value;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: tokens.accent),
        const SizedBox(width: 10),
        Text(label,
            style: text.bodyMedium?.copyWith(color: tokens.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: text.titleMedium?.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

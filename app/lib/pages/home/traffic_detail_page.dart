import 'dart:async';
import '../../design/glass_card.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/system_service.dart';

/// 流量详情：总流量、实时上下行、每个应用（含后台）的用量。
class TrafficDetailPage extends StatefulWidget {
  const TrafficDetailPage({super.key});

  @override
  State<TrafficDetailPage> createState() => _TrafficDetailPageState();
}

class _TrafficDetailPageState extends State<TrafficDetailPage> {
  Timer? _ticker;
  TrafficInfo? _last;
  DateTime? _lastAt;

  double _rxSpeed = 0;
  double _txSpeed = 0;

  bool _hasPermission = false;
  bool _loading = true;
  String? _error;
  List<AppTraffic> _apps = const <AppTraffic>[];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final granted = await SystemService.hasUsageAccess();
    if (!mounted) return;
    setState(() => _hasPermission = granted);
    await _sampleSpeed();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _sampleSpeed());
    if (granted) {
      await _loadApps();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _sampleSpeed() async {
    final now = DateTime.now();
    final info = await SystemService.trafficInfo();
    if (!mounted || info == null) return;
    final last = _last;
    final lastAt = _lastAt;
    if (last != null && lastAt != null) {
      final seconds = now.difference(lastAt).inMilliseconds / 1000.0;
      if (seconds > 0) {
        setState(() {
          _rxSpeed = ((info.rx - last.rx) / seconds).clamp(0, double.infinity);
          _txSpeed = ((info.tx - last.tx) / seconds).clamp(0, double.infinity);
        });
      }
    }
    _last = info;
    _lastAt = now;
    if (mounted && _last == null) {
      setState(() {});
    }
  }

  Future<void> _loadApps() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apps = await SystemService.appTraffic();
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '读取应用流量失败：$e';
      });
    }
  }

  Future<void> _requestPermission() async {
    await SystemService.openUsageAccess();
    // 回到 App 后重新检查
    if (!mounted) return;
    final granted = await SystemService.hasUsageAccess();
    if (!mounted) return;
    setState(() => _hasPermission = granted);
    if (granted) {
      await _loadApps();
    }
  }

  String _fmtBytes(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  String _fmtSpeed(double bytesPerSecond) {
    if (bytesPerSecond >= 1048576) {
      return '${(bytesPerSecond / 1048576).toStringAsFixed(2)} MB/s';
    }
    if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${bytesPerSecond.toStringAsFixed(0)} B/s';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final info = _last;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).trafficTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).commonRefresh,
            onPressed: _hasPermission ? _loadApps : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadApps();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          AppStrings.of(context).trafficTotal,
                          style: text.labelMedium
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                        const Spacer(),
                        Text(
                          info == null ? '--' : _fmtBytes(info.total),
                          style: text.titleMedium?.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _chip(Icons.download_rounded, AppStrings.of(context).trafficDown,
                            _fmtSpeed(_rxSpeed), tokens, text),
                        const SizedBox(width: 10),
                        _chip(Icons.upload_rounded, AppStrings.of(context).trafficUp,
                            _fmtSpeed(_txSpeed), tokens, text),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 累计收/发与上面的上行下行用同一种底框，保持视觉一致
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceCardAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        // 一左一右，撑满整行
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '累计收 ${info == null ? "--" : _fmtBytes(info.rx)}',
                            style: text.bodySmall
                                ?.copyWith(color: tokens.textSecondary),
                          ),
                          Text(
                            '累计发 ${info == null ? "--" : _fmtBytes(info.tx)}',
                            style: text.bodySmall
                                ?.copyWith(color: tokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 应用列表统一放进卡片，和上面的流量卡视觉对齐
            GlassCard(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(
                      AppStrings.of(context).trafficAppUsage,
                      style: text.labelMedium?.copyWith(
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!_hasPermission)
                    _permissionCard(tokens, text)
                  else if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      child: Text(
                        _error!,
                        style:
                            text.bodySmall?.copyWith(color: tokens.danger),
                      ),
                    )
                  else if (_apps.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Text(
                        AppStrings.of(context).trafficNoAppData,
                        style: text.bodyMedium
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        children: [
                          for (final app in _apps)
                            _AppRow(
                              app: app,
                              tokens: tokens,
                              text: text,
                              fmt: _fmtBytes,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    IconData icon,
    String label,
    String value,
    AppTokens tokens,
    TextTheme text,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.surfaceCardAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: tokens.accent),
            const SizedBox(width: 6),
            Text(label,
                style: text.bodySmall?.copyWith(color: tokens.textSecondary)),
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
      ),
    );
  }

  Widget _permissionCard(AppTokens tokens, TextTheme text) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.of(context).trafficNeedUsage,
              style: text.titleSmall?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '' "${AppStrings.of(context).trafficUsageDesc1}${AppStrings.of(context).trafficUsageDesc2}",
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _requestPermission,
              child: Text(AppStrings.of(context).trafficGoGrant),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.tokens,
    required this.text,
    required this.fmt,
  });

  final AppTraffic app;
  final AppTokens tokens;
  final TextTheme text;
  final String Function(int bytes) fmt;

  @override
  Widget build(BuildContext context) {
    final icon = app.icon;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 36,
              height: 36,
              child: icon == null
                  ? Container(
                      color: tokens.surfaceCardAlt,
                      alignment: Alignment.center,
                      child: Icon(Icons.apps_rounded,
                          size: 18, color: tokens.textSecondary),
                    )
                  : Image.memory(
                      Uint8List.fromList(icon),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => Container(
                        color: tokens.surfaceCardAlt,
                        alignment: Alignment.center,
                        child: Icon(Icons.apps_rounded,
                            size: 18, color: tokens.textSecondary),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      text.bodyMedium?.copyWith(color: tokens.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '↓ ${fmt(app.rx)}   ↑ ${fmt(app.tx)}',
                  style:
                      text.labelSmall?.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            fmt(app.total),
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

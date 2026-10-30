import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/system_service.dart';
import '../tools/ping_page.dart';
import '../tools/port_scan_page.dart';

/// Wi-Fi 分析面板：当前连接概况 + 信号历史 + 信道图 + 热点列表。
class WifiScanPage extends StatefulWidget {
  const WifiScanPage({super.key});

  @override
  State<WifiScanPage> createState() => _WifiScanPageState();
}

class _WifiScanPageState extends State<WifiScanPage> {
  List<WifiScanResult> _results = const <WifiScanResult>[];
  WifiInfo? _current;
  final List<double> _history = <double>[];

  Timer? _sampler;
  bool _scanning = false;
  bool _granted = false;
  int _band = 0; // 0 = 2.4G, 1 = 5G

  /// 默认网关，供「Ping 网关」使用
  String? _gateway;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sampler?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final granted = await SystemService.hasWifiPermission();
    if (!mounted) return;
    setState(() => _granted = granted);
    if (!granted) return;
    final gateways = await SystemService.defaultGateways();
    if (!mounted) return;
    setState(() => _gateway = gateways.isNotEmpty ? gateways.values.first : null);
    await _refresh();
    // 信号历史：2 秒采一次，保留约 1 分钟
    _sampler ??= Timer.periodic(const Duration(seconds: 2), (_) => _sample());
  }

  Future<void> _sample() async {
    final info = await SystemService.wifiInfo();
    if (!mounted) return;
    setState(() {
      _current = info;
      if (info != null) {
        _history.add(info.rssi.toDouble());
        if (_history.length > 30) _history.removeAt(0);
      }
    });
  }

  Future<void> _refresh() async {
    setState(() => _scanning = true);
    final info = await SystemService.wifiInfo();
    final results = await SystemService.wifiScan();
    if (!mounted) return;
    setState(() {
      _current = info;
      _results = results;
      _scanning = false;
    });
  }

  Future<void> _requestPermission() async {
    await SystemService.requestWifiPermission();
    if (!mounted) return;
    await _init();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi 分析'),
        actions: [
          IconButton(
            tooltip: strings.lanRescan,
            onPressed: _scanning || !_granted ? null : _refresh,
            icon: _scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: !_granted
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 40, color: tokens.textDisabled),
                    const SizedBox(height: 12),
                    Text(
                      strings.trafficNeedUsage,
                      textAlign: TextAlign.center,
                      style: text.bodyMedium
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _requestPermission,
                      child: Text(strings.trafficGoGrant),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                _SummaryCard(current: _current, tokens: tokens, text: text),
                const SizedBox(height: 10),
                _HistoryCard(history: _history, tokens: tokens, text: text),
                const SizedBox(height: 10),
                _ChannelCard(
                  results: _results,
                  band: _band,
                  onBandChanged: (value) => setState(() => _band = value),
                  tokens: tokens,
                  text: text,
                ),
                const SizedBox(height: 10),
                _ChannelScoreCard(
                  results: _results,
                  band: _band,
                  tokens: tokens,
                  text: text,
                ),
                const SizedBox(height: 10),
                _QualityCard(
                  current: _current,
                  results: _results,
                  tokens: tokens,
                  text: text,
                  onPingGateway: (host) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PingPage(initialHost: host),
                      ),
                    );
                  },
                  onPortScan: (host) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PortScanPage(initialHost: host),
                      ),
                    );
                  },
                  gateway: _gateway,
                ),
                const SizedBox(height: 10),
                _ApListCard(
                  results: _results,
                  band: _band,
                  tokens: tokens,
                  text: text,
                ),
              ],
            ),
    );
  }
}

// ---------- 工具函数 ----------

int _channelOf(int frequency) {
  if (frequency == 2484) return 14;
  if (frequency >= 2412 && frequency <= 2472) return (frequency - 2407) ~/ 5;
  if (frequency >= 5000 && frequency < 5925) return (frequency - 5000) ~/ 5;
  if (frequency >= 5925) return (frequency - 5950) ~/ 5;
  return 0;
}

String _standardName(int code) {
  switch (code) {
    case 1:
      return '11a';
    case 2:
      return '11b';
    case 3:
      return '11g';
    case 4:
      return '11n';
    case 5:
      return '11ac';
    case 6:
      return '11ax';
    case 7:
      return '11ad';
    case 8:
      return '11be';
  }
  return '';
}

String _widthName(int mhz) {
  switch (mhz) {
    case 1:
      return '20MHz';
    case 2:
      return '40MHz';
    case 3:
      return '80MHz';
    case 4:
      return '160MHz';
    case 5:
      return '80+80MHz';
  }
  return '';
}

bool _is5g(int frequency) => frequency >= 5000;

// ---------- 概况 ----------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.current,
    required this.tokens,
    required this.text,
  });

  final WifiInfo? current;
  final AppTokens tokens;
  final TextTheme text;

  List<Color> get palette => <Color>[
        tokens.accent,
        tokens.success,
        tokens.warning,
        tokens.highlight,
        tokens.danger,
      ];

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final info = current;
    final channel = info == null ? 0 : _channelOf(info.frequency);
    final standard = info == null ? '' : _standardName(info.standard);
    final width = info == null ? '' : _widthName(info.channelWidth);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: info == null
            ? Row(
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 18, color: tokens.textDisabled),
                  const SizedBox(width: 8),
                  Text(strings.homeNotConnectedWifi,
                      style: text.bodyMedium
                          ?.copyWith(color: tokens.textSecondary)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi_rounded, size: 18, color: tokens.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          info.ssid.isEmpty ? '--' : info.ssid,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${info.rssi} dBm',
                        style: text.bodyMedium?.copyWith(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _kv(text, strings.cellBandShort,
                          info.frequency >= 5000 ? '5G' : '2.4G'),
                      _kv(text, '信道', channel == 0 ? '--' : '$channel'),
                      if (standard.isNotEmpty)
                        _kv(text, strings.cellRat, standard),
                      if (width.isNotEmpty) _kv(text, '带宽', width),
                      if (info.linkSpeed > 0)
                        _kv(text, '速率', '${info.linkSpeed} Mbps'),
                      if (info.bssid.isNotEmpty)
                        _kv(text, 'MAC', info.bssid),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _kv(TextTheme text, String key, String value) => RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$key ',
              style: text.labelSmall?.copyWith(color: tokens.textDisabled),
            ),
            TextSpan(
              text: value,
              style: text.labelSmall?.copyWith(
                color: tokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

// ---------- 信号历史 ----------

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.history,
    required this.tokens,
    required this.text,
  });

  final List<double> history;
  final AppTokens tokens;
  final TextTheme text;

  List<Color> get palette => <Color>[
        tokens.accent,
        tokens.success,
        tokens.warning,
        tokens.highlight,
        tokens.danger,
      ];

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '信号强度（dBm）',
                  style: text.labelMedium?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  history.isEmpty ? '--' : '${history.last.round()} dBm',
                  style: text.labelSmall?.copyWith(color: tokens.textSecondary),
                ),
                if (history.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _SignalBadge(db: history.last, tokens: tokens, text: text),
                ],
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 90,
              width: double.infinity,
              child: history.length < 2
                  ? Center(
                      child: Text(
                        '采样中',
                        style: text.labelSmall
                            ?.copyWith(color: tokens.textDisabled),
                      ),
                    )
                  : CustomPaint(
                      painter: _SignalPainter(
                        values: history,
                        color: tokens.accent,
                        gridColor: tokens.outlineSoft,
                        labelColor: tokens.textDisabled,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('60 秒前',
                    style:
                        text.labelSmall?.copyWith(color: tokens.textDisabled)),
                Text('当前',
                    style:
                        text.labelSmall?.copyWith(color: tokens.textDisabled)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalPainter extends CustomPainter {
  _SignalPainter({
    required List<double> values,
    required this.color,
    required this.gridColor,
    required this.labelColor,
  }) : values = List<double>.unmodifiable(values);

  final List<double> values;
  final Color color;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const minDb = -95.0;
    const maxDb = -25.0;
    const leftPad = 30.0;
    final chartWidth = size.width - leftPad;

    double yOf(double db) =>
        size.height * ((maxDb - db.clamp(minDb, maxDb)) / (maxDb - minDb));

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );
    for (final db in <double>[-40, -60, -80]) {
      final y = yOf(db);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), grid);
      tp
        ..text = TextSpan(
          text: '${db.toInt()}',
          style: TextStyle(color: labelColor, fontSize: 9),
        )
        ..layout();
      tp.paint(
        canvas,
        Offset(leftPad - tp.width - 4, y - tp.height / 2),
      );
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = leftPad + chartWidth * (i / (values.length - 1));
      final y = yOf(values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SignalPainter old) {
    if (old.color != color) return true;
    if (old.values.length != values.length) return true;
    if (values.isEmpty) return false;
    return old.values.last != values.last;
  }
}

// ---------- 信道图 ----------

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.results,
    required this.band,
    required this.onBandChanged,
    required this.tokens,
    required this.text,
  });

  final List<WifiScanResult> results;
  final int band;
  final ValueChanged<int> onBandChanged;
  final AppTokens tokens;
  final TextTheme text;

  List<Color> get palette => <Color>[
        tokens.accent,
        tokens.success,
        tokens.warning,
        tokens.highlight,
        tokens.danger,
      ];

  @override
  Widget build(BuildContext context) {
    final filtered = results
        .where((r) => band == 0 ? !_is5g(r.frequency) : _is5g(r.frequency))
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '信道',
                  style: text.labelMedium?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: 0, label: Text('2.4G')),
                    ButtonSegment(value: 1, label: Text('5G')),
                  ],
                  selected: {band},
                  onSelectionChanged: (value) => onBandChanged(value.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              width: double.infinity,
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        '该频段未发现热点',
                        style: text.labelSmall
                            ?.copyWith(color: tokens.textDisabled),
                      ),
                    )
                  : CustomPaint(
                      painter: _ChannelPainter(
                        results: filtered,
                        is5g: band == 1,
                        gridColor: tokens.outlineSoft,
                        labelColor: tokens.textDisabled,
                        palette: <Color>[
                          tokens.accent,
                          tokens.success,
                          tokens.warning,
                          tokens.highlight,
                          tokens.danger,
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelPainter extends CustomPainter {
  _ChannelPainter({
    required this.results,
    required this.is5g,
    required this.gridColor,
    required this.labelColor,
    required this.palette,
  });

  final List<WifiScanResult> results;
  final bool is5g;
  final Color gridColor;
  final Color labelColor;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    const minDb = -100.0;
    const maxDb = -20.0;
    const leftPad = 30.0;
    final chartWidth = size.width - leftPad;

    double yOf(double db) =>
        size.height * ((maxDb - db.clamp(minDb, maxDb)) / (maxDb - minDb));

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    for (final db in <double>[-40, -60, -80]) {
      final y = yOf(db);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), grid);
      textPainter
        ..text = TextSpan(
          text: '${db.toInt()}',
          style: TextStyle(color: labelColor, fontSize: 9),
        )
        ..layout();
      textPainter.paint(
        canvas,
        Offset(leftPad - textPainter.width - 4, y - textPainter.height / 2),
      );
    }

    // 只画最强的 10 个
    final sorted = List<WifiScanResult>.of(results)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    final shown = sorted.take(10).toList();

    // 横轴范围跟着实际信道走：5G 只有 36~48 时也能铺开
    final channels = shown
        .map((ap) => _channelOf(ap.frequency))
        .where((c) => c > 0)
        .toList();
    double minChannel;
    double maxChannel;
    if (channels.isEmpty) {
      minChannel = is5g ? 36.0 : 1.0;
      maxChannel = is5g ? 48.0 : 13.0;
    } else {
      minChannel = (channels.reduce((a, b) => a < b ? a : b) - 3).toDouble();
      maxChannel = (channels.reduce((a, b) => a > b ? a : b) + 3).toDouble();
    }
    if (maxChannel - minChannel < 6) maxChannel = minChannel + 6;

    double xOf(double channel) =>
        leftPad +
        chartWidth * ((channel - minChannel) / (maxChannel - minChannel));

    var labelLane = 0;
    for (var i = 0; i < shown.length; i++) {
      final ap = shown[i];
      final channel = _channelOf(ap.frequency).toDouble();
      if (channel <= 0) continue;
      final color = palette[i % palette.length];
      final halfWidth = is5g ? 3.0 : 2.5;
      final top = ap.rssi.toDouble();
      final bottom = yOf(minDb);

      final left = (channel - halfWidth).clamp(minChannel, maxChannel);
      final right = (channel + halfWidth).clamp(minChannel, maxChannel);
      if (right - left < 0.3) continue;

      final apexX = xOf(channel);
      final apexY = yOf(top);

      final curve = Path()
        ..moveTo(xOf(left), bottom)
        ..quadraticBezierTo(
          xOf(channel - halfWidth * 0.55),
          apexY,
          apexX,
          apexY,
        )
        ..quadraticBezierTo(
          xOf(channel + halfWidth * 0.55),
          apexY,
          xOf(right),
          bottom,
        );

      final fill = Path.from(curve)
        ..lineTo(xOf(right), bottom)
        ..lineTo(xOf(left), bottom)
        ..close();
      canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.07));
      canvas.drawPath(
        curve,
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );

      // 顶点标注 SSID：交替上下错开，减少重叠
      final label =
          ap.ssid.length > 8 ? '${ap.ssid.substring(0, 8)}…' : ap.ssid;
      if (label.isNotEmpty) {
        final tp = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: label,
            style: TextStyle(color: color, fontSize: 8.5),
          ),
        )..layout();
        final offset = (labelLane % 3) * 10.0;
        labelLane++;
        final labelY = (apexY - 10 - offset).clamp(0.0, size.height - 10);
        final labelX =
            (apexX - tp.width / 2).clamp(leftPad, size.width - tp.width);
        tp.paint(canvas, Offset(labelX, labelY));
      }
    }

    // 底部信道刻度
    final tick = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final chPainter = TextPainter(textDirection: TextDirection.ltr);
    final span = maxChannel - minChannel;
    final stepChannels = is5g
        ? (span > 60 ? 16 : (span > 24 ? 8 : 4))
        : (span > 12 ? 2 : 1);
    for (var ch = minChannel.ceil(); ch <= maxChannel; ch += stepChannels) {
      if (ch < 1) continue;
      final x = xOf(ch.toDouble());
      canvas.drawLine(
        Offset(x, size.height - 3),
        Offset(x, size.height),
        tick,
      );
      chPainter
        ..text = TextSpan(
          text: '$ch',
          style: TextStyle(color: labelColor, fontSize: 8),
        )
        ..layout();
      chPainter.paint(
        canvas,
        Offset(x - chPainter.width / 2, size.height - chPainter.height),
      );
    }
  }

  @override
  bool shouldRepaint(_ChannelPainter old) =>
      old.results != results || old.is5g != is5g;
}

// ---------- 热点列表 ----------

class _ApListCard extends StatelessWidget {
  const _ApListCard({
    required this.results,
    required this.band,
    required this.tokens,
    required this.text,
  });

  final List<WifiScanResult> results;
  final int band;
  final AppTokens tokens;
  final TextTheme text;

  List<Color> get palette => <Color>[
        tokens.accent,
        tokens.success,
        tokens.warning,
        tokens.highlight,
        tokens.danger,
      ];

  @override
  Widget build(BuildContext context) {
    final filtered = results
        .where((r) => band == 0 ? !_is5g(r.frequency) : _is5g(r.frequency))
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                Text(
                  '热点列表',
                  style: text.labelMedium?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} 个',
                  style: text.labelSmall?.copyWith(color: tokens.textDisabled),
                ),
              ],
            ),
          ),
          for (var i = 0; i < filtered.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: tokens.outlineSoft),
            _ApRow(
              ap: filtered[i],
              color: i < 6 ? palette[i % palette.length] : null,
              tokens: tokens,
              text: text,
            ),
          ],
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Text(
                '未发现热点',
                style: text.labelSmall?.copyWith(color: tokens.textDisabled),
              ),
            ),
        ],
      ),
    );
  }
}

class _ApRow extends StatelessWidget {
  const _ApRow({
    this.color,
    required this.ap,
    required this.tokens,
    required this.text,
  });

  final WifiScanResult ap;

  /// 与信道图曲线一致的颜色；null 表示不在图上
  final Color? color;
  final AppTokens tokens;
  final TextTheme text;

  List<Color> get palette => <Color>[
        tokens.accent,
        tokens.success,
        tokens.warning,
        tokens.highlight,
        tokens.danger,
      ];

  @override
  Widget build(BuildContext context) {
    final channel = _channelOf(ap.frequency);
    final standard = _standardName(ap.standard);
    final width = _widthName(ap.channelWidth);
    final secure = ap.capabilities.contains('WPA') ||
        ap.capabilities.contains('WEP') ||
        ap.capabilities.contains('EAP');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Icon(
            secure ? Icons.lock_rounded : Icons.lock_open_rounded,
            size: 14,
            color: tokens.textDisabled,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ap.ssid.isEmpty ? '(隐藏网络)' : ap.ssid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  ap.bssid,
                  style: text.labelSmall?.copyWith(
                    color: tokens.textDisabled,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${ap.rssi} dBm',
                style: text.bodyMedium?.copyWith(
                  color: ap.rssi > -60
                      ? tokens.success
                      : (ap.rssi > -75 ? tokens.warning : tokens.danger),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                [
                  'CH$channel',
                  if (width.isNotEmpty) width,
                  if (standard.isNotEmpty) standard,
                ].join(' · '),
                style: text.labelSmall?.copyWith(color: tokens.textDisabled),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 信号评级胶囊：把 dBm 换成可读的等级 + 颜色。
class _SignalBadge extends StatelessWidget {
  const _SignalBadge({
    required this.db,
    required this.tokens,
    required this.text,
  });

  final double db;
  final AppTokens tokens;
  final TextTheme text;

  List<Color> get palette => <Color>[
        tokens.accent,
        tokens.success,
        tokens.warning,
        tokens.highlight,
        tokens.danger,
      ];

  (String, Color) get _level {
    if (db >= -50) return ('极佳', tokens.success);
    if (db >= -60) return ('优良', tokens.success);
    if (db >= -70) return ('良好', tokens.warning);
    if (db >= -80) return ('中', tokens.warning);
    if (db >= -90) return ('差', tokens.danger);
    return ('极差', tokens.danger);
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _level;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: text.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------- 信道评估 ----------

/// 计算某个信道被占用的程度（0~100）。
/// 同信道 AP 权重最高，相邻信道按重叠比例衰减。
double _channelScore(
  int channel,
  List<WifiScanResult> aps,
  bool is5g,
) {
  var score = 0.0;
  for (final ap in aps) {
    final apChannel = _channelOf(ap.frequency);
    if (apChannel == 0) continue;
    final distance = (apChannel - channel).abs();
    final double overlap;
    if (distance == 0) {
      overlap = 1.0;
    } else if (distance <= 2) {
      overlap = is5g ? 0.35 : 0.6;
    } else if (distance <= 4) {
      overlap = is5g ? 0.15 : 0.25;
    } else {
      continue;
    }
    // 信号越强影响越大（-90dBm 约 0.14，-40dBm 约 0.86）
    final strength = ((ap.rssi + 100) / 70).clamp(0.1, 1.0);
    score += overlap * strength * 38;
  }
  return score.clamp(0, 100);
}

class _ChannelScoreCard extends StatelessWidget {
  const _ChannelScoreCard({
    required this.results,
    required this.band,
    required this.tokens,
    required this.text,
  });

  final List<WifiScanResult> results;
  final int band;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final is5g = band == 1;
    final aps = results
        .where((r) => is5g ? _is5g(r.frequency) : !_is5g(r.frequency))
        .toList();
    if (aps.isEmpty) {
      return const SizedBox.shrink();
    }

    // 常用信道（5G 只看非 DFS 的常用段）
    final candidates = is5g
        ? <int>[36, 40, 44, 48, 149, 153, 157, 161, 165]
        : <int>[1, 3, 6, 9, 11, 13];
    final scored = <(int, double)>[
      for (final ch in candidates) (ch, _channelScore(ch, aps, is5g)),
    ];

    final best = scored.reduce((a, b) => a.$2 <= b.$2 ? a : b);
    final worst = scored.reduce((a, b) => a.$2 >= b.$2 ? a : b);
    final maxScore = worst.$2 == 0 ? 1.0 : worst.$2;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '信道评估',
                  style: text.labelMedium?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '数值越低表示占用越少',
                  style: text.labelSmall?.copyWith(color: tokens.textDisabled),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final (channel, score) in scored) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        'CH$channel',
                        style: text.labelSmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: (score / maxScore).clamp(0.0, 1.0),
                          minHeight: 7,
                          backgroundColor: tokens.track,
                          color: score < 20
                              ? tokens.success
                              : (score < 45 ? tokens.warning : tokens.danger),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${score.round()}',
                        textAlign: TextAlign.right,
                        style: text.labelSmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 14, color: tokens.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '建议使用 CH${best.$1}（占用最低，评分 ${best.$2.round()}）',
                    style: text.labelSmall?.copyWith(
                      color: tokens.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- 网络质量 ----------

class _QualityCard extends StatelessWidget {
  const _QualityCard({
    required this.current,
    required this.results,
    required this.tokens,
    required this.text,
    required this.onPingGateway,
    required this.onPortScan,
    this.gateway,
  });

  final WifiInfo? current;
  final List<WifiScanResult> results;
  final AppTokens tokens;
  final TextTheme text;
  final ValueChanged<String> onPingGateway;
  final ValueChanged<String> onPortScan;

  final String? gateway;

  @override
  Widget build(BuildContext context) {
    final info = current;
    if (info == null) return const SizedBox.shrink();

    final channel = _channelOf(info.frequency);
    final is5g = info.frequency >= 5000;
    final aps = results
        .where((r) => is5g ? _is5g(r.frequency) : !_is5g(r.frequency))
        .toList();
    final congestion = _channelScore(channel, results, is5g);

    // 综合评分：信号 60 + 速率 20 + 拥挤度 20
    final signalScore = ((info.rssi + 95) / 60).clamp(0.0, 1.0) * 60;
    final speedScore = (info.linkSpeed / 800).clamp(0.0, 1.0) * 20;
    final freeScore = (1 - congestion / 100) * 20;
    final total = (signalScore + speedScore + freeScore).round().clamp(0, 100);

    final (label, color) = total >= 80
        ? ('优秀', tokens.success)
        : total >= 60
            ? ('良好', tokens.warning)
            : (total >= 40 ? ('一般', tokens.warning) : ('较差', tokens.danger));

    final sameChannel = aps.where((ap) {
      return _channelOf(ap.frequency) == channel && ap.bssid != info.bssid;
    }).length;

    final suggestions = <String>[
      if (info.rssi < -70) '信号偏弱，尽量靠近路由器或换 5G 频段',
      if (sameChannel >= 3)
        '同信道有 $sameChannel 个邻居，路由器可考虑换到更空的信道',
      if (!is5g && aps.length >= 5) '2.4G 干扰较多，优先连接 5G',
      if (info.linkSpeed > 0 && info.linkSpeed < 150 && info.rssi > -60)
        '链路速率偏低，可能被同频设备拖累',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '网络质量',
                  style: text.labelMedium?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '$total',
                  style: text.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    label,
                    style: text.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: total / 100,
                minHeight: 6,
                backgroundColor: tokens.track,
                color: color,
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final s in suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 5, color: tokens.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s,
                          style: text.labelSmall
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onPingGateway(
                      gateway ?? '192.168.1.1',
                    ),
                    icon: const Icon(Icons.network_ping_rounded, size: 16),
                    label: const Text('网关 Ping'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onPortScan(
                      gateway ?? '192.168.1.1',
                    ),
                    icon: const Icon(Icons.radar_rounded, size: 16),
                    label: const Text('网关端口扫描'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

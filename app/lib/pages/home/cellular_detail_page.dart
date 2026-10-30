import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/system_service.dart';
import '../../widgets/settings_action.dart';
import '../../widgets/sparkline.dart';

/// 蜂窝详情：卡槽卡片置顶横排，点击切换；下方是该卡的服务小区 / 信号 / 邻区。
class CellularDetailPage extends StatefulWidget {
  const CellularDetailPage({super.key});

  @override
  State<CellularDetailPage> createState() => _CellularDetailPageState();
}

class _CellularDetailPageState extends State<CellularDetailPage> {
  List<CellularInfo> _cells = const <CellularInfo>[];
  int _selected = 0;
  bool _loading = true;
  Timer? _timer;

  // 位置信息（默认遮罩隐藏）
  LocationInfo? _location;
  bool _revealLocation = false;

  // 信号曲线（每秒一个 RSRP 采样，1 分钟窗口）
  static const int _seriesLength = 60;
  final List<double> _rsrpSeries = <double>[];

  @override
  void initState() {
    super.initState();
    _load();
    _loadLocation();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    final granted = await SystemService.hasLocationPermission();
    if (!granted) return;
    final info = await SystemService.locationInfo();
    if (!mounted) return;
    setState(() => _location = info);
  }

  Future<void> _load({bool silent = false}) async {
    final cells = await SystemService.cellularInfo();
    if (!mounted) return;
    final selected = _selected >= cells.length
        ? (cells.isEmpty ? 0 : cells.length - 1)
        : _selected;
    final current = cells.isEmpty ? null : cells[selected];
    final rsrp = current?.primaryRsrp;
    if (rsrp != null) {
      _rsrpSeries.add(rsrp.toDouble());
      if (_rsrpSeries.length > _seriesLength) {
        _rsrpSeries.removeRange(0, _rsrpSeries.length - _seriesLength);
      }
    }
    setState(() {
      _cells = cells;
      _selected = selected;
      if (!silent) _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final current = _cells.isEmpty ? null : _cells[_selected];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).cellTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).commonRefresh,
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SettingsAction(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cells.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      AppStrings.of(context).cellNoSim,
                      textAlign: TextAlign.center,
                      style: text.bodyMedium
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                  ),
                )
              : Column(
                  children: [
                    // 卡槽卡片：双卡时并排置顶，点击切换
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          for (var i = 0; i < _cells.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(
                              child: _SlotCard(
                                info: _cells[i],
                                selected: i == _selected,
                                tokens: tokens,
                                text: text,
                                onTap: () {
                                  setState(() {
                                    _selected = i;
                                    _rsrpSeries.clear();
                                  });
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          if (current != null) ...[
                            _SectionTitle(AppStrings.of(context).cellCarrier, tokens, text),
                            Card(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                child: Column(
                                  children: [
                                    _KvRow(
                                      label: AppStrings.of(context).cellSimCarrier,
                                      value: current.carrier.isNotEmpty
                                          ? current.carrier
                                          : current.operatorName,
                                      tokens: tokens,
                                      text: text,
                                    ),
                                    _KvRow(
                                      label: AppStrings.of(context).cellNetwork,
                                      value: _networkTypeLabel(
                                          current.networkType),
                                      tokens: tokens,
                                      text: text,
                                    ),
                                    _KvRow(
                                      label: 'MCC',
                                      value: current.mcc ?? '-',
                                      tokens: tokens,
                                      text: text,
                                    ),
                                    _KvRow(
                                      label: 'MNC',
                                      value: current.mnc ?? '-',
                                      tokens: tokens,
                                      text: text,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _SectionTitle(AppStrings.of(context).cellServing, tokens, text),
                            Card(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                child: Column(
                                  children: [
                                    _KvRow(
                                      label: AppStrings.of(context).cellDataNet,
                                      value: current.cellTypeLabel,
                                      tokens: tokens,
                                      text: text,
                                    ),
                                    _KvRow(
                                      label: 'TAC',
                                      value: current.tac?.toString() ?? '-',
                                      tokens: tokens,
                                      text: text,
                                    ),
                                    _KvRow(
                                      label: 'PCI',
                                      value: current.pci?.toString() ?? '-',
                                      tokens: tokens,
                                      text: text,
                                    ),
                                    _KvRow(
                                      label: AppStrings.of(context).cellCellId,
                                      value: current.cellId?.toString() ?? '-',
                                      tokens: tokens,
                                      text: text,
                                    ),
                                    _KvRow(
                                      label: 'ARFCN',
                                      value: current.arfcn?.toString() ?? '-',
                                      tokens: tokens,
                                      text: text,
                                    ),
                                    _KvRow(
                                      label: AppStrings.of(context).cellBand,
                                      value: current.band == null
                                          ? '-'
                                          : 'n${current.band}',
                                      tokens: tokens,
                                      text: text,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _SectionTitle(AppStrings.of(context).cellSignal, tokens, text),
                            Card(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 14, 16, 14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _Metric(
                                          label: 'SS-RSRP',
                                          value: current.primaryRsrp == null
                                              ? '-'
                                              : '${current.primaryRsrp}',
                                          unit: 'dBm',
                                          tokens: tokens,
                                          text: text,
                                        ),
                                        const SizedBox(width: 12),
                                        _Metric(
                                          label: 'RSRQ',
                                          value: current.primaryRsrq == null
                                              ? '-'
                                              : '${current.primaryRsrq}',
                                          unit: 'dB',
                                          tokens: tokens,
                                          text: text,
                                        ),
                                        const SizedBox(width: 12),
                                        _Metric(
                                          label: 'SINR',
                                          value: current.primarySinr == null
                                              ? '-'
                                              : '${current.primarySinr}',
                                          unit: 'dB',
                                          tokens: tokens,
                                          text: text,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (_rsrpSeries.length >= 2)
                                      Sparkline(
                                        values: _rsrpSeries,
                                        height: 56,
                                        color: tokens.highlight,
                                        fill: true,
                                      )
                                    else
                                      SizedBox(
                                        height: 56,
                                        child: Center(
                                          child: Text(
                                            AppStrings.of(context).cellSampling,
                                            style: text.bodySmall?.copyWith(
                                                color: tokens.textDisabled),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          AppStrings.of(context).cellMinute,
                                          style: text.labelSmall?.copyWith(
                                              color: tokens.textDisabled),
                                        ),
                                        const Spacer(),
                                        Text(
                                          AppStrings.of(context).cellNow,
                                          style: text.labelSmall?.copyWith(
                                              color: tokens.textDisabled),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _SectionTitle(
                                '邻小区（${current.neighbors.length}）',
                                tokens,
                                text),
                            Card(
                              child: current.neighbors.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        AppStrings.of(context).cellNoNeighbors,
                                        style: text.bodySmall?.copyWith(
                                            color: tokens.textSecondary),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        _NeighborHeader(
                                            tokens: tokens, text: text),
                                        const Divider(height: 1),
                                        for (final neighbor
                                            in current.neighbors)
                                          _NeighborRow(
                                            neighbor: neighbor,
                                            tokens: tokens,
                                            text: text,
                                          ),
                                      ],
                                    ),
                            ),
                            _SectionTitle(AppStrings.of(context).cellLocation, tokens, text),
                            _LocationSection(
                              info: _location,
                              revealed: _revealLocation,
                              tokens: tokens,
                              text: text,
                              onToggle: () => setState(
                                  () => _revealLocation = !_revealLocation),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  String _networkTypeLabel(int? type) {
    if (type == null) return '未知';
    switch (type) {
      case 13:
        return 'LTE';
      case 20:
        return '5G NR';
      case 2:
        return 'EDGE';
      case 3:
        return 'UMTS';
      case 4:
        return 'CDMA';
      case 1:
        return 'GPRS';
      case 16:
        return 'GSM';
      default:
        return '类型 $type';
    }
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.info,
    required this.revealed,
    required this.tokens,
    required this.text,
    required this.onToggle,
  });

  final LocationInfo? info;
  final bool revealed;
  final AppTokens tokens;
  final TextTheme text;
  final VoidCallback onToggle;

  String _mask(String value) => revealed ? value : '••••••';

  String _providerLabel(BuildContext context, String provider) => switch (provider) {
        'gps' => 'GPS',
        'network' => AppStrings.of(context).cellNetLocate,
        'passive' => AppStrings.of(context).cellPassive,
        '' => AppStrings.of(context).commonUnknown,
        _ => provider,
      };

  String _fmtTime(DateTime time) {
    if (time.millisecondsSinceEpoch == 0) return '未知';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final data = info;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(Icons.location_on_outlined, color: tokens.accent),
        title: Text(
          AppStrings.of(context).cellViewLocation,
          style: text.bodyLarge?.copyWith(color: tokens.textPrimary),
        ),
        subtitle: Text(
          revealed ? '已显示真实坐标' : AppStrings.of(context).cellMasked,
          style: text.bodySmall?.copyWith(color: tokens.textSecondary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (data == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                AppStrings.of(context).cellNoLocation,
                style: text.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
            )
          else ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  revealed
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 18,
                ),
                label: Text(revealed ? '隐藏' : '显示'),
              ),
            ),
            _KvRow(
              label: AppStrings.of(context).cellLatitude,
              value: _mask(data.lat.toStringAsFixed(6)),
              tokens: tokens,
              text: text,
            ),
            _KvRow(
              label: AppStrings.of(context).cellLongitude,
              value: _mask(data.lng.toStringAsFixed(6)),
              tokens: tokens,
              text: text,
            ),
            _KvRow(
              label: AppStrings.of(context).cellAccuracy,
              value: _mask('±${data.accuracy.toStringAsFixed(1)} m'),
              tokens: tokens,
              text: text,
            ),
            _KvRow(
              label: AppStrings.of(context).cellAltitude,
              value: _mask('${data.altitude.toStringAsFixed(1)} m'),
              tokens: tokens,
              text: text,
            ),
            _KvRow(
              label: '速度',
              value:
                  _mask('${(data.speed * 3.6).toStringAsFixed(1)} km/h'),
              tokens: tokens,
              text: text,
            ),
            _KvRow(
              label: AppStrings.of(context).cellSource,
              value: _mask(_providerLabel(context, data.provider)),
              tokens: tokens,
              text: text,
            ),
            _KvRow(
              label: AppStrings.of(context).cellUpdatedAt,
              value: _mask(_fmtTime(data.time)),
              tokens: tokens,
              text: text,
            ),
          ],
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.info,
    required this.selected,
    required this.tokens,
    required this.text,
    required this.onTap,
  });

  final CellularInfo info;
  final bool selected;
  final AppTokens tokens;
  final TextTheme text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? tokens.accentSoft : tokens.surfaceCard,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '卡槽 ${info.slot}',
                    style: text.labelMedium?.copyWith(
                      color:
                          selected ? tokens.onAccentSoft : tokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${info.percent}%',
                    style: text.labelMedium?.copyWith(
                      color: selected ? tokens.onAccentSoft : tokens.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                info.carrier.isNotEmpty ? info.carrier : AppStrings.of(context).cellNoCarrier,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  color: selected ? tokens.onAccentSoft : tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                info.primaryRsrp == null
                    ? '${info.cellTypeLabel} · 无信号数据'
                    : '${info.cellTypeLabel} · ${info.primaryRsrp} dBm',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(
                  color: selected ? tokens.onAccentSoft : tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, this.tokens, this.text);

  final String label;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 14),
      child: Text(
        label,
        style: text.titleSmall?.copyWith(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.unit,
    required this.tokens,
    required this.text,
  });

  final String label;
  final String value;
  final String unit;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.labelSmall?.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: text.titleMedium?.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: text.labelSmall?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NeighborHeader extends StatelessWidget {
  const _NeighborHeader({required this.tokens, required this.text});

  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    Widget cell(String value, int flex) => Expanded(
          flex: flex,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(color: tokens.textSecondary),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          cell(AppStrings.of(context).cellRat, 3),
          cell(AppStrings.of(context).cellBand, 3),
          cell('PCI', 3),
          cell('RSRP', 4),
          cell('RSRQ', 3),
          cell('SINR', 3),
        ],
      ),
    );
  }
}

class _NeighborRow extends StatelessWidget {
  const _NeighborRow({
    required this.neighbor,
    required this.tokens,
    required this.text,
  });

  final CellNeighbor neighbor;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    Widget cell(String value, int flex) => Expanded(
          flex: flex,
          child: Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: tokens.textPrimary),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          cell(neighbor.type, 3),
          cell(neighbor.band == null ? '-' : 'n${neighbor.band}', 3),
          cell(neighbor.pci?.toString() ?? '-', 3),
          cell(neighbor.rsrp?.toString() ?? '-', 4),
          cell(neighbor.rsrq?.toString() ?? '-', 3),
          cell(neighbor.sinr?.toString() ?? '-', 3),
        ],
      ),
    );
  }
}
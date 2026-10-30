import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../widgets/settings_action.dart';
import '../home/lan_scan_page.dart';
import 'dns_lookup_page.dart';
import 'geo_ping_page.dart';
import 'iperf_page.dart';
import 'ip_calculator_page.dart';
import 'monitor_page.dart';
import 'multi_ping_page.dart';
import 'ping_page.dart';
import 'port_scan_page.dart';
import 'speed_test_page.dart';
import 'traceroute_page.dart';
import 'upnp_page.dart';
import 'whois_page.dart';
import 'wol_page.dart';

/// 工具：分组列表，组内可长按拖动排序（顺序持久化）。
class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  static const String _orderPrefix = 'tools.order.';

  /// 每个分组内的自定义顺序（工具标题列表）
  final Map<String, List<String>> _orders = <String, List<String>>{};

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, List<String>>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_orderPrefix)) continue;
      map[key.substring(_orderPrefix.length)] =
          prefs.getStringList(key) ?? const <String>[];
    }
    if (!mounted) return;
    setState(() {
      _orders
        ..clear()
        ..addAll(map);
    });
  }

  List<_ToolItem> _sorted(String group, List<_ToolItem> items) {
    final order = _orders[group];
    if (order == null || order.isEmpty) return items;
    final remaining = <String, _ToolItem>{
      for (final item in items) item.title: item,
    };
    final sorted = <_ToolItem>[];
    for (final title in order) {
      final item = remaining.remove(title);
      if (item != null) sorted.add(item);
    }
    // 顺序表里没有的（新版本新增的工具）追加到末尾
    sorted.addAll(remaining.values);
    return sorted;
  }

  Future<void> _reorder(
    String group,
    List<_ToolItem> items,
    int oldIndex,
    int newIndex,
  ) async {
    // onReorderItem 已经处理过索引偏移
    final list = List<_ToolItem>.of(items);
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    setState(() {
      _orders[group] = list.map((item) => item.title).toList();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_orderPrefix$group', _orders[group]!);
  }

  @override
  Widget build(BuildContext context) {
    final groups = <(String, List<_ToolItem>)>[
      (
        AppStrings.of(context).groupDiagnostics,
        <_ToolItem>[
          _ToolItem(
            Icons.network_ping_rounded,
            'Ping',
            AppStrings.of(context).toolPingSub,
            builder: (_) => const PingPage(),
          ),
          _ToolItem(
            Icons.playlist_play_rounded,
            AppStrings.of(context).toolMultiPing,
            AppStrings.of(context).toolMultiPingSub,
            builder: (_) => const MultiPingPage(),
          ),
          _ToolItem(
            Icons.monitor_heart_outlined,
            AppStrings.of(context).toolMonitor,
            AppStrings.of(context).toolMonitorSub,
            builder: (_) => const MonitorPage(),
          ),
          _ToolItem(
            Icons.public_rounded,
            'GeoPing',
            AppStrings.of(context).toolGeoPingSub,
            builder: (_) => const GeoPingPage(),
          ),
          _ToolItem(
            Icons.route_rounded,
            'Traceroute',
            AppStrings.of(context).toolTracerouteSub,
            builder: (_) => const TraceroutePage(),
          ),
          _ToolItem(
            Icons.radar_rounded,
            AppStrings.of(context).toolPortScan,
            AppStrings.of(context).toolPortScanSub,
            builder: (_) => const PortScanPage(),
          ),
          _ToolItem(
            Icons.badge_rounded,
            'Whois',
            AppStrings.of(context).toolWhoisSub,
            builder: (_) => const WhoisPage(),
          ),
          _ToolItem(
            Icons.dns_rounded,
            'DNS Lookup',
            AppStrings.of(context).toolDnsSub,
            builder: (_) => const DnsLookupPage(),
          ),
        ],
      ),
      (
        AppStrings.of(context).groupPerformance,
        <_ToolItem>[
          _ToolItem(
            Icons.speed_rounded,
            'iperf',
            AppStrings.of(context).toolIperfSub,
            builder: (_) => const IperfPage(),
          ),
          _ToolItem(
            Icons.download_rounded,
            AppStrings.of(context).toolSpeed,
            AppStrings.of(context).toolSpeedSub,
            builder: (_) => const SpeedTestPage(),
          ),
        ],
      ),
      (
        AppStrings.of(context).groupLan,
        <_ToolItem>[
          _ToolItem(
            Icons.lan_rounded,
            AppStrings.of(context).toolSubnet,
            AppStrings.of(context).toolSubnetSub,
            builder: (_) => const LanScanPage(),
          ),
          _ToolItem(
            Icons.cast_connected_rounded,
            AppStrings.of(context).toolUpnp,
            AppStrings.of(context).toolUpnpSub,
            builder: (_) => const UpnpScanPage(),
          ),
          _ToolItem(
            Icons.power_settings_new_rounded,
            AppStrings.of(context).toolWol,
            AppStrings.of(context).toolWolSub,
            builder: (_) => const WolPage(),
          ),
        ],
      ),
      (
        AppStrings.of(context).groupCompute,
        <_ToolItem>[
          _ToolItem(
            Icons.calculate_rounded,
            AppStrings.of(context).toolIpCalc,
            AppStrings.of(context).toolIpCalcSub,
            builder: (_) => const IpCalculatorPage(),
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).toolsTitle),
        actions: const [SettingsAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          for (final (title, items) in groups)
            _ToolGroup(
              title: title,
              items: _sorted(title, items),
              onReorder: (oldIndex, newIndex) =>
                  _reorder(title, items, oldIndex, newIndex),
            ),
        ],
      ),
    );
  }
}

class _ToolItem {
  const _ToolItem(
    this.icon,
    this.title,
    this.subtitle, {
    this.builder,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// 有 builder 说明该工具已实现，点击进入；否则提示待实现
  final Widget Function(BuildContext context)? builder;
}

class _ToolGroup extends StatelessWidget {
  const _ToolGroup({
    required this.title,
    required this.items,
    required this.onReorder,
  });

  final String title;
  final List<_ToolItem> items;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: text.labelMedium?.copyWith(
                color: tokens.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              // 拖动时用圆角容器包裹，默认是直角 + 灰底
              proxyDecorator: (child, index, animation) => Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  ),
              itemCount: items.length,
              onReorderItem: onReorder,
              itemBuilder: (context, i) {
                final item = items[i];
                return Column(
                  key: ValueKey('$title::${item.title}'),
                  children: [
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 60,
                        color: tokens.outlineSoft,
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: _ToolRow(
                            item: item,
                            tokens: tokens,
                            text: text,
                          ),
                        ),
                        // 拖拽手柄：按住它上下拖，避免和点击冲突
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(2, 0, 10, 0),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              size: 18,
                              color: tokens.textDisabled,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.item,
    required this.tokens,
    required this.text,
  });

  final _ToolItem item;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final ready = item.builder != null;
    final iconColor = ready ? tokens.accent : tokens.textDisabled;
    return InkWell(
      onTap: () {
        final builder = item.builder;
        if (builder != null) {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.of(context).toolTodoTemplate.replaceAll('{name}', item.title))),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 0, 9),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(item.icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: ready ? tokens.textPrimary : tokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        text.labelSmall?.copyWith(color: tokens.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

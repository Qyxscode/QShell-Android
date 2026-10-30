import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/qshell_config.dart';
import '../../services/tools/ping_service.dart';
import '../../widgets/sparkline.dart';
import 'ping_page.dart';
import 'traceroute_page.dart';

/// 监视节点。
class MonitorNode {
  const MonitorNode({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
  });

  final String id;
  final String name;
  final String host;
  final int port;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'host': host,
        'port': port,
      };

  factory MonitorNode.fromJson(Map<String, dynamic> json) => MonitorNode(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        host: (json['host'] as String?) ?? '',
        port: (json['port'] as num?)?.toInt() ?? 443,
      );
}

/// 节点监视器：持久化一组节点，定时探测在线状态 / 延迟 / 丢包。
class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _NodeRuntime {
  _NodeRuntime(this.node, {this.configHost});

  final MonitorNode node;
  int sent = 0;
  int received = 0;
  Duration? lastRtt;
  bool? online;
  final List<double> series = <double>[];


  /// 非空表示来自桌面版「主机管理」配置，删除/编辑会写回配置
  final QShellHost? configHost;

  bool get fromConfig => configHost != null;
  int get lossPercent =>
      sent == 0 ? 0 : ((sent - received) * 100 / sent).round();
}

class _MonitorPageState extends State<MonitorPage> {
  static const _prefsKey = 'monitor.nodes';
  static const int _seriesLength = 40;

  final List<_NodeRuntime> _nodes = <_NodeRuntime>[];
  Timer? _timer;
  bool _monitoring = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const _selectedKey = 'monitor.selected';

  /// 用户勾选要监视的配置主机 id（cfg:host:port）
  Set<String> _selected = <String>{};

  Future<void> _load() async {
    final configStore = QShellConfigStore();
    final groups = await configStore.load();
    final prefs = await SharedPreferences.getInstance();

    // 收集全部配置主机
    final all = <(String id, QShellHost host)>[];
    for (final group in groups) {
      for (final host in group.hosts) {
        all.add(('cfg:${host.group}:${host.host}:${host.port}:${host.user}', host));
      }
    }

    // 没有选择记录时默认全选；有记录则按记录来
    final saved = prefs.getStringList(_selectedKey);
    if (saved == null) {
      _selected = all.map((item) => item.$1).toSet();
    } else {
      _selected = saved.toSet();
    }

    final configRuntimes = <_NodeRuntime>[
      for (final (id, host) in all)
        if (_selected.contains(id))
          _NodeRuntime(
            MonitorNode(
              id: id,
              name: host.name,
              host: host.host,
              port: host.port,
            ),
            configHost: host,
          ),
    ];

    final manualNodes = <MonitorNode>[];
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded.whereType<Map>()) {
          manualNodes.add(MonitorNode.fromJson(item.cast<String, dynamic>()));
        }
      } catch (_) {
        // 忽略坏数据
      }
    }

    if (!mounted) return;
    setState(() {
      _nodes
        ..clear()
        ..addAll(configRuntimes)
        ..addAll(manualNodes.map(_NodeRuntime.new));
      _loading = false;
    });
    if (_nodes.isNotEmpty && !_monitoring) _start();
  }

  /// 弹出选择框：勾选要监视的 SSH 主机（主机多时列表可滚动）
  Future<void> _chooseNodes() async {
    final configStore = QShellConfigStore();
    final groups = await configStore.load();
    if (!mounted) return;
    final all = <(String id, QShellHost host)>[];
    for (final group in groups) {
      for (final host in group.hosts) {
        all.add(('cfg:${host.group}:${host.host}:${host.port}:${host.user}', host));
      }
    }
    if (all.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(AppStrings.of(context).filesNoConnections)));
      return;
    }
    final selected = Set<String>.from(_selected);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppStrings.of(context).settingsSelectNodes),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: ListView(
              children: [
                for (final (id, host) in all)
                  CheckboxListTile(
                    dense: true,
                    value: selected.contains(id),
                    title: Text(host.name),
                    subtitle: Text('${host.host}:${host.port}'),
                    onChanged: (value) => setDialogState(() {
                      if (value == true) {
                        selected.add(id);
                      } else {
                        selected.remove(id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setDialogState(() {
                if (selected.length == all.length) {
                  selected.clear();
                } else {
                  selected
                    ..clear()
                    ..addAll(all.map((item) => item.$1));
                }
              }),
              child: Text(selected.length == all.length ? AppStrings.of(context).settingsSelectNone : AppStrings.of(context).settingsSelectAll),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context).commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: Text(AppStrings.of(context).commonConfirmBtn),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    _selected = result;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedKey, result.toList());
    await _load();
  }

  Future<void> _save() async {
    // 只持久化手动添加的节点；来自桌面版配置的每次启动重新读取
    final manual = _nodes
        .where((runtime) => !runtime.node.id.startsWith('cfg:'))
        .map((runtime) => runtime.node.toJson())
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(manual));
  }

  void _start() {
    if (_nodes.isEmpty) return;
    _timer?.cancel();
    setState(() => _monitoring = true);
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    setState(() => _monitoring = false);
  }

  Future<void> _tick() async {
    await Future.wait(_nodes.map(_probeOne));
  }

  Future<void> _probeOne(_NodeRuntime runtime) async {
    if (!mounted) return;
    try {
      final results = await tcpPing(
        runtime.node.host,
        port: runtime.node.port,
        count: 1,
        timeout: const Duration(seconds: 2),
        interval: Duration.zero,
      ).toList();
      final ok = results.isNotEmpty && results.first.success;
      final rtt = results.isNotEmpty ? results.first.rtt : null;
      if (!mounted) return;
      setState(() {
        runtime.sent++;
        if (ok && rtt != null) {
          runtime.received++;
          runtime.lastRtt = rtt;
          runtime.online = true;
          runtime.series.add(rtt.inMilliseconds.toDouble());
        } else {
          runtime.online = false;
          runtime.series.add(0);
        }
        if (runtime.series.length > _seriesLength) {
          runtime.series.removeRange(
              0, runtime.series.length - _seriesLength);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        runtime.sent++;
        runtime.online = false;
        runtime.series.add(0);
      });
    }
  }


  Future<void> _editNode(_NodeRuntime runtime) async {
    final updated = await showDialog<MonitorNode>(
      context: context,
      builder: (_) => _NodeDialog(initial: runtime.node),
    );
    if (updated == null || !mounted) return;
    final configHost = runtime.configHost;
    if (configHost != null) {
      // 写回桌面版「主机管理」配置
      await QShellConfigStore().updateHost(
        configHost,
        configHost.copyWith(
          name: updated.name,
          host: updated.host,
          port: updated.port,
        ),
      );
      if (!mounted) return;
      await _load();
    } else {
      final index = _nodes.indexOf(runtime);
      if (index < 0) return;
      setState(() => _nodes[index] = _NodeRuntime(updated));
      await _save();
    }
  }

  Future<void> _removeNode(_NodeRuntime runtime) async {
    if (runtime.fromConfig) {
      _selected.remove(runtime.node.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_selectedKey, _selected.toList());
      if (!mounted) return;
      setState(() => _nodes.remove(runtime));
    } else {
      setState(() => _nodes.remove(runtime));
      await _save();
    }
  }

  void _showActions(_NodeRuntime runtime) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(runtime.node.name),
              subtitle: Text('${runtime.node.host}:${runtime.node.port}'),
            ),
            ListTile(
              leading: const Icon(Icons.network_ping_rounded),
              title: const Text('Ping'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PingPage(initialHost: runtime.node.host),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.route_rounded),
              title: const Text('Traceroute'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TraceroutePage(initialHost: runtime.node.host),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(AppStrings.of(context).commonEdit),
              onTap: () {
                Navigator.pop(context);
                _editNode(runtime);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(AppStrings.of(context).commonDelete),
              onTap: () {
                Navigator.pop(context);
                _removeNode(runtime);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final online =
        _nodes.where((node) => node.online == true).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).settingsMonitorTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).settingsReadList,
            onPressed: _chooseNodes,
            icon: const Icon(Icons.sync_rounded),
          ),
          if (_nodes.isNotEmpty)
            IconButton(
              tooltip: _monitoring ? AppStrings.of(context).settingsStopMonitor : AppStrings.of(context).settingsStartMonitor,
              onPressed: _monitoring ? _stop : _start,
              icon: Icon(_monitoring
                  ? Icons.stop_rounded
                  : Icons.play_arrow_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _nodes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.monitor_heart_outlined,
                            size: 44, color: tokens.textDisabled),
                        const SizedBox(height: 12),
                        Text(
                          AppStrings.of(context).settingsNoNodes,
                          style: text.bodyMedium
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.of(context).settingsNodesHint,
                          style: text.bodySmall
                              ?.copyWith(color: tokens.textDisabled),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _chooseNodes,
                          icon: const Icon(Icons.sync_rounded),
                          label: Text(AppStrings.of(context).settingsReadList),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        '${_nodes.length} 个节点 · 在线 $online'
                        '${_monitoring ? " · 监视中" : ""}',
                        style: text.bodySmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ),
                    for (final runtime in _nodes)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => _showActions(runtime),
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 9,
                                      color: runtime.online == null
                                          ? tokens.textDisabled
                                          : (runtime.online!
                                              ? tokens.success
                                              : tokens.danger),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        runtime.node.name.isEmpty
                                            ? runtime.node.host
                                            : runtime.node.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.bodyMedium?.copyWith(
                                          color: tokens.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      runtime.online == null
                                          ? '--'
                                          : '${runtime.lastRtt?.inMilliseconds ?? "-"} ms',
                                      style: text.bodySmall?.copyWith(
                                        color: runtime.online == false
                                            ? tokens.danger
                                            : tokens.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${runtime.node.id.startsWith('cfg:') ? '[配置] ' : ''}'
                                  '${runtime.node.host}:${runtime.node.port}'
                                  '${runtime.online == null ? "" : " · 丢包 ${runtime.lossPercent}%"}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.labelSmall
                                      ?.copyWith(color: tokens.textSecondary),
                                ),
                                if (runtime.series.length >= 2) ...[
                                  const SizedBox(height: 6),
                                  Sparkline(
                                    values: runtime.series,
                                    height: 22,
                                    color: runtime.online == false
                                        ? tokens.danger
                                        : tokens.accent,
                                    fill: false,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _NodeDialog extends StatefulWidget {
  const _NodeDialog({this.initial});

  final MonitorNode? initial;

  @override
  State<_NodeDialog> createState() => _NodeDialogState();
}

class _NodeDialogState extends State<_NodeDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _hostCtrl = TextEditingController(text: widget.initial?.host ?? '');
    _portCtrl =
        TextEditingController(text: '${widget.initial?.port ?? 443}');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) {
      setState(() => _error = AppStrings.of(context).settingsNodeNameRequired);
      return;
    }
    final port = int.tryParse(_portCtrl.text.trim()) ?? 443;
    Navigator.pop(
      context,
      MonitorNode(
        id: widget.initial?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameCtrl.text.trim().isEmpty
            ? host
            : _nameCtrl.text.trim(),
        host: host,
        port: port,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? AppStrings.of(context).settingsAddNode : AppStrings.of(context).settingsEditNode),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.of(context).commonName,
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _hostCtrl,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: AppStrings.of(context).commonHost,
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _portCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppStrings.of(context).commonPort,
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: const TextStyle(fontSize: 12, color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.of(context).commonCancel),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

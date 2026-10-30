import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/qshell_config.dart';

/// 备忘录：桌面版右侧面板里的快捷命令（memo）。
///
/// 数据结构与 config.json 的 `memos` 一致：分组 → {name, cmd}。
class MemoPage extends StatefulWidget {
  const MemoPage({super.key});

  @override
  State<MemoPage> createState() => _MemoPageState();
}

class _MemoPageState extends State<MemoPage> {
  final QShellConfigStore _store = QShellConfigStore();
  List<QShellMemoGroup> _groups = const <QShellMemoGroup>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await _store.loadMemos();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _save(List<QShellMemoGroup> groups) async {
    await _store.saveMemos(groups);
    if (!mounted) return;
    setState(() => _groups = groups);
  }

  Future<void> _add() async {
    final result = await showDialog<_MemoDraft>(
      context: context,
      builder: (_) => _MemoDialog(
        groups: _groups.map((group) => group.group).toList(),
      ),
    );
    if (result == null || !mounted) return;
    final groups = List<QShellMemoGroup>.of(_groups);
    final index = groups.indexWhere((group) => group.group == result.group);
    final item = QShellMemo(name: result.name, cmd: result.cmd);
    if (index >= 0) {
      groups[index] = QShellMemoGroup(
        group: groups[index].group,
        items: [...groups[index].items, item],
      );
    } else {
      groups.add(QShellMemoGroup(group: result.group, items: [item]));
    }
    await _save(groups);
  }

  Future<void> _edit(int groupIndex, int itemIndex) async {
    final current = _groups[groupIndex].items[itemIndex];
    final result = await showDialog<_MemoDraft>(
      context: context,
      builder: (_) => _MemoDialog(
        groups: _groups.map((group) => group.group).toList(),
        initialGroup: _groups[groupIndex].group,
        initialName: current.name,
        initialCmd: current.cmd,
      ),
    );
    if (result == null || !mounted) return;

    final groups = List<QShellMemoGroup>.of(_groups);
    // 先从原分组移除
    final source = List<QShellMemo>.of(groups[groupIndex].items)..removeAt(itemIndex);
    groups[groupIndex] = QShellMemoGroup(
      group: groups[groupIndex].group,
      items: source,
    );
    // 再加入目标分组
    final target = groups.indexWhere((group) => group.group == result.group);
    final item = QShellMemo(name: result.name, cmd: result.cmd);
    if (target >= 0) {
      groups[target] = QShellMemoGroup(
        group: groups[target].group,
        items: [...groups[target].items, item],
      );
    } else {
      groups.add(QShellMemoGroup(group: result.group, items: [item]));
    }
    // 清掉空分组
    groups.removeWhere((group) => group.items.isEmpty);
    await _save(groups);
  }

  Future<void> _remove(int groupIndex, int itemIndex) async {
    final groups = List<QShellMemoGroup>.of(_groups);
    final items = List<QShellMemo>.of(groups[groupIndex].items)
      ..removeAt(itemIndex);
    if (items.isEmpty) {
      groups.removeAt(groupIndex);
    } else {
      groups[groupIndex] = QShellMemoGroup(
        group: groups[groupIndex].group,
        items: items,
      );
    }
    await _save(groups);
  }

  Future<void> _copy(String cmd) async {
    await Clipboard.setData(ClipboardData(text: cmd));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(AppStrings.of(context).memoCopied)));
  }

  void _showActions(int groupIndex, int itemIndex) {
    final item = _groups[groupIndex].items[itemIndex];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(item.name.isEmpty ? AppStrings.of(context).memoUnnamed : item.name),
              subtitle: Text(
                item.cmd,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(AppStrings.of(context).memoCopy),
              onTap: () {
                Navigator.pop(context);
                _copy(item.cmd);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(AppStrings.of(context).commonEdit),
              onTap: () {
                Navigator.pop(context);
                _edit(groupIndex, itemIndex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(AppStrings.of(context).commonDelete),
              onTap: () {
                Navigator.pop(context);
                _remove(groupIndex, itemIndex);
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
    final total = _groups.fold<int>(0, (sum, group) => sum + group.items.length);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).memoTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).memoAdd,
            onPressed: _add,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sticky_note_2_outlined,
                            size: 40, color: tokens.textDisabled),
                        const SizedBox(height: 12),
                        Text(
                          AppStrings.of(context).memoEmpty,
                          style: text.bodyMedium
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.of(context).memoEmptyDesc,
                          style: text.labelSmall
                              ?.copyWith(color: tokens.textDisabled),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _add,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(AppStrings.of(context).memoAddItem),
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
                        '${_groups.length} 个分组 · $total 条',
                        style: text.labelSmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ),
                    for (var g = 0; g < _groups.length; g++) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                        child: Text(
                          _groups[g].group.isEmpty
                              ? AppStrings.of(context).memoNoGroup
                              : _groups[g].group,
                          style: text.labelMedium?.copyWith(
                            color: tokens.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < _groups[g].items.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: tokens.outlineSoft,
                                ),
                              _MemoRow(
                                item: _groups[g].items[i],
                                tokens: tokens,
                                text: text,
                                onTap: () => _copy(_groups[g].items[i].cmd),
                                onLongPress: () => _showActions(g, i),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _MemoRow extends StatelessWidget {
  const _MemoRow({
    required this.item,
    required this.tokens,
    required this.text,
    required this.onTap,
    required this.onLongPress,
  });

  final QShellMemo item;
  final AppTokens tokens;
  final TextTheme text;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Icon(Icons.terminal_rounded, size: 16, color: tokens.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.name.isNotEmpty) ...[
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                  ],
                  Text(
                    item.cmd,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: tokens.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, size: 15, color: tokens.textDisabled),
          ],
        ),
      ),
    );
  }
}

class _MemoDraft {
  const _MemoDraft({
    required this.group,
    required this.name,
    required this.cmd,
  });

  final String group;
  final String name;
  final String cmd;
}

class _MemoDialog extends StatefulWidget {
  const _MemoDialog({
    required this.groups,
    this.initialGroup,
    this.initialName,
    this.initialCmd,
  });

  final List<String> groups;
  final String? initialGroup;
  final String? initialName;
  final String? initialCmd;

  @override
  State<_MemoDialog> createState() => _MemoDialogState();
}

class _MemoDialogState extends State<_MemoDialog> {
  late final TextEditingController _groupCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cmdCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _groupCtrl = TextEditingController(text: widget.initialGroup ?? '');
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _cmdCtrl = TextEditingController(text: widget.initialCmd ?? '');
  }

  @override
  void dispose() {
    _groupCtrl.dispose();
    _nameCtrl.dispose();
    _cmdCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final cmd = _cmdCtrl.text.trim();
    if (cmd.isEmpty) {
      setState(() => _error = AppStrings.of(context).memoCmdRequired);
      return;
    }
    final group = _groupCtrl.text.trim();
    Navigator.pop(
      context,
      _MemoDraft(
        group: group.isEmpty ? AppStrings.of(context).memoDefaultGroup : group,
        name: _nameCtrl.text.trim(),
        cmd: cmd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialCmd == null ? AppStrings.of(context).memoAddItem : AppStrings.of(context).memoEditItem),
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
              controller: _cmdCtrl,
              maxLines: 4,
              minLines: 2,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: AppStrings.of(context).commonCommand,
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _groupCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.of(context).commonGroup,
                hintText: widget.groups.isEmpty
                    ? '常用'
                    : widget.groups.join(' / '),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
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
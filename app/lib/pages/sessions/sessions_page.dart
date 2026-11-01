import 'dart:io';
import '../../design/instant_route.dart';
import '../../design/glass_card.dart';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../services/qshell_config.dart';
import '../../widgets/settings_action.dart';
import '../../i18n/app_strings.dart';
import 'memo_page.dart';
import 'terminal_page.dart';

/// 会话：连接列表（数据来自桌面版 config.json / 备份 zip）。
class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final QShellConfigStore _store = QShellConfigStore();
  final TextEditingController _searchCtrl = TextEditingController();
  List<QShellGroup> _groups = const <QShellGroup>[];
  bool _loading = true;
  bool _importing = false;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 按名称 / 主机 / 用户过滤，空组自动隐藏。
  List<QShellGroup> get _filteredGroups {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _groups;
    final result = <QShellGroup>[];
    for (final group in _groups) {
      final hosts = group.hosts.where((host) {
        return host.name.toLowerCase().contains(query) ||
            host.host.toLowerCase().contains(query) ||
            host.user.toLowerCase().contains(query) ||
            group.name.toLowerCase().contains(query);
      }).toList();
      if (hosts.isNotEmpty) {
        result.add(QShellGroup(name: group.name, hosts: hosts));
      }
    }
    return result;
  }

  int get _hostCount =>
      _groups.fold<int>(0, (sum, group) => sum + group.hosts.length);

  Future<void> _load() async {
    final groups = await _store.load();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final picked = await FilePicker.pickFile();
      final bytes = picked == null ? null : await picked.readAsBytes();
      if (bytes == null || bytes.isEmpty) {
        setState(() => _importing = false);
        return;
      }
      final groups = await _store.importFromBytes(bytes);
      final count = groups.fold<int>(0, (sum, g) => sum + g.hosts.length);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _importing = false;
      });
      _toast(AppStrings.of(context).sessionsImportedTemplate.replaceAll('{n}', '$count'));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyImportError(e);
        _importing = false;
      });
    }
  }

  String _friendlyImportError(Object e) {
    final text = e.toString();
    if (text.contains('qshell_config.json')) {
      return AppStrings.of(context).sessionsNoConfigInZip;
    }
    if (text.contains('FormatException') || text.contains('JSON')) {
      return AppStrings.of(context).sessionsBadConfig;
    }
    return AppStrings.of(context).sessionsImportFailedTemplate.replaceAll('{msg}', text);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _open(QShellHost host) {
    if (!host.isSsh) {
      _toast(AppStrings.of(context).sessionsProtocolTodoTemplate.replaceAll('{proto}', host.protocol.toUpperCase()));
      return;
    }
    if (host.keyPath != null && host.keyPath!.isNotEmpty && host.password.isEmpty) {
      _toast(AppStrings.of(context).sessionsKeyTodo);
      return;
    }
    Navigator.of(context).push(
      InstantPageRoute<void>(
        builder: (_) => TerminalPage(
          host: host.host,
          port: host.port,
          user: host.user,
          password: host.password,
          keyPath: host.keyPath,
          passphrase: host.passphrase,
          proxyHost: host.proxyHost,
          proxyPort: host.proxyPort,
          proxyUser: host.proxyUser,
          proxyPwd: host.proxyPwd,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).sessionsTitle),
        actions: [
          // 顺序：新建连接 → 导入 → 备忘录 → 设置
          IconButton(
            tooltip: AppStrings.of(context).sessionsNew,
            onPressed: _addHost,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: AppStrings.of(context).sessionsImport,
            onPressed: _importing ? null : _import,
            icon: _importing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.accent,
                    ),
                  )
                : const Icon(Icons.file_open_outlined),
          ),
          IconButton(
            tooltip: AppStrings.of(context).memoTitle,
            onPressed: () {
              Navigator.of(context).push(
                InstantPageRoute<void>(
                  builder: (_) => const MemoPage(),
                ),
              );
            },
            icon: const Icon(Icons.sticky_note_2_outlined),
          ),
          const SettingsAction(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? _buildEmpty(tokens, text)
              : _buildList(tokens, text),
    );
  }

  Future<void> _addHost() async {
    final host = await showModalBottomSheet<QShellHost>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        // 键盘弹起时把表单整体顶上去，避免输入框被挡住
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const _HostEditSheet(),
      ),
    );
    if (host == null) return;
    final groups = await _store.addHost(host);
    if (!mounted) return;
    setState(() => _groups = groups);
    _toast(AppStrings.of(context).sessionsAddedTemplate.replaceAll('{name}', host.name));
  }

  Future<void> _editHost(QShellHost original) async {
    final host = await showModalBottomSheet<QShellHost>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _HostEditSheet(initial: original),
      ),
    );
    if (host == null) return;
    final groups = await _store.updateHost(original, host);
    if (!mounted) return;
    setState(() => _groups = groups);
    _toast(AppStrings.of(context).sessionsSavedTemplate.replaceAll('{name}', host.name));
  }

  Future<void> _showHostActions(QShellHost host) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(AppStrings.of(context).commonEdit),
              subtitle: Text(host.subtitle),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(AppStrings.of(context).commonDelete),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _editHost(host);
    } else if (action == 'delete') {
      await _removeHost(host);
    }
  }

  Future<void> _removeHost(QShellHost host) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.of(context).sessionsDeleteTitle),
        content: Text(AppStrings.of(context).sessionsDeleteConfirmTemplate.replaceAll('{name}', host.name).replaceAll('{sub}', host.subtitle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.of(context).commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final groups = await _store.removeHost(host);
    if (!mounted) return;
    setState(() => _groups = groups);
    _toast(AppStrings.of(context).sessionsDeletedTemplate.replaceAll('{name}', host.name));
  }

  Widget _buildEmpty(AppTokens tokens, TextTheme text) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 110),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.terminal_rounded,
                size: 34, color: tokens.onAccentSoft),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppStrings.of(context).sessionsEmpty,
          textAlign: TextAlign.center,
          style: text.titleMedium?.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: _importing ? null : _import,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(_importing ? AppStrings.of(context).sessionsImporting : AppStrings.of(context).sessionsImportBtn),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.outlineSoft),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 18, color: tokens.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: text.bodySmall?.copyWith(color: tokens.danger),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildList(AppTokens tokens, TextTheme text) {
    final groups = _filteredGroups;
    final searching = _query.trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        _SearchField(
          controller: _searchCtrl,
          tokens: tokens,
          text: text,
          onChanged: (value) => setState(() => _query = value),
          onClear: () {
            _searchCtrl.clear();
            setState(() => _query = '');
          },
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.outlineSoft),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 18, color: tokens.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: text.bodySmall?.copyWith(color: tokens.danger),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (searching && groups.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded,
                    size: 40, color: tokens.textDisabled),
                const SizedBox(height: 12),
                Text(
                  AppStrings.of(context).sessionsNoMatchShortTemplate.replaceAll('{q}', _query.trim()),
                  style:
                      text.bodyMedium?.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
        ],
        for (final group in groups) ...[
          GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              // 与「文件」页一致：默认折叠，组多时一眼能扫完
              initiallyExpanded: false,
              shape: const Border(),
              collapsedShape: const Border(),
              leading: Icon(Icons.folder_rounded, color: tokens.accent),
              title: Text(
                group.name,
                style: text.bodyLarge?.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                AppStrings.of(context).sessionsCountTemplate.replaceAll('{n}', '${group.hosts.length}'),
                style: text.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                for (final host in group.hosts) ...[
                  _HostTile(
                    host: host,
                    tokens: tokens,
                    text: text,
                    onTap: () => _open(host),
                    onLongPress: () => _showHostActions(host),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Center(
          child: Text(
            searching
                ? AppStrings.of(context).sessionsMatchTemplate.replaceAll('{a}', '${groups.fold<int>(0, (s, g) => s + g.hosts.length)}').replaceAll('{b}', '$_hostCount')
                : AppStrings.of(context).sessionsTotalTemplate.replaceAll('{n}', '$_hostCount'),
            style: text.bodySmall?.copyWith(color: tokens.textDisabled),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.tokens,
    required this.text,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final AppTokens tokens;
  final TextTheme text;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autocorrect: false,
      enableSuggestions: false,
      style: text.bodyMedium?.copyWith(color: tokens.textPrimary),
      decoration: InputDecoration(
        hintText: AppStrings.of(context).sessionsSearchHint,
        hintStyle: text.bodyMedium?.copyWith(color: tokens.textDisabled),
        prefixIcon: Icon(Icons.search_rounded,
            size: 20, color: tokens.textSecondary),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 18, color: tokens.textSecondary),
                onPressed: onClear,
              ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: tokens.glass
            ? Colors.white.withValues(alpha: 0.28)
            : tokens.surfaceCardAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _HostEditSheet extends StatefulWidget {
  const _HostEditSheet({this.initial});

  /// 传了就是编辑，没传就是新建
  final QShellHost? initial;

  @override
  State<_HostEditSheet> createState() => _HostEditSheetState();
}

class _HostEditSheetState extends State<_HostEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _groupCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _passphraseCtrl;
  late final TextEditingController _proxyHostCtrl;
  late final TextEditingController _proxyPortCtrl;
  late final TextEditingController _proxyUserCtrl;
  late final TextEditingController _proxyPwdCtrl;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameCtrl = TextEditingController(text: initial?.name ?? '');
    _hostCtrl = TextEditingController(text: initial?.host ?? '');
    _portCtrl = TextEditingController(text: '${initial?.port ?? 22}');
    _userCtrl = TextEditingController(text: initial?.user ?? 'root');
    _passCtrl = TextEditingController(text: initial?.password ?? '');
    _groupCtrl = TextEditingController(
      text: (initial?.group.isNotEmpty ?? false) ? initial!.group : AppStrings.of(context).sessionsDefaultGroup,
    );
    _keyCtrl = TextEditingController(text: initial?.keyPath ?? '');
    _passphraseCtrl = TextEditingController(text: initial?.passphrase ?? '');
    _proxyHostCtrl = TextEditingController(text: initial?.proxyHost ?? '');
    _proxyPortCtrl = TextEditingController(text: '${initial?.proxyPort ?? 22}');
    _proxyUserCtrl = TextEditingController(text: initial?.proxyUser ?? '');
    _proxyPwdCtrl = TextEditingController(text: initial?.proxyPwd ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _groupCtrl.dispose();
    _keyCtrl.dispose();
    _passphraseCtrl.dispose();
    _proxyHostCtrl.dispose();
    _proxyPortCtrl.dispose();
    _proxyUserCtrl.dispose();
    _proxyPwdCtrl.dispose();
    super.dispose();
  }

  /// 选一个私钥文件，复制到应用目录后只存路径
  Future<void> _pickKey() async {
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      final dir = await getApplicationDocumentsDirectory();
      final target = File('${dir.path}/id_${picked.name}');
      await target.writeAsBytes(bytes);
      if (!mounted) return;
      setState(() => _keyCtrl.text = target.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppStrings.of(context).sessionsPickKeyFailedTemplate.replaceAll('{msg}', '$e'));
    }
  }
  void _submit() {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) {
      setState(() => _error = AppStrings.of(context).sessionsHostRequired);
      return;
    }
    final name = _nameCtrl.text.trim().isEmpty ? host : _nameCtrl.text.trim();
    final group =
        _groupCtrl.text.trim().isEmpty ? AppStrings.of(context).sessionsDefaultGroup : _groupCtrl.text.trim();
    Navigator.pop(
      context,
      QShellHost(
        name: name,
        protocol: widget.initial?.protocol ?? 'ssh',
        host: host,
        port: int.tryParse(_portCtrl.text.trim()) ?? 22,
        user: _userCtrl.text.trim(),
        password: _passCtrl.text,
        keyPath: _keyCtrl.text.trim().isEmpty ? null : _keyCtrl.text.trim(),
        passphrase: _passphraseCtrl.text.isEmpty ? null : _passphraseCtrl.text,
        group: group,
        proxyHost: _proxyHostCtrl.text.trim().isEmpty
            ? null
            : _proxyHostCtrl.text.trim(),
        proxyPort: _proxyHostCtrl.text.trim().isEmpty
            ? null
            : (int.tryParse(_proxyPortCtrl.text.trim()) ?? 22),
        proxyUser: _proxyUserCtrl.text.trim().isEmpty
            ? null
            : _proxyUserCtrl.text.trim(),
        proxyPwd: _proxyPwdCtrl.text.isEmpty
            ? null
            : _proxyPwdCtrl.text,
        proxyKey: widget.initial?.proxyKey,
        proxyPassphrase: widget.initial?.proxyPassphrase,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? '编辑连接' : '新建连接',
              style: text.titleMedium?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _field(_nameCtrl, AppStrings.of(context).commonName, '留空就用主机名'),
            _field(_hostCtrl, AppStrings.of(context).commonHost, 'IP 或域名'),
            _field(_portCtrl, AppStrings.of(context).commonPort, '22', number: true),
            _field(_userCtrl, AppStrings.of(context).commonUser, 'root'),
            _field(_passCtrl, AppStrings.of(context).commonPassword, '', obscure: true),
            _field(_groupCtrl, AppStrings.of(context).commonGroup, '填新名字就是新分组'),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                AppStrings.of(context).sessionsKeySection,
                style: text.titleSmall?.copyWith(color: tokens.textPrimary),
              ),
              subtitle: Text(
                _keyCtrl.text.trim().isEmpty
                    ? AppStrings.of(context).sessionsUsingPwd
                    : _keyCtrl.text.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _keyCtrl.text.trim().isEmpty
                            ? AppStrings.of(context).sessionsNoKeyFile
                            : _keyCtrl.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickKey,
                      child: Text(AppStrings.of(context).commonSelect),
                    ),
                    if (_keyCtrl.text.trim().isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            setState(() => _keyCtrl.text = ''),
                        child: Text(AppStrings.of(context).commonClear),
                      ),
                  ],
                ),
                _field(_passphraseCtrl, AppStrings.of(context).sessionsPassphrase, AppStrings.of(context).sessionsPassphraseHint, obscure: true),
              ],
            ),
            ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                AppStrings.of(context).sessionsProxySection,
                style: text.titleSmall?.copyWith(color: tokens.textPrimary),
              ),
              subtitle: Text(
                _proxyHostCtrl.text.trim().isEmpty ? AppStrings.of(context).sessionsProxyDirect : _proxyHostCtrl.text.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
              children: [
                _field(_proxyHostCtrl, AppStrings.of(context).commonProxy, AppStrings.of(context).sessionsProxyHostHint),
                _field(_proxyPortCtrl, AppStrings.of(context).commonPort, '22', number: true),
                _field(_proxyUserCtrl, AppStrings.of(context).commonUser, AppStrings.of(context).sessionsProxyUserHint),
                _field(_proxyPwdCtrl, AppStrings.of(context).commonPassword, AppStrings.of(context).sessionsProxyPwdHint, obscure: true),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: text.bodySmall?.copyWith(color: tokens.danger),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppStrings.of(context).commonCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(_isEdit ? '保存' : '添加'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    bool obscure = false,
    bool number = false,
  }) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: number ? TextInputType.number : null,
              autocorrect: false,
              enableSuggestions: false,
              style: text.bodyLarge?.copyWith(color: tokens.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    text.bodyLarge?.copyWith(color: tokens.textDisabled),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: tokens.glass
                    ? Colors.white.withValues(alpha: 0.28)
                    : tokens.surfaceCardAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostTile extends StatelessWidget {
  const _HostTile({
    required this.host,
    required this.tokens,
    required this.text,
    required this.onTap,
    required this.onLongPress,
  });

  final QShellHost host;
  final AppTokens tokens;
  final TextTheme text;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final enabled = host.isSsh;
    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: enabled ? tokens.accentSoft : tokens.surfaceCardAlt,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.terminal_rounded,
                  size: 18,
                  color: enabled ? tokens.onAccentSoft : tokens.textDisabled,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      host.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!enabled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.surfaceCardAlt,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    host.protocol.toUpperCase(),
                    style: text.labelSmall?.copyWith(color: tokens.textDisabled),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: tokens.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}

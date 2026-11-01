import 'package:flutter/material.dart';
import '../../design/instant_route.dart';
import '../../design/glass_card.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/files/remote_fs.dart';
import '../../services/qshell_config.dart';
import '../../widgets/settings_action.dart';
import 'remote_browser_page.dart';
import 'sftp_browser_page.dart';

/// 文件：WebDAV / FTP / SMB（可多套配置）+ SFTP（复用已导入的 SSH 主机）。
class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  final QShellConfigStore _configStore = QShellConfigStore();
  final RemoteStore _remoteStore = RemoteStore();
  List<QShellGroup> _groups = const <QShellGroup>[];
  List<RemoteServer> _servers = const <RemoteServer>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await _configStore.load();
    final servers = await _remoteStore.load();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _servers = servers;
      _loading = false;
    });
  }

  void _openSftp(QShellHost host) {
    if (!host.isSsh) {
      _toast('${host.protocol.toUpperCase()} 暂未接入');
      return;
    }
    if (host.password.isEmpty) {
      _toast('这条连接没有密码（私钥登录暂未接入）');
      return;
    }
    Navigator.of(context).push(
      InstantPageRoute<void>(
        builder: (_) => SftpBrowserPage(
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

  void _openServer(RemoteServer server) {
    Navigator.of(context).push(
      InstantPageRoute<void>(
        builder: (_) => RemoteBrowserPage(server: server),
      ),
    );
  }

  Future<void> _addServer(String kind) async {
    final server = await showModalBottomSheet<RemoteServer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _RemoteServerSheet(kind: kind),
      ),
    );
    if (server == null) return;
    final servers = await _remoteStore.add(server);
    if (!mounted) return;
    setState(() => _servers = servers);
  }

  Future<void> _editServer(RemoteServer server) async {
    final updated = await showModalBottomSheet<RemoteServer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _RemoteServerSheet(kind: server.kind, initial: server),
      ),
    );
    if (updated == null) return;
    final servers = await _remoteStore.update(server, updated);
    if (!mounted) return;
    setState(() => _servers = servers);
  }

  Future<void> _removeServer(RemoteServer server) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.of(context).filesDeleteServerTitle),
        content: Text(AppStrings.of(context).filesDeleteServerConfirmTemplate.replaceAll('{name}', server.name)),
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
    final servers = await _remoteStore.remove(server);
    if (!mounted) return;
    setState(() => _servers = servers);
  }

  void _showServerActions(RemoteServer server) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(AppStrings.of(context).commonEdit),
              subtitle: Text(server.subtitle),
              onTap: () {
                Navigator.pop(context);
                _editServer(server);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(AppStrings.of(context).commonDelete),
              onTap: () {
                Navigator.pop(context);
                _removeServer(server);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<RemoteServer> _byKind(String kind) =>
      _servers.where((server) => server.kind == kind).toList();

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).filesTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).filesRefresh,
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SettingsAction(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  _remoteSection('webdav', 'WebDAV', tokens, text),
                  const SizedBox(height: 16),
                  _remoteSection('ftp', 'FTP', tokens, text),
                  const SizedBox(height: 16),
                  _remoteSection('smb', 'SMB', tokens, text),
                  const SizedBox(height: 16),
                  _sftpSection(tokens, text),
                ],
              ),
            ),
    );
  }

  Widget _remoteSection(
    String kind,
    String title,
    AppTokens tokens,
    TextTheme text,
  ) {
    final servers = _byKind(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _sectionLabel(title, tokens, text)),
            IconButton(
              tooltip: '添加 $title',
              visualDensity: VisualDensity.compact,
              onPressed: () => _addServer(kind),
              icon: Icon(Icons.add_circle_outline_rounded,
                  size: 20, color: tokens.accent),
            ),
          ],
        ),
        if (servers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              AppStrings.of(context).filesEmptyHint,
              style: text.bodySmall?.copyWith(color: tokens.textDisabled),
            ),
          )
        else
          for (final server in servers)
            GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  switch (kind) {
                    'webdav' => Icons.cloud_outlined,
                    'ftp' => Icons.folder_shared_outlined,
                    'smb' => Icons.dns_outlined,
                    _ => Icons.folder_outlined,
                  },
                  color: tokens.accent,
                ),
                title: Text(
                  server.name.isEmpty ? server.host : server.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge?.copyWith(color: tokens.textPrimary),
                ),
                subtitle: Text(
                  server.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: tokens.textSecondary),
                ),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: tokens.textDisabled),
                onTap: () => _openServer(server),
                onLongPress: () => _showServerActions(server),
              ),
            ),
      ],
    );
  }

  Widget _sftpSection(AppTokens tokens, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('SFTP', tokens, text),
        const SizedBox(height: 6),
        if (_groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              AppStrings.of(context).filesNoConnections,
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
          )
        else
          for (final group in _groups) ...[
            GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.antiAlias,
              child: _GroupSection(
                group: group,
                tokens: tokens,
                text: text,
                onOpen: _openSftp,
              ),
            ),
          ],
      ],
    );
  }

  Widget _sectionLabel(String label, AppTokens tokens, TextTheme text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
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

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.tokens,
    required this.text,
    required this.onOpen,
  });

  final QShellGroup group;
  final AppTokens tokens;
  final TextTheme text;
  final void Function(QShellHost host) onOpen;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
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
        '${group.hosts.length} 个连接',
        style: text.bodySmall?.copyWith(color: tokens.textSecondary),
      ),
      childrenPadding: const EdgeInsets.only(bottom: 6),
      children: [
        for (final host in group.hosts)
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(56, 0, 16, 0),
            leading: Icon(
              host.isSsh ? Icons.terminal_rounded : Icons.block_rounded,
              size: 18,
              color: host.isSsh ? tokens.textSecondary : tokens.textDisabled,
            ),
            title: Text(
              host.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(
                color: host.isSsh ? tokens.textPrimary : tokens.textDisabled,
              ),
            ),
            subtitle: Text(
              host.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
            trailing: Icon(Icons.chevron_right_rounded,
                size: 18, color: tokens.textDisabled),
            onTap: () => onOpen(host),
          ),
      ],
    );
  }
}

class _RemoteServerSheet extends StatefulWidget {
  const _RemoteServerSheet({required this.kind, this.initial});

  final String kind;
  final RemoteServer? initial;

  @override
  State<_RemoteServerSheet> createState() => _RemoteServerSheetState();
}

class _RemoteServerSheetState extends State<_RemoteServerSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _shareCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  String? _error;

  bool get _isEdit => widget.initial != null;

  String get _title => switch (widget.kind) {
        'webdav' => AppStrings.of(context).filesWebdav,
        'ftp' => AppStrings.of(context).filesFtp,
        'smb' => AppStrings.of(context).filesSmb,
        _ => '服务器',
      };

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameCtrl = TextEditingController(text: initial?.name ?? '');
    _hostCtrl = TextEditingController(text: initial?.host ?? '');
    _portCtrl = TextEditingController(
      text: '${initial?.port ?? (widget.kind == 'ftp' ? 21 : 0)}',
    );
    _shareCtrl = TextEditingController(text: initial?.share ?? '');
    _userCtrl = TextEditingController(text: initial?.user ?? '');
    _passCtrl = TextEditingController(text: initial?.pass ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _shareCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) return AppStrings.of(context).filesAddrRequired;
    if (widget.kind == 'webdav') {
      if (!host.startsWith('http://') && !host.startsWith('https://')) {
        return AppStrings.of(context).filesWebdavUrlInvalid;
      }
    }
    if (widget.kind == 'smb' && _shareCtrl.text.trim().isEmpty) {
      return AppStrings.of(context).filesSmbShareRequired;
    }
    return null;
  }

  void _submit() {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    var host = _hostCtrl.text.trim();
    if (widget.kind == 'webdav' && host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }
    Navigator.pop(
      context,
      RemoteServer(
        kind: widget.kind,
        name: _nameCtrl.text.trim().isEmpty ? host : _nameCtrl.text.trim(),
        host: host,
        port: widget.kind == 'ftp'
            ? (int.tryParse(_portCtrl.text.trim()) ?? 21)
            : 0,
        share: widget.kind == 'smb' ? _shareCtrl.text.trim() : '',
        user: _userCtrl.text.trim(),
        pass: _passCtrl.text,
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
              _isEdit ? '编辑 $_title' : '添加 $_title',
              style: text.titleMedium?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            _field(_nameCtrl, AppStrings.of(context).commonName, AppStrings.of(context).filesServerNameHint),
            _field(
              _hostCtrl,
              widget.kind == 'webdav' ? AppStrings.of(context).filesServerAddr : '主机',
              widget.kind == 'webdav'
                  ? 'https://example.com/dav'
                  : '192.168.1.10',
            ),
            if (widget.kind == 'ftp') _field(_portCtrl, AppStrings.of(context).commonPort, '21'),
            if (widget.kind == 'smb') _field(_shareCtrl, AppStrings.of(context).filesServerShare, AppStrings.of(context).filesServerShareHint),
            _field(_userCtrl, AppStrings.of(context).commonUser, ''),
            _field(_passCtrl, AppStrings.of(context).commonPassword, '', obscure: true),
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
                fillColor: tokens.surfaceCardAlt,
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

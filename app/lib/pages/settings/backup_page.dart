import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/download_helper.dart';
import '../../services/files/remote_fs.dart';
import '../../services/qshell_config.dart';
import '../../services/tools/webdav_client.dart';

/// WebDAV 备份 / 恢复。
///
/// 这里的服务器地址是**独立手填**的，不继承「文件」页里的 WebDAV 浏览配置。
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  static const _kUrl = 'backup.webdav.url';
  static const _kUser = 'backup.webdav.user';
  static const _kPass = 'backup.webdav.pass';

  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  List<WebdavEntry> _files = const <WebdavEntry>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool get _configured => _urlCtrl.text.trim().isNotEmpty;

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _urlCtrl.text = prefs.getString(_kUrl) ?? '';
    _userCtrl.text = prefs.getString(_kUser) ?? '';
    _passCtrl.text = prefs.getString(_kPass) ?? '';
    setState(() => _loading = false);
    if (_configured) {
      await _loadFiles();
    }
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    var url = _urlCtrl.text.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    await prefs.setString(_kUrl, url);
    await prefs.setString(_kUser, _userCtrl.text.trim());
    await prefs.setString(_kPass, _passCtrl.text);
  }

  WebdavClient _client() => WebdavClient(
        baseUrl: _urlCtrl.text.trim(),
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
      );

  Future<void> _loadFiles() async {
    if (!_configured) return;
    await _saveConfig();
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final entries = await _client().list('');
      final backups = entries
          .where((entry) =>
              !entry.isDirectory && entry.name.toLowerCase().endsWith('.zip'))
          .toList();
      backups.sort((a, b) => b.name.compareTo(a.name));
      if (!mounted) return;
      setState(() {
        _files = backups;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppStrings.of(context).backupReadFailedTemplate.replaceAll('{msg}', '$e');
        _files = const <WebdavEntry>[];
      });
    }
  }

  Future<List<int>> _buildZip() async {
    final configStore = QShellConfigStore();
    final rawJson = await configStore.exportRawJson();
    final configBytes = utf8.encode(rawJson);

    final servers = await RemoteStore().load();
    final serversBytes = utf8.encode(jsonEncode(<String, dynamic>{
      'version': '1',
      'servers': servers.map((server) => server.toJson()).toList(),
    }));

    final archive = Archive()
      ..addFile(
        ArchiveFile('qshell_config.json', configBytes.length, configBytes),
      )
      ..addFile(
        ArchiveFile('qshell_servers.json', serversBytes.length, serversBytes),
      );
    return ZipEncoder().encode(archive);
  }

  Future<void> _backup() async {
    if (!_configured) {
      setState(() => _error = AppStrings.of(context).backupAddrRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await _buildZip();
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final name = 'qshell_backup_${now.year}${two(now.month)}${two(now.day)}'
          '_${two(now.hour)}${two(now.minute)}${two(now.second)}.zip';
      await _client().upload(name, bytes);
      if (!mounted) return;
      _toast(AppStrings.of(context).backupDoneTemplate.replaceAll('{name}', name));
      await _loadFiles();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppStrings.of(context).backupFailedTemplate.replaceAll('{msg}', '$e');
      });
    }
  }

  /// 把远端备份下载到手机（不恢复，仅保存文件）
  Future<void> _download(WebdavEntry entry) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await _client().download(entry.href);
      final path = await DownloadHelper.saveBytes(
        entry.name,
        Uint8List.fromList(bytes),
      );
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('已保存到 $path');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '下载失败：$e';
      });
    }
  }

  Future<void> _restore(WebdavEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.of(context).backupRestoreTitle),
        content: Text(AppStrings.of(context).backupRestoreConfirmTemplate.replaceAll('{name}', entry.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.of(context).backupRestoreBtn),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await _client().download(entry.href);
      final archive = ZipDecoder().decodeBytes(bytes);
      final configFile = archive.findFile('qshell_config.json') ??
          archive.findFile('config.json');
      if (configFile == null) {
        throw const FormatException('备份里没有 qshell_config.json');
      }
      final configBytes = configFile.readBytes();
      if (configBytes == null) {
        throw const FormatException('配置文件读取失败');
      }
      final groupCount =
          (await QShellConfigStore().importFromBytes(configBytes)).length;

      var restoredServers = 0;
      final serversFile = archive.findFile('qshell_servers.json');
      if (serversFile != null) {
        final serverBytes = serversFile.readBytes();
        if (serverBytes != null) {
          final decoded =
              jsonDecode(utf8.decode(serverBytes)) as Map<String, dynamic>;
          final list = (decoded['servers'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((item) => RemoteServer.fromJson(item.cast<String, dynamic>()))
              .toList();
          await RemoteStore().save(list);
          restoredServers = list.length;
        }
      }

      if (!mounted) return;
      setState(() => _busy = false);
      _toast(AppStrings.of(context).backupRestoredTemplate.replaceAll('{g}', '$groupCount').replaceAll('{s}', '$restoredServers'));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppStrings.of(context).backupRestoreFailedTemplate.replaceAll('{msg}', '$e');
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _fmtSize(int bytes) {
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).backupTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).backupRefresh,
            onPressed: _busy || !_configured ? null : _loadFiles,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _field(_urlCtrl, AppStrings.of(context).filesServerAddr, 'https://example.com/dav'),
                const SizedBox(height: 10),
                _field(_userCtrl, AppStrings.of(context).commonUser, ''),
                const SizedBox(height: 10),
                _field(_passCtrl, AppStrings.of(context).commonPassword, '', obscure: true),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _backup,
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: Text(_busy ? AppStrings.of(context).backupInProgress : AppStrings.of(context).backupDoNow),
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: tokens.track,
                      color: tokens.accent,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: text.bodySmall?.copyWith(color: tokens.danger)),
                ],
                const SizedBox(height: 20),
                Text(
                  AppStrings.of(context).backupRemoteCountTemplate.replaceAll('{n}', '${_files.length}'),
                  style: text.labelMedium?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                if (!_configured)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      AppStrings.of(context).backupHint,
                      style: text.bodySmall
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                  )
                else if (_files.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      AppStrings.of(context).backupNoFiles,
                      style: text.bodySmall
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                  )
                else
                  for (final file in _files)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(Icons.folder_zip_rounded,
                            color: tokens.accent),
                        title: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium
                              ?.copyWith(color: tokens.textPrimary),
                        ),
                        subtitle: Text(
                          _fmtSize(file.size),
                          style: text.labelSmall
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '下载到手机',
                              onPressed:
                                  _busy ? null : () => _download(file),
                              icon: const Icon(
                                  Icons.download_rounded,
                                  size: 20),
                            ),
                            TextButton(
                              onPressed: () => _restore(file),
                              child: Text(AppStrings.of(context)
                                  .backupRestoreBtn),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
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
    return Row(
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
              hintStyle: text.bodyLarge?.copyWith(color: tokens.textDisabled),
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
    );
  }
}

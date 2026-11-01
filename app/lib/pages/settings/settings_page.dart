import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/design_switcher.dart';
import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/download_helper.dart';
import '../../services/qshell_config.dart';
import '../../services/update_service.dart';
import '../../version.dart';
import '../../services/system_service.dart';
import '../../state/locale_scope.dart';
import '../../state/theme_controller.dart';
import 'backup_page.dart';

/// 设置：外观 / 语言 / 终端 / 设计语言 / 数据 / 权限 / 关于。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final ThemeController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _usage = false;
  bool _phone = false;
  bool _wifi = false;
  bool _location = false;
  bool _importing = false;

  /// 语言切换暂时不开放（翻译还没覆盖所有页面）
  static const bool _showLanguage = true;

  static const String _kAutoUpdateKey = 'update.auto';

  bool _autoCheckUpdate = true;
  bool _checkingUpdate = false; // ignore: prefer_final_fields
  String? _updateMessage;

  @override
  void initState() {
    super.initState();
    _loadUpdatePrefs();
    _loadPermissions();
    _loadDownloadLocation();
  }

  String _downloadLocation = DownloadHelper.appLocation;

  Future<void> _loadDownloadLocation() async {
    final value = await DownloadHelper.getLocation();
    if (!mounted) return;
    setState(() => _downloadLocation = value);
  }

  Future<void> _chooseDownloadLocation() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(AppStrings.of(context).settingsAppDir),
              subtitle: Text(AppStrings.of(context).settingsAppDirDesc),
              trailing: _downloadLocation == DownloadHelper.appLocation
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(context, DownloadHelper.appLocation),
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: Text(AppStrings.of(context).settingsDownloads),
              subtitle: Text(AppStrings.of(context).settingsDownloadsDesc),
              trailing: _downloadLocation == DownloadHelper.downloadsLocation
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () =>
                  Navigator.pop(context, DownloadHelper.downloadsLocation),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await DownloadHelper.setLocation(choice);
    await _loadDownloadLocation();
  }

  Future<void> _loadPermissions() async {
    final usage = await SystemService.hasUsageAccess();
    final phone = await SystemService.hasPhonePermission();
    final wifi = await SystemService.hasWifiPermission();
    final location = await SystemService.hasLocationPermission();
    if (!mounted) return;
    setState(() {
      _usage = usage;
      _phone = phone;
      _wifi = wifi;
      _location = location;
    });
  }

  Future<void> _importConfig() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null) {
        setState(() => _importing = false);
        return;
      }
      final bytes = await picked.readAsBytes();
      final store = QShellConfigStore();
      final groups = await store.importFromBytes(bytes);
      if (!mounted) return;
      final count = groups.fold<int>(0, (sum, g) => sum + g.hosts.length);
      _toast('已导入 $count 条连接（${groups.length} 个分组）');
    } catch (e) {
      if (!mounted) return;
      _toast('导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _pickBgImage() async {
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/terminal_bg.png');
      await file.writeAsBytes(bytes);
      await widget.controller.setTerminalBgImage(file.path);
      if (!mounted) return;
      _toast(AppStrings.of(context).settingsBgImageSet);
    } catch (e) {
      if (!mounted) return;
      _toast('设置背景失败：$e');
    }
  }

  Future<void> _removeBgImage() async {
    await widget.controller.setTerminalBgImage(null);
    if (!mounted) return;
    _toast(AppStrings.of(context).settingsBgImageCleared);
  }

  /// 导出本地数据：按桌面版格式打包成 zip（内含 qshell_config.json），
  /// 可以和桌面端直接互导。
  Future<void> _exportData() async {
    try {
      final store = QShellConfigStore();
      final rawJson = await store.exportRawJson();
      final bytes = utf8.encode(rawJson);
      final archive = Archive()
        ..addFile(
          ArchiveFile('qshell_config.json', bytes.length, bytes),
        );
      final zipBytes = ZipEncoder().encode(archive);

      final uri = await FilePicker.saveFile(
        fileName: 'qshell_backup.zip',
        bytes: Uint8List.fromList(zipBytes),
        mimeType: 'application/zip',
      );
      if (!mounted) return;
      _toast(uri == null ? AppStrings.of(context).settingsExportCancelled : AppStrings.of(context).settingsExported);
    } catch (e) {
      if (!mounted) return;
      _toast('导出失败：$e');
    }
  }

  /// 检查 GitHub Releases 上的新版本
  Future<void> _loadUpdatePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final auto = prefs.getBool(_kAutoUpdateKey) ?? true;
    if (!mounted) return;
    setState(() => _autoCheckUpdate = auto);
    if (auto) {
      // 进设置页时静默检查一次（不弹窗）
      await _checkUpdate(silent: true);
    }
  }

  Future<void> _checkUpdate({bool silent = false}) async {
    final repo = UpdateService.defaultRepo;
    if (repo.isEmpty) {
      if (!silent) {
        setState(() =>
            _updateMessage = AppStrings.of(context).updateNoRepo);
      }
      return;
    }
    setState(() {
      _checkingUpdate = true;
      _updateMessage = null;
    });
    try {
      final release = await UpdateService.latest(repo);
      if (!mounted) return;
      if (release == null) {
        setState(() {
          _checkingUpdate = false;
          _updateMessage = AppStrings.of(context).updateLatest;
        });
        return;
      }
      final newer = UpdateService.isNewer(release.version, kAppVersion);
      setState(() {
        _checkingUpdate = false;
        _updateMessage = newer
            ? AppStrings.of(context)
                .updateAvailableTemplate
                .replaceAll('{v}', release.version)
            : AppStrings.of(context).updateLatest;
      });
      if (newer && !silent) {
        await _showUpdateDialog(release);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingUpdate = false;
        _updateMessage = AppStrings.of(context)
            .updateFailedTemplate
            .replaceAll('{msg}', '$e');
      });
    }
  }

  Future<void> _showUpdateDialog(ReleaseInfo release) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppStrings.of(context)
              .updateAvailableTemplate
              .replaceAll('{v}', release.version),
        ),
        content: SingleChildScrollView(
          child: Text(
            release.notes.isEmpty ? release.name : release.notes,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _openReleasePage(release);
            },
            child: Text(AppStrings.of(context).checkUpdate),
          ),
        ],
      ),
    );
  }

  Future<void> _openReleasePage(ReleaseInfo release) async {
    final url = release.apkUrl.isNotEmpty ? release.apkUrl : release.pageUrl;
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(url)));
    }
  }

  Future<void> _clearData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.of(context).clearData),
        content: Text(AppStrings.of(context).clearDataDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.of(context).commonConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => !key.startsWith('flutter.'));
    for (final key in keys.toList()) {
      await prefs.remove(key);
    }
    if (!mounted) return;
    _toast(AppStrings.of(context).clearDataDone);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final locale = LocaleScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(context).settingsTitle)),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              // 语言设置先占位在外观之上，但暂不开放切换（文案还没全量迁移）
              if (_showLanguage) ...[
                _SectionTitle(AppStrings.of(context).sectionLanguage,
                    tokens: tokens, text: text),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<AppLanguage>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: AppLanguage.zhHans,
                            label: Text('简体中文'),
                          ),
                          ButtonSegment(
                            value: AppLanguage.zhHant,
                            label: Text('繁體中文'),
                          ),
                        ],
                        selected: {locale.language},
                        onSelectionChanged: (value) =>
                            locale.setLanguage(value.first),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _SectionTitle(AppStrings.of(context).sectionAppearance,
                  tokens: tokens, text: text),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  // 外观选项默认折叠，减少设置页长度
                  initiallyExpanded: false,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: Icon(Icons.palette_outlined, color: tokens.accent),
                  title: Text(
                    AppStrings.of(context).sectionAppearance,
                    style: text.bodyLarge?.copyWith(color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    AppStrings.of(context).settingsAppearanceSub,
                    style: text.bodySmall
                        ?.copyWith(color: tokens.textSecondary),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // 设计语言：MD3 / 液态玻璃
                      Text('设计语言',
                          style: text.titleSmall
                              ?.copyWith(color: tokens.textPrimary)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<DesignLanguage>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: DesignLanguage.md3,
                              label: Text('MD3'),
                            ),
                            ButtonSegment(
                              value: DesignLanguage.glass,
                              label: Text('液态玻璃'),
                            ),
                          ],
                          selected: <DesignLanguage>{widget.controller.designLanguage},
                          onSelectionChanged: (values) {
                            widget.controller.setDesignLanguage(values.first);
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(AppStrings.of(context).modeTitle,
                          style: text.titleSmall
                              ?.copyWith(color: tokens.textPrimary)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeModeChoice>(
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            textStyle: text.labelMedium,
                          ),
                          segments: [
                            ButtonSegment(
                              value: ThemeModeChoice.system,
                              label: Text(AppStrings.of(context).modeSystem),
                              icon: const Icon(Icons.brightness_auto_rounded),
                            ),
                            ButtonSegment(
                              value: ThemeModeChoice.light,
                              label: Text(AppStrings.of(context).modeLight),
                              icon: const Icon(Icons.light_mode_rounded),
                            ),
                            ButtonSegment(
                              value: ThemeModeChoice.dark,
                              label: Text(AppStrings.of(context).modeDark),
                              icon: const Icon(Icons.dark_mode_rounded),
                            ),
                          ],
                          selected: {widget.controller.modeChoice},
                          onSelectionChanged: (value) =>
                              widget.controller.setModeChoice(value.first),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(AppStrings.of(context).followWallpaper,
                            style: text.bodyLarge
                                ?.copyWith(color: tokens.textPrimary)),
                        subtitle: Text(
                          AppStrings.of(context).followWallpaperDesc,
                          style: text.bodySmall
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                        value: widget.controller.useDynamicColor,
                        onChanged: widget.controller.setUseDynamicColor,
                      ),
                      const SizedBox(height: 8),
                      Text(AppStrings.of(context).accentColor,
                          style: text.titleSmall
                              ?.copyWith(color: tokens.textPrimary)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final color in ThemeController.accentPresets)
                            _ColorDot(
                              color: color,
                              selected: widget.controller.seed == color,
                              tokens: tokens,
                              onTap: () => widget.controller.setSeed(color),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.controller.useDynamicColor
                            ? AppStrings.of(context).accentDynamicHint
                            : AppStrings.of(context).accentManualHint,
                        style: text.bodySmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(AppStrings.of(context).sectionTerminal,
                  tokens: tokens, text: text),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  // 终端选项默认折叠，避免设置页太长
                  initiallyExpanded: false,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: Icon(Icons.terminal_rounded, color: tokens.accent),
                  title: Text(
                    AppStrings.of(context).settingsTerminalLook,
                    style: text.bodyLarge?.copyWith(color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    AppStrings.of(context).settingsTerminalLookDesc,
                    style: text.bodySmall
                        ?.copyWith(color: tokens.textSecondary),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [
                    // 字号
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppStrings.of(context).terminalFontSize,
                            style: text.bodyMedium
                                ?.copyWith(color: tokens.textSecondary),
                          ),
                        ),
                        IconButton(
                          tooltip: AppStrings.of(context).decrease,
                          onPressed: widget.controller.terminalFontSize <=
                                  ThemeController.minTerminalFontSize
                              ? null
                              : () => widget.controller.setTerminalFontSize(
                                  widget.controller.terminalFontSize - 1),
                          icon: const Icon(Icons.text_decrease_rounded),
                        ),
                        SizedBox(
                          width: 42,
                          child: Text(
                            widget.controller.terminalFontSize
                                .toStringAsFixed(0),
                            textAlign: TextAlign.center,
                            style: text.titleMedium?.copyWith(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: AppStrings.of(context).increase,
                          onPressed: widget.controller.terminalFontSize >=
                                  ThemeController.maxTerminalFontSize
                              ? null
                              : () => widget.controller.setTerminalFontSize(
                                  widget.controller.terminalFontSize + 1),
                          icon: const Icon(Icons.text_increase_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(AppStrings.of(context).settingsTextColor,
                          style: text.bodyMedium
                              ?.copyWith(color: tokens.textSecondary)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        // 自动：亮底深字 / 暗底浅字
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () =>
                              widget.controller.setTerminalFgColor(null),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: tokens.surfaceCardAlt,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    widget.controller.terminalFgColor == null
                                        ? tokens.textPrimary
                                        : tokens.outlineSoft,
                                width: 2.5,
                              ),
                            ),
                            child: Icon(Icons.autorenew_rounded,
                                size: 15, color: tokens.textSecondary),
                          ),
                        ),
                        for (final color in ThemeController.terminalFgPresets)
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () =>
                                widget.controller.setTerminalFgColor(color),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: widget.controller.terminalFgColor ==
                                          color
                                      ? tokens.textPrimary
                                      : tokens.outlineSoft,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(AppStrings.of(context).settingsBgColor,
                          style: text.bodyMedium
                              ?.copyWith(color: tokens.textSecondary)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () =>
                              widget.controller.setTerminalBgColor(null),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: tokens.background,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    widget.controller.terminalBgColor == null
                                        ? tokens.textPrimary
                                        : tokens.outlineSoft,
                                width: 2.5,
                              ),
                            ),
                            child: Icon(Icons.format_color_reset_rounded,
                                size: 15, color: tokens.textSecondary),
                          ),
                        ),
                        for (final color in ThemeController.terminalBgPresets)
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () =>
                                widget.controller.setTerminalBgColor(color),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: widget.controller.terminalBgColor ==
                                          color
                                      ? tokens.textPrimary
                                      : tokens.outlineSoft,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.controller.terminalBgImage == null
                                ? AppStrings.of(context).settingsBgImageUnset
                                : AppStrings.of(context).settingsBgImageSetDesc,
                            style: text.bodySmall
                                ?.copyWith(color: tokens.textSecondary),
                          ),
                        ),
                        if (widget.controller.terminalBgImage != null)
                          TextButton(
                            onPressed: _removeBgImage,
                            child: Text(AppStrings.of(context).commonClear),
                          ),
                        TextButton(
                          onPressed: _pickBgImage,
                          child: Text(AppStrings.of(context).settingsPickImage),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(AppStrings.of(context).sectionData, tokens: tokens, text: text),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  // 数据操作也默认折叠
                  initiallyExpanded: false,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: Icon(Icons.storage_rounded, color: tokens.accent),
                  title: Text(
                    AppStrings.of(context).sectionData,
                    style: text.bodyLarge?.copyWith(color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    AppStrings.of(context).settingsDataSub,
                    style: text.bodySmall
                        ?.copyWith(color: tokens.textSecondary),
                  ),
                  childrenPadding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: Icon(Icons.file_open_outlined,
                          color: tokens.accent),
                      title: Text(AppStrings.of(context).importConfig,
                          style: text.bodyLarge
                              ?.copyWith(color: tokens.textPrimary)),
                      subtitle: Text(AppStrings.of(context).importConfigDesc,
                          style: text.bodySmall
                              ?.copyWith(color: tokens.textSecondary)),
                      trailing: _importing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.chevron_right_rounded,
                              color: tokens.textDisabled),
                      onTap: _importing ? null : _importConfig,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.save_alt_rounded, color: tokens.accent),
                      title: Text(AppStrings.of(context).settingsExportLocal,
                          style: text.bodyLarge
                              ?.copyWith(color: tokens.textPrimary)),
                      subtitle: Text(
                          AppStrings.of(context).settingsExportLocalDesc,
                          style: text.bodySmall
                              ?.copyWith(color: tokens.textSecondary)),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: tokens.textDisabled),
                      onTap: _exportData,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading:
                          Icon(Icons.download_rounded, color: tokens.accent),
                      title: Text(AppStrings.of(context).settingsDownloadLocation,
                          style: text.bodyLarge
                              ?.copyWith(color: tokens.textPrimary)),
                      subtitle: Text(
                          _downloadLocation == DownloadHelper.downloadsLocation
                              ? AppStrings.of(context).settingsDownloads
                              : AppStrings.of(context).settingsAppDir,
                          style: text.bodySmall
                              ?.copyWith(color: tokens.textSecondary)),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: tokens.textDisabled),
                      onTap: _chooseDownloadLocation,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading:
                          Icon(Icons.cloud_sync_outlined, color: tokens.accent),
                      title: Text(AppStrings.of(context).webdavBackup,
                          style: text.bodyLarge
                              ?.copyWith(color: tokens.textPrimary)),
                      subtitle: Text(AppStrings.of(context).webdavBackupDesc,
                          style: text.bodySmall
                              ?.copyWith(color: tokens.textSecondary)),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: tokens.textDisabled),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const BackupPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  // 权限状态默认折叠
                  initiallyExpanded: false,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: Icon(Icons.verified_user_outlined,
                      color: tokens.accent),
                  title: Text(
                    AppStrings.of(context).sectionPermissions,
                    style: text.bodyLarge?.copyWith(color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    AppStrings.of(context).settingsPermissionsSub,
                    style: text.bodySmall
                        ?.copyWith(color: tokens.textSecondary),
                  ),
                  childrenPadding: EdgeInsets.zero,
                  children: [
                    _PermissionTile(
                      title: AppStrings.of(context).permissionUsage,
                      granted: _usage,
                      grantedText: AppStrings.of(context).permissionGranted,
                      deniedText: AppStrings.of(context).permissionDenied,
                      goGrantText: AppStrings.of(context).permissionGoGrant,
                      tokens: tokens,
                      text: text,
                      onGrant: () async {
                        await SystemService.openUsageAccess();
                        await _loadPermissions();
                      },
                    ),
                    const Divider(height: 1),
                    _PermissionTile(
                      title: AppStrings.of(context).permissionPhone,
                      granted: _phone,
                      grantedText: AppStrings.of(context).permissionGranted,
                      deniedText: AppStrings.of(context).permissionDenied,
                      goGrantText: AppStrings.of(context).permissionGoGrant,
                      tokens: tokens,
                      text: text,
                      onGrant: () async {
                        await SystemService.requestPhonePermission();
                        await _loadPermissions();
                      },
                    ),
                    const Divider(height: 1),
                    _PermissionTile(
                      title: AppStrings.of(context).permissionLocation,
                      granted: _location,
                      grantedText: AppStrings.of(context).permissionGranted,
                      deniedText: AppStrings.of(context).permissionDenied,
                      goGrantText: AppStrings.of(context).permissionGoGrant,
                      tokens: tokens,
                      text: text,
                      onGrant: () async {
                        await SystemService.requestLocationPermission();
                        await _loadPermissions();
                      },
                    ),
                    const Divider(height: 1),
                    _PermissionTile(
                      title: AppStrings.of(context).permissionWifi,
                      granted: _wifi,
                      grantedText: AppStrings.of(context).permissionGranted,
                      deniedText: AppStrings.of(context).permissionDenied,
                      goGrantText: AppStrings.of(context).permissionGoGrant,
                      tokens: tokens,
                      text: text,
                      onGrant: () async {
                        await SystemService.requestWifiPermission();
                        await _loadPermissions();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded,
                      color: tokens.danger),
                  title: Text(AppStrings.of(context).clearData,
                      style:
                          text.bodyLarge?.copyWith(color: tokens.danger)),
                  subtitle: Text(AppStrings.of(context).clearDataDesc,
                      style: text.bodySmall
                          ?.copyWith(color: tokens.textSecondary)),
                  onTap: _clearData,
                ),
              ),
              const SizedBox(height: 20),
              // 更新
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.system_update_rounded,
                          color: tokens.accent),
                      title: Text(
                        AppStrings.of(context).checkUpdate,
                        style: text.bodyLarge
                            ?.copyWith(color: tokens.textPrimary),
                      ),
                      subtitle: Text(
                        _checkingUpdate
                            ? AppStrings.of(context).checkingUpdate
                            : (_updateMessage ??
                                AppStrings.of(context).checkUpdateDesc),
                        style: text.bodySmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                      trailing: _checkingUpdate
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.chevron_right_rounded,
                              color: tokens.textDisabled),
                      onTap: _checkingUpdate ? null : _checkUpdate,
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 56,
                      color: tokens.outlineSoft,
                    ),
                    SwitchListTile(
                      secondary: Icon(Icons.autorenew_rounded,
                          color: tokens.accent),
                      title: Text(
                        AppStrings.of(context).autoCheckUpdate,
                        style: text.bodyLarge
                            ?.copyWith(color: tokens.textPrimary),
                      ),
                      subtitle: Text(
                        AppStrings.of(context).autoCheckUpdateDesc,
                        style: text.bodySmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                      value: _autoCheckUpdate,
                      onChanged: (value) async {
                        setState(() => _autoCheckUpdate = value);
                        final prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setBool(_kAutoUpdateKey, value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Text(
                      '${AppStrings.of(context).frameStage} $kAppVersionLabel',
                      style: text.bodySmall
                          ?.copyWith(color: tokens.textDisabled),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.of(context).aboutDesc,
                      style: text.labelSmall
                          ?.copyWith(color: tokens.textDisabled),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.granted,
    required this.grantedText,
    required this.deniedText,
    required this.goGrantText,
    required this.tokens,
    required this.text,
    required this.onGrant,
  });

  final String title;
  final bool granted;
  final String grantedText;
  final String deniedText;
  final String goGrantText;
  final AppTokens tokens;
  final TextTheme text;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: text.bodyLarge?.copyWith(color: tokens.textPrimary),
      ),
      subtitle: Text(
        granted ? grantedText : deniedText,
        style: text.bodySmall?.copyWith(
          color: granted ? tokens.success : tokens.textSecondary,
        ),
      ),
      trailing: granted
          ? Icon(Icons.check_circle_rounded, color: tokens.success, size: 20)
          : TextButton(onPressed: onGrant, child: Text(goGrantText)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, {required this.tokens, required this.text});

  final String label;
  final AppTokens tokens;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
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

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final AppTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? tokens.textPrimary : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}

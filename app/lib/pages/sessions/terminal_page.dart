import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';
import '../../services/terminal_registry.dart';
import '../../services/qshell_config.dart';

import 'memo_page.dart';
import '../../services/ssh_connector.dart';
import '../../state/theme_controller.dart';
import '../../state/theme_scope.dart';
import '../../widgets/settings_action.dart';

/// 全屏终端会话页：独立路由，不显示悬浮底栏。
class TerminalPage extends StatefulWidget {
  const TerminalPage({
    super.key,
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    this.keyPath,
    this.passphrase,
    this.proxyHost,
    this.proxyPort,
    this.proxyUser,
    this.proxyPwd,
  });

  final String host;
  final int port;
  final String user;
  final String password;

  // 跳板机（ProxyJump）
  final String? keyPath;
  final String? passphrase;

  final String? proxyHost;
  final int? proxyPort;
  final String? proxyUser;
  final String? proxyPwd;

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  SSHClient? _client;
  SSHClient? _jumpClient;
  SSHSession? _session;
  Terminal? _terminal;
  final TerminalController _terminalController = TerminalController();
  StreamSubscription<Uint8List>? _stdoutSub;

  bool _connecting = true;
  bool _connected = false;
  bool _stickyCtrl = false;
  String? _error;

  /// 页面是否已销毁（用于避免重连定时器在退出后还跑）
  bool _disposed = false;
  int _retry = 0;
  Timer? _reconnectTimer;

  /// 防止同一次按键触发两次 onOutput（键盘大写 / IME 提交时会发生）
  DateTime? _lastCtrlAt;
  String? _lastCtrlChar;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _teardown();
    super.dispose();
  }

  void _teardown() {
    _stdoutSub?.cancel();
    _stdoutSub = null;
    _session?.close();
    _session = null;
    _client?.close();
    _jumpClient?.close();
    _jumpClient = null;
    _client = null;
    // 从保活通知里注销这个终端；没有终端后服务自动停
    unawaited(TerminalRegistry.unregister(_terminalName));
  }

  /// 意外断线后自动重连（后台被系统掐网络时很有用）。
  void _scheduleReconnect() {
    if (_disposed) return;
    if (_retry >= 5) {
      _terminal?.write('\r\n\x1b[31m${AppStrings.of(context).termReconnectFailed}\x1b[0m\r\n');
      return;
    }
    _retry++;
    final delay = _retry == 1 ? 2 : 3;
    _terminal?.write(
      '\r\n\x1b[33m[$delay 秒后自动重连（第 $_retry 次）]\x1b[0m\r\n',
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_disposed) return;
      _connect();
    });
  }

  String get _terminalName => '${widget.user}@${widget.host}';

  void _logSsh(String? message) => debugPrint('SSH: $message');

  Future<void> _connect() async {
    try {
      // 有跳板就先连跳板，再经 direct-tcpip 通道连目标
      final connection = await SshConnector.connect(
        host: widget.host,
        port: widget.port,
        user: widget.user,
        password: widget.password,
        keyPath: widget.keyPath,
        passphrase: widget.passphrase,
        proxyHost: widget.proxyHost,
        proxyPort: widget.proxyPort,
        proxyUser: widget.proxyUser,
        proxyPwd: widget.proxyPwd,
        // 协议级日志（调试构建）：定位后台断连到底是 EOF、RST 还是超时
        printDebug: kDebugMode ? _logSsh : null,
      );
      _jumpClient = connection.jumpClient;
      final client = connection.client;

      // 重连时复用同一个 Terminal，保留此前的输出历史
      final terminal = _terminal ?? Terminal(maxLines: 10000);
      final session = await client.shell(
        pty: const SSHPtyConfig(
          type: 'xterm-256color',
          width: 80,
          height: 24,
        ),
      );

      terminal.onOutput = (data) {
        final now = DateTime.now();

        if (_stickyCtrl) {
          // 粘滞 Ctrl 生效时，输入法确认用的回车直接吞掉，别让它当命令执行
          if (data == '\n' || data == '\r') return;
          if (data.isEmpty) return;

          var out = data;
          if (data.length == 1) {
            final unit = data.toUpperCase().codeUnitAt(0);
            if (unit >= 0x40 && unit <= 0x5F) {
              out = String.fromCharCode(unit - 0x40);
            }
          }
          _stickyCtrl = false;
          _lastCtrlAt = now;
          // 记录的是「原始输入」，便于后面按大小写不敏感去重
          _lastCtrlChar = data;
          if (mounted) setState(() {});
          session.stdin.add(utf8.encode(out));
          return;
        }

        // 同一按键的重复回调（大小写不同也算重复），丢掉
        if (_lastCtrlAt != null &&
            now.difference(_lastCtrlAt!).inMilliseconds < 400 &&
            _lastCtrlChar != null &&
            data.toLowerCase() == _lastCtrlChar!.toLowerCase()) {
          return;
        }
        session.stdin.add(utf8.encode(data));
      };
      terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        session.resizeTerminal(width, height);
      };

      _stdoutSub = session.stdout.listen(
        (data) {
          terminal.write(utf8.decode(data, allowMalformed: true));
        },
        onError: (Object e) {
          debugPrint('QShellTerminal: stdout error → $e');
        },
        onDone: () {
          debugPrint('QShellTerminal: stdout done');
        },
      );

      session.done.then((_) {
        debugPrint('QShellTerminal: session done（连接断开）');
        if (!mounted || _disposed) return;
        setState(() => _connected = false);
        terminal.write('\r\n\x1b[31m${AppStrings.of(context).termDisconnected}\x1b[0m\r\n');
        _teardown();
        // 非主动退出 → 自动重连（后台被系统掐网络时很有用）
        _scheduleReconnect();
      });

      setState(() {
        _client = client;
        _session = session;
        _terminal = terminal;
        _connected = true;
        _connecting = false;
        _error = null;
      });
      _retry = 0;
      // 连接成功 → 登记到保活通知，退到后台不被冻结
      unawaited(TerminalRegistry.register(_terminalName));
    } catch (e) {
      if (_disposed) return;
      // 重连尝试中失败：不弹错误页，安静地进入下一次重试
      if (_retry > 0 && _retry < 5) {
        _scheduleReconnect();
        return;
      }
      setState(() {
        _error = _friendlyError(e);
        _connecting = false;
      });
    }
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    final lower = text.toLowerCase();
    // 只认真正的认证失败，避免把 socket/传输错误误判成密码错误
    if (lower.contains('authentication failed') ||
        lower.contains('auth fail') ||
        lower.contains('permission denied') ||
        lower.contains('unable to authenticate')) {
      return AppStrings.of(context).termAuthFailed;
    }
    if (lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('connection abort') ||
        lower.contains('connection reset') ||
        lower.contains('broken pipe')) {
      return AppStrings.of(context).termNetworkLost;
    }
    if (lower.contains('refused')) {
      return AppStrings.of(context).termConnRefused;
    }
    if (lower.contains('unreachable')) {
      return AppStrings.of(context).termNetworkUnreachable;
    }
    return '连接失败：$text';
  }

  void _sendKey(String data) {
    _session?.stdin.add(utf8.encode(data));
  }

  /// 终端背景：优先背景图（加 45% 暗幕保证文字可读），否则用背景色/主题色。
  BoxDecoration _terminalBackground(AppTokens tokens, ThemeController controller) {
    final imagePath = controller.terminalBgImage;
    final color = controller.terminalBgColor ?? tokens.background;
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return BoxDecoration(
          color: color,
          image: DecorationImage(
            image: FileImage(file),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.45),
              BlendMode.darken,
            ),
          ),
        );
      }
    }
    return BoxDecoration(color: color);
  }

  /// 自动文字色：有背景图时按暗幕后的亮度用浅色；否则按背景色亮度取。
  Color _autoForeground(AppTokens tokens, ThemeController controller) {
    final imagePath = controller.terminalBgImage;
    if (imagePath != null &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync()) {
      // 背景图叠了 45% 黑色暗幕，整体偏暗
      return const Color(0xFFD8DEE9);
    }
    final bg = controller.terminalBgColor ?? tokens.background;
    return bg.computeLuminance() < 0.5
        ? const Color(0xFFD8DEE9)
        : const Color(0xFF111318);
  }

  /// 对比度兜底：用户手动设的文字色如果和当前背景太接近（比如白字 + 日间白底），
  /// 自动换成该背景下可读的颜色。
  Color _ensureReadable(
    Color fg,
    AppTokens tokens,
    ThemeController controller,
  ) {
    final imagePath = controller.terminalBgImage;
    final double bgLuminance;
    if (imagePath != null &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync()) {
      bgLuminance = 0.12; // 45% 暗幕后的近似亮度
    } else {
      bgLuminance = (controller.terminalBgColor ?? tokens.background)
          .computeLuminance();
    }
    final diff = (fg.computeLuminance() - bgLuminance).abs();
    if (diff >= 0.35) return fg;
    return bgLuminance > 0.5
        ? const Color(0xFF111318)
        : const Color(0xFFD8DEE9);
  }

  /// 基于默认主题换前景色（xterm 的 TerminalTheme 没有 copyWith）。
  TerminalTheme _terminalTheme(Color foreground) {
    const base = TerminalThemes.defaultTheme;
    return TerminalTheme(
      cursor: foreground,
      selection: foreground.withValues(alpha: 0.28),
      foreground: foreground,
      background: Colors.transparent,
      black: base.black,
      red: base.red,
      green: base.green,
      yellow: base.yellow,
      blue: base.blue,
      magenta: base.magenta,
      cyan: base.cyan,
      white: base.white,
      brightBlack: base.brightBlack,
      brightRed: base.brightRed,
      brightGreen: base.brightGreen,
      brightYellow: base.brightYellow,
      brightBlue: base.brightBlue,
      brightMagenta: base.brightMagenta,
      brightCyan: base.brightCyan,
      brightWhite: base.brightWhite,
      searchHitBackground: base.searchHitBackground,
      searchHitBackgroundCurrent: base.searchHitBackgroundCurrent,
      searchHitForeground: base.searchHitForeground,
    );
  }

  /// 备忘录：选中即发送到终端（不是只复制）
  Future<void> _showMemos() async {
    final groups = await QShellConfigStore().loadMemos();
    if (!mounted) return;
    if (groups.every((group) => group.items.isEmpty)) {
      _toast(AppStrings.of(context).termNoMemos);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final tokens = AppTokens.of(context);
        final text = Theme.of(context).textTheme;
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            builder: (context, scrollController) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.of(context).termMemoSheetTitle,
                        style: text.labelMedium?.copyWith(
                          color: tokens.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MemoPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('新建'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                for (final group in groups.where((g) => g.items.isNotEmpty)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
                    child: Text(
                      group.group.isEmpty ? AppStrings.of(context).memoNoGroup : group.group,
                      style: text.labelSmall
                          ?.copyWith(color: tokens.textDisabled),
                    ),
                  ),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < group.items.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: tokens.outlineSoft,
                            ),
                          ListTile(
                            dense: true,
                            leading: Icon(Icons.terminal_rounded,
                                size: 16, color: tokens.accent),
                            title: Text(
                              group.items[i].name.isEmpty
                                  ? group.items[i].cmd
                                  : group.items[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium
                                  ?.copyWith(color: tokens.textPrimary),
                            ),
                            subtitle: Text(
                              group.items[i].cmd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall?.copyWith(
                                color: tokens.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _sendKey('${group.items[i].cmd}\n');
                              _toast(AppStrings.of(context).termSentTemplate.replaceAll('{cmd}', group.items[i].cmd));
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _copySelection() async {
    final selection = _terminalController.selection;
    final terminal = _terminal;
    if (selection == null || terminal == null) {
      _toast(AppStrings.of(context).terminalSelectFirst);
      return;
    }
    final text = terminal.buffer.getText(selection);
    if (text.trim().isEmpty) {
      _toast(AppStrings.of(context).terminalSelectionEmpty);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final strings = AppStrings.of(context);
    _toast(strings.terminalCopiedTemplate.replaceAll('{n}', '${text.length}'));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text == null || text.isEmpty) {
      _toast(AppStrings.of(context).terminalClipboardEmpty);
      return;
    }
    _sendKey(text);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final themeController = ThemeScope.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.user}@${widget.host}'),
            Text(
              _connecting
                  ? AppStrings.of(context).termConnecting
                  : (_connected ? '已连接 · ${widget.port}' : (_error ?? AppStrings.of(context).termDisconnectedState)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                color: _connected ? tokens.success : tokens.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (_connected) ...[
            IconButton(
              tooltip: AppStrings.of(context).terminalCopy,
              onPressed: _copySelection,
              icon: const Icon(Icons.copy_rounded),
            ),
            IconButton(
              tooltip: AppStrings.of(context).terminalPaste,
              onPressed: _paste,
              icon: const Icon(Icons.paste_rounded),
            ),
            IconButton(
              tooltip: AppStrings.of(context).memoTitle,
              onPressed: _showMemos,
              icon: const Icon(Icons.sticky_note_2_outlined),
            ),
          ],
          const SettingsAction(),
        ],
      ),
      // 只要建立过终端就一直显示终端视图（重连中/重连失败也保留历史输出）
      body: _terminal != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: _terminalBackground(tokens, themeController),
                    child: TerminalView(
                      _terminal!,
                      controller: _terminalController,
                      autofocus: true,
                      // 终端自身背景透明，露出外层背景色 / 背景图
                      backgroundOpacity: 0,
                      // 文字色：用户指定优先，但对比度不够时自动兜底
                      theme: _terminalTheme(
                        _ensureReadable(
                          themeController.terminalFgColor ??
                              _autoForeground(tokens, themeController),
                          tokens,
                          themeController,
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      textStyle:
                          TerminalStyle(fontSize: themeController.terminalFontSize),
                    ),
                  ),
                ),
                _KeyStrip(
                  onSend: _sendKey,
                  stickyCtrl: _stickyCtrl,
                  onToggleCtrl: () =>
                      setState(() => _stickyCtrl = !_stickyCtrl),
                ),
              ],
            )
          : _buildStatus(tokens, text),
    );
  }

  Widget _buildStatus(AppTokens tokens, TextTheme text) {
    if (_connecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '正在连接 ${widget.host}:${widget.port}',
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: tokens.textDisabled),
            const SizedBox(height: 12),
            Text(
              _error ?? '连接已断开',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 功能键条：铺满屏幕宽度，底色与终端区分。
class _KeyStrip extends StatelessWidget {
  const _KeyStrip({
    required this.onSend,
    required this.stickyCtrl,
    required this.onToggleCtrl,
  });

  final void Function(String data) onSend;
  final bool stickyCtrl;
  final VoidCallback onToggleCtrl;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    const gap = SizedBox(width: 4);
    return Container(
      width: double.infinity,
      color: tokens.surfaceCard,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 两行各 6 个键、宽度均分，避免方向键块整体换行造成的凹凸
              Row(
                children: [
                  _flex(context, 'Ctrl', onToggleCtrl, active: stickyCtrl),
                  gap,
                  _flex(context, 'Tab', () => onSend('\t')),
                  gap,
                  _flex(context, 'Esc', () => onSend('\x1b')),
                  gap,
                  _flex(context, 'Ctrl+C', () => onSend('\x03')),
                  gap,
                  _flex(context, '↑', () => onSend('\x1b[A')),
                  gap,
                  _flex(context, 'Ctrl+D', () => onSend('\x04')),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _flex(context, '|', () => onSend('|')),
                  gap,
                  _flex(context, '-', () => onSend('-')),
                  gap,
                  _flex(context, '/', () => onSend('/')),
                  gap,
                  _flex(context, '←', () => onSend('\x1b[D')),
                  gap,
                  _flex(context, '↓', () => onSend('\x1b[B')),
                  gap,
                  _flex(context, '→', () => onSend('\x1b[C')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flex(
    BuildContext context,
    String label,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return Expanded(
      child: SizedBox(
        height: 38,
        child: _button(
          context,
          label: label,
          onTap: onTap,
          active: active,
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final tokens = AppTokens.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: active ? tokens.accent : tokens.surfaceCardAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: active ? tokens.accent : tokens.outlineSoft,
          ),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? tokens.onAccent : tokens.textPrimary,
        ),
      ),
    );
  }
}

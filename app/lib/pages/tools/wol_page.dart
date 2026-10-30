import 'package:flutter/material.dart';

import '../../widgets/tool_layout.dart';
import '../../i18n/app_strings.dart';
import '../../services/tools/wol.dart';

/// Wake On LAN：发送魔术包。
class WolPage extends StatefulWidget {
  const WolPage({super.key});

  @override
  State<WolPage> createState() => _WolPageState();
}

class _WolPageState extends State<WolPage> {
  final _macCtrl = TextEditingController();
  final _broadcastCtrl = TextEditingController(text: '255.255.255.255');
  final _portCtrl = TextEditingController(text: '9');

  bool _sending = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _macCtrl.dispose();
    _broadcastCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
      _success = null;
    });
    try {
      final port = int.tryParse(_portCtrl.text.trim()) ?? 9;
      await WolService.send(
        mac: _macCtrl.text,
        broadcast: _broadcastCtrl.text,
        port: port,
      );
      if (!mounted) return;
      final mac = WolService.parseMac(_macCtrl.text);
      setState(() {
        _sending = false;
        _success = mac == null
            ? '已发送'
            : '已发送 3 次魔术包 → ${WolService.formatMac(mac)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Wake On LAN')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ToolCard(
            children: [
              ToolField(
                label: 'MAC',
                controller: _macCtrl,
                hint: 'AA:BB:CC:DD:EE:FF',
              ),
              ToolField(
                label: '广播',
                controller: _broadcastCtrl,
                hint: '255.255.255.255 或 192.168.1.255',
              ),
              ToolField(
                label: '端口',
                controller: _portCtrl,
                hint: '9',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ToolPrimaryButton(
            onPressed: _sending ? null : _send,
            label: AppStrings.of(context).commonSendMagic,
            icon: Icons.power_settings_new_rounded,
            loading: _sending,
            loadingLabel: AppStrings.of(context).commonSending,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ToolNotice(message: _error!, error: true),
          ],
          if (_success != null) ...[
            const SizedBox(height: 12),
            ToolNotice(message: _success!),
          ],
        ],
      ),
    );
  }

}

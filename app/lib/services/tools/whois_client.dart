import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 一次 whois 查询结果。
class WhoisResult {
  const WhoisResult({required this.server, required this.text});

  final String server;
  final String text;
}

/// whois 查询：先问 IANA，再跟随它给出的 refer 服务器查一次。
///
/// 走 TCP 43，纯 Dart，不需要原生。
class WhoisClient {
  static const _iana = 'whois.iana.org';
  static const _timeout = Duration(seconds: 12);

  Future<WhoisResult> query(String target) async {
    final cleaned = _clean(target);
    if (cleaned.isEmpty) throw const FormatException('请输入域名或 IP');

    final ianaText = await _ask(_iana, cleaned);
    final refer = _extractRefer(ianaText);
    if (refer == null || refer == _iana) {
      return WhoisResult(server: _iana, text: ianaText);
    }

    try {
      final text = await _ask(refer, cleaned);
      return WhoisResult(server: refer, text: text);
    } catch (_) {
      return WhoisResult(server: _iana, text: ianaText);
    }
  }

  String _clean(String raw) {
    var text = raw.trim();
    if (text.startsWith('http://')) text = text.substring(7);
    if (text.startsWith('https://')) text = text.substring(8);
    final slash = text.indexOf('/');
    if (slash >= 0) text = text.substring(0, slash);
    return text;
  }

  String? _extractRefer(String text) {
    for (final line in const LineSplitter().convert(text)) {
      if (line.toLowerCase().startsWith('refer:')) {
        return line.substring(6).trim();
      }
    }
    return null;
  }

  Future<String> _ask(String server, String query) async {
    Socket? socket;
    try {
      socket = await Socket.connect(server, 43, timeout: _timeout);
      socket.write('$query\r\n');
      await socket.flush();

      final buffer = <int>[];
      await for (final chunk in socket.timeout(_timeout)) {
        buffer.addAll(chunk);
        if (buffer.length > 512 * 1024) break;
      }
      final text = utf8.decode(buffer, allowMalformed: true);
      if (text.trim().isEmpty) {
        throw const FormatException('whois 服务器没有返回内容');
      }
      return text;
    } finally {
      socket?.destroy();
    }
  }
}

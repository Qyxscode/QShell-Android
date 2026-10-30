import 'dart:convert';

import 'package:http/http.dart' as http;

/// IP 归属地查询（ip-api.com，免费、无需 key）。
///
/// 结果缓存，避免同一次 traceroute 里重复请求同一跳。
class IpGeo {
  IpGeo._();

  static final Map<String, String> _cache = <String, String>{};

  /// 返回形如「日本 · 东京 · 某 ISP」的描述；查不到返回 null。
  static Future<String?> lookup(String ip) async {
    if (ip.isEmpty) return null;
    final cached = _cache[ip];
    if (cached != null) return cached.isEmpty ? null : cached;
    try {
      final resp = await http
          .get(Uri.parse(
            'http://ip-api.com/json/$ip?fields=status,country,regionName,city,isp&lang=zh-CN',
          ))
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['status'] != 'success') {
        _cache[ip] = '';
        return null;
      }
      final parts = <String>[
        if ((data['country'] as String?)?.isNotEmpty == true)
          data['country'] as String,
        if ((data['regionName'] as String?)?.isNotEmpty == true)
          data['regionName'] as String,
        if ((data['isp'] as String?)?.isNotEmpty == true)
          data['isp'] as String,
      ];
      final text = parts.join(' · ');
      _cache[ip] = text;
      return text.isEmpty ? null : text;
    } catch (_) {
      _cache[ip] = '';
      return null;
    }
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

/// 一次发布信息（来自 GitHub Releases）。
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.notes,
    required this.pageUrl,
    required this.apkUrl,
    required this.publishedAt,
  });

  /// 形如 v1.0.0+12
  final String tag;
  final String name;
  final String notes;
  final String pageUrl;

  /// 第一个 .apk 资源的下载直链，没有则为空
  final String apkUrl;
  final DateTime? publishedAt;

  /// tag 里的版本号部分（v1.0.0+12 → 1.0.0+12）
  String get version => tag.startsWith('v') ? tag.substring(1) : tag;
}

/// 检查 GitHub Releases 上有没有新版本。
class UpdateService {
  UpdateService._();

  /// 更新源仓库（独立仓库）
  static const String _defaultRepo = 'Qyxscode/QShell-Android';

  /// 更新源仓库（owner/repo）。留空表示未配置。
  static String get defaultRepo => _defaultRepo;

  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'QShell-Android',
  };

  /// 拉取最新 release；[repo] 形如 `owner/name`。
  static Future<ReleaseInfo?> latest(String repo) async {
    if (repo.trim().isEmpty) return null;
    final uri = Uri.parse('https://api.github.com/repos/${repo.trim()}/releases/latest');
    final resp = await http.get(uri, headers: _headers).timeout(
          const Duration(seconds: 12),
        );
    if (resp.statusCode != 200) {
      throw Exception('GitHub 返回 ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final assets = (data['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    String apkUrl = '';
    for (final asset in assets) {
      final name = (asset['name'] as String?) ?? '';
      if (name.toLowerCase().endsWith('.apk')) {
        apkUrl = (asset['browser_download_url'] as String?) ?? '';
        break;
      }
    }
    return ReleaseInfo(
      tag: (data['tag_name'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      notes: (data['body'] as String?) ?? '',
      pageUrl: (data['html_url'] as String?) ?? '',
      apkUrl: apkUrl,
      publishedAt: DateTime.tryParse((data['published_at'] as String?) ?? ''),
    );
  }

  /// 判断 [remote] 是否比 [local] 新。
  ///
  /// 只比较 `+` 后面的构建号；没有构建号时按语义版本比较前三段。
  static bool isNewer(String remote, String local) {
    final r = _parse(remote);
    final l = _parse(local);
    if (r == null || l == null) return false;
    if (r.build != l.build) return r.build > l.build;
    if (r.major != l.major) return r.major > l.major;
    if (r.minor != l.minor) return r.minor > l.minor;
    return r.patch > l.patch;
  }

  static _Ver? _parse(String value) {
    final cleaned = value.trim().replaceFirst('v', '');
    final parts = cleaned.split('+');
    final semver = parts.first.split('.');
    final build = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return _Ver(
      major: int.tryParse(semver.isNotEmpty ? semver[0] : '') ?? 0,
      minor: int.tryParse(semver.length > 1 ? semver[1] : '') ?? 0,
      patch: int.tryParse(semver.length > 2 ? semver[2] : '') ?? 0,
      build: build,
    );
  }
}

class _Ver {
  const _Ver({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;
}

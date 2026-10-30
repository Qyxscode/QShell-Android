import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// WebDAV 目录项。
class WebdavEntry {
  const WebdavEntry({
    required this.href,
    required this.name,
    required this.isDirectory,
    required this.size,
    this.modified,
  });

  final String href;
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
}

/// 最小可用的 WebDAV 客户端：PROPFIND 列表 + GET / PUT / DELETE / MKCOL。
///
/// 兼容 Nextcloud、坚果云、群晖、Nginx dav 等常见实现。
class WebdavClient {
  WebdavClient({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  /// 形如 https://example.com/dav
  final String baseUrl;
  final String username;
  final String password;

  static const Duration _timeout = Duration(seconds: 20);

  Map<String, String> get _authHeaders => <String, String>{
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      };

  /// 内部一律用「相对 baseUrl 的路径」（'' 表示根），
  /// 这里再拼回完整 URL，并用 pathSegments 让中文等字符正确编码。
  Uri _resolve(String relativePath) {
    final base = Uri.parse(_normalizeBase(baseUrl));
    final baseSegments =
        base.pathSegments.where((segment) => segment.isNotEmpty).toList();
    final segments =
        relativePath.split('/').where((segment) => segment.isNotEmpty).toList();
    final uri = base.replace(
      pathSegments: <String>[...baseSegments, ...segments],
      query: null,
    );
    debugPrint('WebDAV: $uri');
    return uri;
  }

  /// 把服务器返回的 href（可能是完整 URL、带 BaseURL 的绝对路径、相对路径）
  /// 统一转成相对 baseUrl 的路径（已解码）。
  /// 把用户填的地址规整成可解析的 URI（非法百分号按普通字符处理）。
  static String _normalizeBase(String raw) {
    final trimmed = raw.trim();
    try {
      Uri.parse(trimmed);
      return trimmed;
    } catch (_) {
      // 逐段编码后再拼回去
      final uri = Uri.tryParse(Uri.encodeFull(trimmed));
      return uri?.toString() ?? trimmed;
    }
  }

  static String _safeDecode(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  /// 用服务器返回的 href 构造下载/读取 URL。
  ///
  /// WebDAV 的 href 通常相对**服务器根**（如 `/dir/a.zip`），
  /// 而 baseUrl 可能自带子目录（如 `https://host/dav`）。
  /// 直接拿 href 的绝对路径替换 base 的 path，避免 `dav/dav/a.zip` 这种重复拼接。
  Uri uriOf(String href) {
    final raw = href.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Uri.parse(raw);
    }
    final base = Uri.parse(_normalizeBase(baseUrl));
    final decoded = _safeDecode(raw);
    final absolute = decoded.startsWith('/') ? decoded : '/$decoded';
    return base.replace(path: absolute, query: null);
  }

  String relativePathOf(String href) {
    var path = href.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      path = Uri.parse(path).path;
    }
    // href 可能含非法百分号（如文件名带 %），解码失败就用原串
    path = _safeDecode(path);

    final base = Uri.parse(_normalizeBase(baseUrl));
    final basePath = base.path;
    final baseWithSlash = basePath.endsWith('/') ? basePath : '$basePath/';
    final baseNoSlash =
        basePath.endsWith('/') ? basePath.substring(0, basePath.length - 1) : basePath;

    if (baseWithSlash.isNotEmpty && path.startsWith(baseWithSlash)) {
      return path.substring(baseWithSlash.length);
    }
    if (baseNoSlash.isNotEmpty && path == baseNoSlash) return '';
    if (baseNoSlash.isNotEmpty && path.startsWith('$baseNoSlash/')) {
      return path.substring(baseNoSlash.length + 1);
    }
    if (path.startsWith('/')) return path.substring(1);
    return path;
  }

  Future<List<WebdavEntry>> list(String path) async {
    final client = http.Client();
    try {
      final request = http.Request('PROPFIND', _resolve(path))
        ..headers.addAll(_authHeaders)
        ..headers['Depth'] = '1'
        ..headers['Content-Type'] = 'application/xml; charset=utf-8'
        ..body = '<?xml version="1.0" encoding="utf-8"?>'
            '<d:propfind xmlns:d="DAV:"><d:prop>'
            '<d:displayname/><d:getcontentlength/><d:getlastmodified/>'
            '<d:resourcetype/><d:href/>'
            '</d:prop></d:propfind>';
      final streamed = await client.send(request).timeout(_timeout);
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 401) {
        throw Exception('认证失败（401）：检查用户名/密码');
      }
      if (streamed.statusCode == 404) {
        throw Exception('路径不存在（404）');
      }
      if (streamed.statusCode >= 400) {
        throw Exception('HTTP ${streamed.statusCode}');
      }
      return _parseMultiStatus(body, path);
    } finally {
      client.close();
    }
  }

  List<WebdavEntry> _parseMultiStatus(String xmlText, String basePath) {
    final doc = XmlDocument.parse(xmlText);
    final entries = <WebdavEntry>[];
    final normalizedBase = basePath.trim();

    for (final response in doc.descendants.whereType<XmlElement>()) {
      if (response.localName != 'response') continue;

      String href = '';
      String displayName = '';
      int size = 0;
      DateTime? modified;
      var isDirectory = false;

      for (final node in response.descendants.whereType<XmlElement>()) {
        switch (node.localName) {
          case 'href':
            if (href.isEmpty) href = node.innerText.trim();
          case 'displayname':
            displayName = node.innerText.trim();
          case 'getcontentlength':
            size = int.tryParse(node.innerText.trim()) ?? 0;
          case 'getlastmodified':
            modified = _parseHttpDate(node.innerText.trim());
          case 'collection':
            isDirectory = true;
        }
      }

      if (href.isEmpty) continue;

      final relative = relativePathOf(href);
      debugPrint('WebDAV href="$href" -> "$relative" (in "$normalizedBase")');
      // 跳过当前目录自己
      final normalizedRelative = relative.endsWith('/')
          ? relative.substring(0, relative.length - 1)
          : relative;
      if (normalizedRelative == normalizedBase) continue;
      if (normalizedRelative.isEmpty && normalizedBase.isEmpty) continue;

      final segments = normalizedRelative
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();
      if (segments.isEmpty) continue;
      final name = displayName.isNotEmpty ? displayName : segments.last;
      if (name.isEmpty) continue;

      entries.add(
        WebdavEntry(
          href: normalizedRelative,
          name: name,
          isDirectory: isDirectory,
          size: size,
          modified: modified,
        ),
      );
    }

    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  DateTime? _parseHttpDate(String value) => _parseDate(value);

  /// 按 href 直接下载（href 相对服务器根，避免 base 子目录重复拼接）
  Future<Uint8List> downloadHref(String href) =>
      downloadUri(uriOf(href));

  Future<Uint8List> downloadUri(Uri uri) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)
        ..headers.addAll(_authHeaders);
      final streamed = await client.send(request).timeout(_timeout);
      if (streamed.statusCode >= 400) {
        throw Exception('下载失败：HTTP ${streamed.statusCode}（$uri）');
      }
      return await streamed.stream.toBytes();
    } finally {
      client.close();
    }
  }

  Future<Uint8List> download(
    String path, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = http.Client();
    final uri = _resolve(path);
    try {
      final request = http.Request('GET', uri)..headers.addAll(_authHeaders);
      final streamed = await client.send(request).timeout(_timeout);
      if (streamed.statusCode >= 400) {
        throw Exception('下载失败：HTTP ${streamed.statusCode}（$uri）');
      }
      final total = streamed.contentLength ?? 0;
      final chunks = <int>[];
      await for (final chunk in streamed.stream) {
        chunks.addAll(chunk);
        onProgress?.call(chunks.length, total);
      }
      return Uint8List.fromList(chunks);
    } finally {
      client.close();
    }
  }

  Future<void> upload(String path, List<int> bytes, {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final response = await c
          .put(
            _resolve(path),
            headers: {
              ..._authHeaders,
              'Content-Type': 'application/octet-stream',
            },
            body: bytes,
          )
          .timeout(_timeout);
      if (response.statusCode >= 400) {
        throw Exception('上传失败：HTTP ${response.statusCode}');
      }
    } finally {
      if (client == null) c.close();
    }
  }

  Future<void> delete(String path) async {
    final client = http.Client();
    try {
      final response = await client
          .delete(_resolve(path), headers: _authHeaders)
          .timeout(_timeout);
      if (response.statusCode >= 400) {
        throw Exception('删除失败：HTTP ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// 重命名 / 移动（WebDAV MOVE）。
  Future<void> rename(String oldPath, String newPath) async {
    final client = http.Client();
    try {
      final response = await client
          .send(
            http.Request('MOVE', _resolve(oldPath))
              ..headers.addAll(_authHeaders)
              ..headers['Destination'] = _resolve(newPath).toString()
              ..headers['Overwrite'] = 'T',
          )
          .timeout(_timeout);
      await response.stream.drain<void>();
      if (response.statusCode >= 400) {
        throw Exception('重命名失败：HTTP ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  Future<void> mkdir(String path) async {
    final client = http.Client();
    try {
      final response = await client
          .send(
            http.Request('MKCOL', _resolve(path))
              ..headers.addAll(_authHeaders),
          )
          .timeout(_timeout);
      await response.stream.drain<void>();
      if (response.statusCode >= 400 && response.statusCode != 405) {
        throw Exception('新建目录失败：HTTP ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }
}

/// 轻量 HTTP 日期解析（不引 intl）。
DateTime? _parseDate(String value) {
  // 常见格式：Tue, 29 Oct 2026 12:00:00 GMT
  final match = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(value);
  if (match == null) {
    return DateTime.tryParse(value)?.toLocal();
  }
  const months = <String, int>{
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };
  final month = months[match.group(2)!.toLowerCase()];
  if (month == null) return null;
  return DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  ).toLocal();
}

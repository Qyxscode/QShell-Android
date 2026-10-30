/// IPv4 子网计算。
class IpCalcResult {
  const IpCalcResult({
    required this.input,
    required this.address,
    required this.prefix,
    required this.mask,
    required this.wildcard,
    required this.network,
    required this.broadcast,
    required this.firstHost,
    required this.lastHost,
    required this.hostCount,
    required this.className,
    required this.isPrivate,
  });

  final String input;
  final String address;
  final int prefix;
  final String mask;
  final String wildcard;
  final String network;
  final String broadcast;
  final String firstHost;
  final String lastHost;
  final int hostCount;
  final String className;
  final bool isPrivate;
}

/// 解析 `192.168.1.0/24`、`192.168.1.10 255.255.255.0`、单个 IP。
IpCalcResult? calculateIpv4(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  String ipPart;
  int? prefix;
  if (text.contains('/')) {
    final parts = text.split('/');
    if (parts.length != 2) return null;
    ipPart = parts[0].trim();
    prefix = int.tryParse(parts[1].trim());
  } else if (text.contains(' ')) {
    final parts = text.split(RegExp(r'\s+'));
    if (parts.length != 2) return null;
    ipPart = parts[0].trim();
    final maskParts = parts[1].trim().split('.');
    if (maskParts.length != 4) return null;
    var bits = 0;
    for (final m in maskParts) {
      final v = int.tryParse(m);
      if (v == null || v < 0 || v > 255) return null;
      bits += _bitCount(v);
    }
    prefix = bits;
  } else {
    ipPart = text;
    prefix = 32;
  }

  if (prefix == null || prefix < 0 || prefix > 32) return null;
  final ip = _parseIp(ipPart);
  if (ip == null) return null;

  final maskInt = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
  final network = ip & maskInt;
  final broadcast = network | (~maskInt & 0xFFFFFFFF);

  // 可用主机：/31 与 /32 特殊处理
  int hostCount;
  String firstHost;
  String lastHost;
  if (prefix >= 31) {
    hostCount = prefix == 32 ? 1 : 2;
    firstHost = prefix == 32 ? _formatIp(ip) : _formatIp(network);
    lastHost = prefix == 32 ? _formatIp(ip) : _formatIp(broadcast);
  } else {
    hostCount = broadcast - network - 1;
    firstHost = _formatIp(network + 1);
    lastHost = _formatIp(broadcast - 1);
  }

  final firstOctet = (ip >> 24) & 0xFF;
  final className = firstOctet < 128
      ? 'A 类'
      : firstOctet < 192
          ? 'B 类'
          : firstOctet < 224
              ? 'C 类'
              : firstOctet < 240
                  ? 'D 类（组播）'
                  : 'E 类（保留）';

  final isPrivate = _isPrivate(firstOctet, ip);

  return IpCalcResult(
    input: text,
    address: _formatIp(ip),
    prefix: prefix,
    mask: _formatIp(maskInt),
    wildcard: _formatIp(~maskInt & 0xFFFFFFFF),
    network: _formatIp(network),
    broadcast: _formatIp(broadcast),
    firstHost: firstHost,
    lastHost: lastHost,
    hostCount: hostCount < 0 ? 0 : hostCount,
    className: className,
    isPrivate: isPrivate,
  );
}

int? _parseIp(String text) {
  final parts = text.split('.');
  if (parts.length != 4) return null;
  var value = 0;
  for (final part in parts) {
    final v = int.tryParse(part);
    if (v == null || v < 0 || v > 255) return null;
    value = (value << 8) | v;
  }
  return value;
}

String _formatIp(int value) {
  final v = value & 0xFFFFFFFF;
  return '${(v >> 24) & 0xFF}.${(v >> 16) & 0xFF}.${(v >> 8) & 0xFF}.${v & 0xFF}';
}

int _bitCount(int v) {
  var count = 0;
  var x = v;
  while (x > 0) {
    count += x & 1;
    x >>= 1;
  }
  return count;
}

bool _isPrivate(int firstOctet, int ip) {
  final second = (ip >> 16) & 0xFF;
  if (firstOctet == 10) return true;
  if (firstOctet == 172 && second >= 16 && second <= 31) return true;
  if (firstOctet == 192 && second == 168) return true;
  if (firstOctet == 127) return true;
  if (firstOctet == 169 && second == 254) return true;
  return false;
}

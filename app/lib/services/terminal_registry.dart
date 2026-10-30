import 'package:flutter/foundation.dart';

import 'system_service.dart';

/// 活跃终端登记表：维护当前所有 SSH 会话的名称，
/// 每次变化都会刷新保活通知里的「当前已连接终端」文本。
class TerminalRegistry {
  TerminalRegistry._();

  static final Set<String> _active = <String>{};

  static List<String> get active => _active.toList();

  static Future<void> register(String name) async {
    if (_active.contains(name)) return;
    _active.add(name);
    debugPrint('TerminalRegistry: +$name → ${_active.length} 个终端');
    await SystemService.startKeepAlive(_active.toList());
  }

  static Future<void> unregister(String name) async {
    if (!_active.remove(name)) return;
    debugPrint('TerminalRegistry: -$name → ${_active.length} 个终端');
    if (_active.isEmpty) {
      await SystemService.stopKeepAlive();
    } else {
      await SystemService.startKeepAlive(_active.toList());
    }
  }

  /// 退出登录/全局清理时用
  static Future<void> clear() async {
    _active.clear();
    await SystemService.stopKeepAlive();
  }
}

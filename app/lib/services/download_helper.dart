import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'system_service.dart';

/// 下载落盘位置：应用私有目录 / 系统下载目录。
class DownloadHelper {
  static const _key = 'download.location';
  static const appLocation = 'app';
  static const downloadsLocation = 'downloads';

  static Future<String> getLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? appLocation;
  }

  static Future<void> setLocation(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
  }

  /// 下载时用的临时目录（先落这里，完成后按设置决定最终位置）。
  static Future<String> tempPath(String name) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/$name';
  }

  /// 把下载完成的文件放到用户选择的目录，返回最终路径 / URI。
  static Future<String> finalize(String tempFilePath, String name) async {
    final location = await getLocation();
    final file = File(tempFilePath);
    if (location == downloadsLocation) {
      try {
        final bytes = await file.readAsBytes();
        final uri = await SystemService.saveToDownloads(name, bytes);
        if (uri != null) {
          if (await file.exists()) {
            try {
              await file.delete();
            } catch (_) {}
          }
          return uri;
        }
      } catch (_) {
        // 失败就回退到应用目录
      }
    }
    final dir = await getApplicationDocumentsDirectory();
    final target = File('${dir.path}/$name');
    if (tempFilePath != target.path) {
      await file.copy(target.path);
      try {
        await file.delete();
      } catch (_) {}
    }
    return target.path;
  }

  /// 直接写字节（小文件用）。
  static Future<String> saveBytes(String name, Uint8List bytes) async {
    final location = await getLocation();
    if (location == downloadsLocation) {
      final uri = await SystemService.saveToDownloads(name, bytes);
      if (uri != null) return uri;
    }
    final dir = await getApplicationDocumentsDirectory();
    final target = File('${dir.path}/$name');
    await target.writeAsBytes(bytes);
    return target.path;
  }
}

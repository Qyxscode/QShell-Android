import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/design_switcher.dart';

enum ThemeModeChoice { system, light, dark }

/// 全局外观设置：设计语言、日夜模式、动态取色、强调色。
///
/// 所有设置持久化到 SharedPreferences；页面通过 Provider 式的监听刷新。
class ThemeController extends ChangeNotifier {
  static const _kMode = 'appearance.mode';
  static const _kDynamic = 'appearance.use_dynamic_color';
  static const _kSeed = 'appearance.seed';
  static const _kDesign = 'appearance.design_language';
  static const _kGlassRefraction = 'appearance.glass_refraction';
  static const _kGlassAllCards = 'appearance.glass_all_cards';
  static const _kWallpaper = 'appearance.wallpaper';
  static const _kWallpaperDim = 'appearance.wallpaper_dim';
  static const _kTerminalFontSize = 'terminal.font_size';
  static const _kTerminalBgColor = 'terminal.bg_color';
  static const _kTerminalBgImage = 'terminal.bg_image';
  static const _kTerminalFgColor = 'terminal.fg_color';

  DesignLanguage _designLanguage = DesignLanguage.md3;
  bool _glassRefraction = false;
  bool _glassAllCards = false;
  String? _wallpaper;
  double _wallpaperDim = 0.35;
  ThemeModeChoice _modeChoice = ThemeModeChoice.system;
  bool _useDynamicColor = true;
  Color _seed = accentPresets.first;
  double _terminalFontSize = 13;
  int? _terminalBgColor;
  String? _terminalBgImage;
  int? _terminalFgColor;

  DesignLanguage get designLanguage => _designLanguage;

  /// 液态玻璃档位 B：真实折射（fragment shader）
  bool get glassRefraction => _glassRefraction;

  /// 全量卡片启用真实折射（性能开销大，默认关）
  bool get glassAllCards => _glassAllCards;

  /// 自定义壁纸的本地文件路径（null = 用内置光斑）
  String? get wallpaper => _wallpaper;

  /// 壁纸压暗程度（0 = 原图，1 = 全黑）
  double get wallpaperDim => _wallpaperDim;
  ThemeModeChoice get modeChoice => _modeChoice;
  bool get useDynamicColor => _useDynamicColor;
  Color get seed => _seed;
  double get terminalFontSize => _terminalFontSize;

  /// 终端背景色；null 表示跟随主题
  Color? get terminalBgColor =>
      _terminalBgColor == null ? null : Color(_terminalBgColor!);

  /// 终端背景图片的本地路径；null 表示没有
  String? get terminalBgImage => _terminalBgImage;

  /// 终端文字色；null 表示按背景亮度自动取（亮底深字 / 暗底浅字）
  Color? get terminalFgColor =>
      _terminalFgColor == null ? null : Color(_terminalFgColor!);

  /// 终端文字色预设
  static const List<Color> terminalFgPresets = <Color>[
    Color(0xFFD8DEE9), // 浅灰
    Color(0xFF81C995), // 绿（桌面端默认）
    Color(0xFF8AB4F8), // 蓝
    Color(0xFFE8EAED), // 白
    Color(0xFFFFD54F), // 琥珀
    Color(0xFF111318), // 深灰（亮底用）
  ];

  /// 终端背景预设（彼此区分明显的中深色，不是一片近黑）
  static const List<Color> terminalBgPresets = <Color>[
    Color(0xFF2A3138), // 石板灰
    Color(0xFF21456B), // 深蓝
    Color(0xFF24513A), // 深绿
    Color(0xFF3E2C55), // 深紫
    Color(0xFF4E3A24), // 深棕
    Color(0xFF55292F), // 酒红
  ];

  static const double minTerminalFontSize = 10;
  static const double maxTerminalFontSize = 22;

  ThemeMode get themeMode => switch (_modeChoice) {
        ThemeModeChoice.system => ThemeMode.system,
        ThemeModeChoice.light => ThemeMode.light,
        ThemeModeChoice.dark => ThemeMode.dark,
      };

  /// 界面用这套预设色作为"强调色"来源（MD3 的 seed 色）。
  static const List<Color> accentPresets = <Color>[
    Color(0xFF3B5BDB), // 蓝
    Color(0xFF0B7285), // 青
    Color(0xFF2F9E44), // 绿
    Color(0xFFE8590C), // 橙
    Color(0xFFC2255C), // 玫红
    Color(0xFF7048E8), // 紫
    Color(0xFF495057), // 石墨
    Color(0xFFB08D57), // 金
  ];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _modeChoice = ThemeModeChoice.values[
        (prefs.getInt(_kMode) ?? ThemeModeChoice.system.index)
            .clamp(0, ThemeModeChoice.values.length - 1)];
    _useDynamicColor = prefs.getBool(_kDynamic) ?? true;
    final seedValue = prefs.getInt(_kSeed);
    if (seedValue != null) _seed = Color(seedValue);
    _designLanguage = DesignLanguage.values[
        (prefs.getInt(_kDesign) ?? 0).clamp(0, DesignLanguage.values.length - 1)];
    _glassRefraction = prefs.getBool(_kGlassRefraction) ?? false;
    _glassAllCards = prefs.getBool(_kGlassAllCards) ?? false;
    _wallpaper = prefs.getString(_kWallpaper);
    _wallpaperDim = prefs.getDouble(_kWallpaperDim) ?? 0.35;
    _terminalFontSize = (prefs.getDouble(_kTerminalFontSize) ?? 13)
        .clamp(minTerminalFontSize, maxTerminalFontSize);
    _terminalBgColor = prefs.getInt(_kTerminalBgColor);
    _terminalBgImage = prefs.getString(_kTerminalBgImage);
    _terminalFgColor = prefs.getInt(_kTerminalFgColor);
    notifyListeners();
  }

  Future<void> setTerminalFgColor(Color? value) async {
    _terminalFgColor = value?.toARGB32();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_terminalFgColor == null) {
      await prefs.remove(_kTerminalFgColor);
    } else {
      await prefs.setInt(_kTerminalFgColor, _terminalFgColor!);
    }
  }

  Future<void> setTerminalBgColor(Color? value) async {
    _terminalBgColor = value?.toARGB32();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_terminalBgColor == null) {
      await prefs.remove(_kTerminalBgColor);
    } else {
      await prefs.setInt(_kTerminalBgColor, _terminalBgColor!);
    }
  }

  Future<void> setTerminalBgImage(String? path) async {
    _terminalBgImage = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove(_kTerminalBgImage);
    } else {
      await prefs.setString(_kTerminalBgImage, path);
    }
  }

  Future<void> setTerminalFontSize(double value) async {
    final next = value.clamp(minTerminalFontSize, maxTerminalFontSize);
    if (_terminalFontSize == next) return;
    _terminalFontSize = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kTerminalFontSize, next);
  }




  /// 选了一张壁纸：复制到应用私有目录，避免外部路径失效
  /// 设置壁纸：直接写入字节，避免 FilePicker 返回的临时路径失效
  Future<void> setWallpaperBytes(List<int>? bytes) async {
    final prefs = await SharedPreferences.getInstance();
    if (bytes == null || bytes.isEmpty) {
      _wallpaper = null;
      notifyListeners();
      await prefs.remove(_kWallpaper);
      return;
    }
    var dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    // 文件名带时间戳：Image.file 按路径缓存，固定文件名换图不会刷新
    final file = File(
      '${dir.path}/wallpaper_${DateTime.now().millisecondsSinceEpoch}.img',
    );
    await file.writeAsBytes(bytes, flush: true);
    final old = _wallpaper;
    _wallpaper = file.path;
    notifyListeners();
    await prefs.setString(_kWallpaper, file.path);
    debugPrint(
      'setWallpaperBytes: wrote ${file.path} '
      '(exists=${await file.exists()}, bytes=${bytes.length})',
    );
    if (old != null && old != file.path) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
  }

  Future<void> clearWallpaper() async {
    await setWallpaperBytes(null);
  }


  Future<void> setWallpaperDim(double value) async {
    final next = value.clamp(0.0, 0.9);
    if ((_wallpaperDim - next).abs() < 0.001) return;
    _wallpaperDim = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kWallpaperDim, next);
  }

  Future<void> setGlassAllCards(bool value) async {
    if (_glassAllCards == value) return;
    _glassAllCards = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGlassAllCards, value);
  }

  Future<void> setGlassRefraction(bool value) async {
    if (_glassRefraction == value) return;
    _glassRefraction = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGlassRefraction, value);
  }

  Future<void> setDesignLanguage(DesignLanguage value) async {
    if (_designLanguage == value) return;
    _designLanguage = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDesign, value.index);
  }

  Future<void> setModeChoice(ThemeModeChoice value) async {
    if (_modeChoice == value) return;
    _modeChoice = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMode, value.index);
  }

  Future<void> setUseDynamicColor(bool value) async {
    if (_useDynamicColor == value) return;
    _useDynamicColor = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDynamic, value);
  }

  Future<void> setSeed(Color value) async {
    if (_seed == value) return;
    _seed = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSeed, value.toARGB32());
  }
}

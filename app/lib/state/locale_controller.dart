import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/app_strings.dart';

/// 语言设置（目前只有简体中文 / 繁体中文）。
class LocaleController extends ChangeNotifier {
  static const _kLanguage = 'app.language';

  AppLanguage _language = AppLanguage.zhHans;

  AppLanguage get language => _language;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _language = AppLanguage.fromCode(prefs.getString(_kLanguage));
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, language.code);
  }
}

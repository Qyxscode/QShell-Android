import 'dart:async';
import 'package:flutter/material.dart';

import 'pages/files/file_actions.dart';
import 'app.dart';
import 'services/system_service.dart';
import 'state/locale_controller.dart';
import 'state/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 上次进程被系统杀掉时「打开」用的临时文件会残留，启动时先清一次
  unawaited(clearOpenCache());
  final controller = ThemeController();
  await controller.load();
  final localeController = LocaleController();
  await localeController.load();
  final dynamicAccent = await SystemService.systemAccentColor();
  runApp(
    QShellApp(
      controller: controller,
      localeController: localeController,
      dynamicAccent: dynamicAccent,
    ),
  );
}

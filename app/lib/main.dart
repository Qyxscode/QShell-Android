import 'package:flutter/material.dart';

import 'app.dart';
import 'services/system_service.dart';
import 'state/locale_controller.dart';
import 'state/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

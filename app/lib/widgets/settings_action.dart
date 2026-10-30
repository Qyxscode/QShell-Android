import 'package:flutter/material.dart';

import '../pages/settings/settings_page.dart';
import '../state/theme_scope.dart';

/// 页面右上角的设置入口（悬浮底栏不再放设置项）。
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '设置',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SettingsPage(controller: ThemeScope.of(context)),
          ),
        );
      },
    );
  }
}

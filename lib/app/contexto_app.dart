import 'package:flutter/material.dart';

import '../core/media/screenshot_picker.dart';
import '../core/theme/app_theme.dart';
import '../features/home/presentation/home_page.dart';

class ContextoApp extends StatelessWidget {
  const ContextoApp({super.key, this.screenshotPicker});

  final ScreenshotPicker? screenshotPicker;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contexto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: HomePage(screenshotPicker: screenshotPicker),
    );
  }
}

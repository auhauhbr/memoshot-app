import 'package:flutter/material.dart';

import '../core/media/screenshot_picker.dart';
import '../core/theme/app_theme.dart';
import '../features/home/presentation/home_page.dart';
import '../features/library/data/media_item_repository.dart';

class ContextoApp extends StatelessWidget {
  const ContextoApp({super.key, this.screenshotPicker, this.mediaRepository});

  final ScreenshotPicker? screenshotPicker;
  final MediaItemRepository? mediaRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contexto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: HomePage(
        screenshotPicker: screenshotPicker,
        mediaRepository: mediaRepository,
      ),
    );
  }
}

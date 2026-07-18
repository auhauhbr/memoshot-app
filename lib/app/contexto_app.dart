import 'package:flutter/material.dart';

import '../core/media/screenshot_picker.dart';
import '../core/automatic_import/automatic_screenshot_source.dart';
import '../core/sharing/incoming_share_source.dart';
import '../core/theme/app_theme.dart';
import '../features/categories/data/category_repository.dart';
import '../features/automatic_import/data/automatic_import_settings_repository.dart';
import '../features/home/presentation/home_page.dart';
import '../features/library/data/media_item_repository.dart';
import '../features/ocr/data/ocr_repository.dart';
import '../features/processing/data/ocr_queue_processor.dart';
import '../features/tags/data/tag_repository.dart';

class ContextoApp extends StatelessWidget {
  const ContextoApp({
    super.key,
    this.screenshotPicker,
    this.mediaRepository,
    this.ocrRepository,
    this.ocrQueue,
    this.categoryRepository,
    this.tagRepository,
    this.incomingShareSource,
    this.automaticScreenshotSource,
    this.automaticImportSettingsRepository,
  });

  final ScreenshotPicker? screenshotPicker;
  final MediaItemRepository? mediaRepository;
  final OcrRepository? ocrRepository;
  final OcrQueue? ocrQueue;
  final CategoryRepository? categoryRepository;
  final TagRepository? tagRepository;
  final IncomingShareSource? incomingShareSource;
  final AutomaticScreenshotSource? automaticScreenshotSource;
  final AutomaticImportSettingsRepository? automaticImportSettingsRepository;

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
        ocrRepository: ocrRepository,
        ocrQueue: ocrQueue,
        categoryRepository: categoryRepository,
        tagRepository: tagRepository,
        incomingShareSource: incomingShareSource,
        automaticScreenshotSource: automaticScreenshotSource,
        automaticImportSettingsRepository: automaticImportSettingsRepository,
      ),
    );
  }
}

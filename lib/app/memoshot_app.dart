import 'package:flutter/material.dart';

import '../core/media/screenshot_picker.dart';
import '../core/automatic_import/automatic_screenshot_source.dart';
import '../core/automatic_import/method_channel_automatic_screenshot_source.dart';
import '../core/sharing/incoming_share_source.dart';
import '../core/theme/app_theme.dart';
import '../features/categories/data/category_repository.dart';
import '../features/classification/data/classification_suggestion_repository.dart';
import '../features/classification/application/review_decision.dart';
import '../features/automatic_import/data/automatic_import_settings_repository.dart';
import '../features/home/presentation/home_page.dart';
import '../features/library/data/media_item_repository.dart';
import '../features/ocr/data/ocr_repository.dart';
import '../features/onboarding/data/onboarding_repository.dart';
import '../features/onboarding/presentation/onboarding_gate.dart';
import '../features/processing/data/ocr_queue_processor.dart';
import '../features/tags/data/tag_repository.dart';

class MemoShotApp extends StatelessWidget {
  const MemoShotApp({
    super.key,
    this.screenshotPicker,
    this.mediaRepository,
    this.ocrRepository,
    this.ocrQueue,
    this.categoryRepository,
    this.classificationSuggestionRepository,
    this.reviewDecisionProcessor,
    this.tagRepository,
    this.incomingShareSource,
    this.automaticScreenshotSource,
    this.automaticImportSettingsRepository,
    this.onboardingRepository,
  });

  final ScreenshotPicker? screenshotPicker;
  final MediaItemRepository? mediaRepository;
  final OcrRepository? ocrRepository;
  final OcrQueue? ocrQueue;
  final CategoryRepository? categoryRepository;
  final ClassificationSuggestionRepository? classificationSuggestionRepository;
  final ReviewDecisionProcessor? reviewDecisionProcessor;
  final TagRepository? tagRepository;
  final IncomingShareSource? incomingShareSource;
  final AutomaticScreenshotSource? automaticScreenshotSource;
  final AutomaticImportSettingsRepository? automaticImportSettingsRepository;
  final OnboardingRepository? onboardingRepository;

  @override
  Widget build(BuildContext context) {
    final automaticSource =
        automaticScreenshotSource ??
        const MethodChannelAutomaticScreenshotSource();
    return MaterialApp(
      title: 'MemoShot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: OnboardingGate(
        repository:
            onboardingRepository ?? const MethodChannelOnboardingRepository(),
        automaticScreenshotSource: automaticSource,
        child: HomePage(
          screenshotPicker: screenshotPicker,
          mediaRepository: mediaRepository,
          ocrRepository: ocrRepository,
          ocrQueue: ocrQueue,
          categoryRepository: categoryRepository,
          classificationSuggestionRepository:
              classificationSuggestionRepository,
          reviewDecisionProcessor: reviewDecisionProcessor,
          tagRepository: tagRepository,
          incomingShareSource: incomingShareSource,
          automaticScreenshotSource: automaticSource,
          automaticImportSettingsRepository: automaticImportSettingsRepository,
        ),
      ),
    );
  }
}

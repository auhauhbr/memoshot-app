import 'package:flutter/material.dart';

import '../core/media/screenshot_picker.dart';
import '../core/media_store/media_store_content.dart';
import '../core/automatic_import/automatic_screenshot_source.dart';
import '../core/automatic_import/method_channel_automatic_screenshot_source.dart';
import '../core/sharing/incoming_share_source.dart';
import '../core/theme/app_theme.dart';
import '../features/categories/data/category_repository.dart';
import '../features/categories/data/recent_folder_repository.dart';
import '../features/classification/data/classification_suggestion_repository.dart';
import '../features/classification/application/classification_queue_processor.dart';
import '../features/automatic_import/data/automatic_import_settings_repository.dart';
import '../features/home/presentation/home_page.dart';
import '../features/library/data/media_item_repository.dart';
import '../features/ocr/data/ocr_repository.dart';
import '../features/onboarding/data/onboarding_repository.dart';
import '../features/onboarding/presentation/onboarding_gate.dart';
import '../features/processing/data/ocr_queue_processor.dart';
import '../features/tags/data/tag_repository.dart';
import '../features/existing_screenshots/application/existing_screenshot_inventory_coordinator.dart';
import '../features/existing_screenshots/application/historical_archive_preparation_coordinator.dart';

class MemoShotApp extends StatelessWidget {
  const MemoShotApp({
    super.key,
    this.screenshotPicker,
    this.mediaRepository,
    this.ocrRepository,
    this.ocrQueue,
    this.classificationQueue,
    this.categoryRepository,
    this.recentFolderRepository,
    this.classificationSuggestionRepository,
    this.tagRepository,
    this.incomingShareSource,
    this.automaticScreenshotSource,
    this.automaticImportSettingsRepository,
    this.onboardingRepository,
    this.existingScreenshotInventoryCoordinator,
    this.historicalArchivePreparationCoordinator,
    this.mediaStoreContentGateway,
  });

  final ScreenshotPicker? screenshotPicker;
  final MediaItemRepository? mediaRepository;
  final OcrRepository? ocrRepository;
  final OcrQueue? ocrQueue;
  final ClassificationQueue? classificationQueue;
  final CategoryRepository? categoryRepository;
  final RecentFolderRepository? recentFolderRepository;
  final ClassificationSuggestionRepository? classificationSuggestionRepository;
  final TagRepository? tagRepository;
  final IncomingShareSource? incomingShareSource;
  final AutomaticScreenshotSource? automaticScreenshotSource;
  final AutomaticImportSettingsRepository? automaticImportSettingsRepository;
  final OnboardingRepository? onboardingRepository;
  final ExistingScreenshotInventoryCoordinator?
  existingScreenshotInventoryCoordinator;
  final HistoricalArchivePreparationCoordinator?
  historicalArchivePreparationCoordinator;
  final MediaStoreContentGateway? mediaStoreContentGateway;

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
          classificationQueue: classificationQueue,
          categoryRepository: categoryRepository,
          recentFolderRepository: recentFolderRepository,
          classificationSuggestionRepository:
              classificationSuggestionRepository,
          tagRepository: tagRepository,
          incomingShareSource: incomingShareSource,
          automaticScreenshotSource: automaticSource,
          automaticImportSettingsRepository: automaticImportSettingsRepository,
          existingScreenshotInventoryCoordinator:
              existingScreenshotInventoryCoordinator,
          historicalArchivePreparationCoordinator:
              historicalArchivePreparationCoordinator,
          mediaStoreContentGateway: mediaStoreContentGateway,
        ),
      ),
    );
  }
}

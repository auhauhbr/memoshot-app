import '../../core/automatic_import/method_channel_automatic_screenshot_source.dart';
import '../../core/database/contexto_database.dart';
import '../../core/media/screenshot_storage.dart';
import '../../core/ocr/ml_kit_text_recognition_service.dart';
import '../../core/notifications/method_channel_review_notification_gateway.dart';
import '../automatic_import/data/automatic_import_settings_repository.dart';
import '../categories/data/category_repository.dart';
import '../categories/data/category_store.dart';
import '../classification/application/classification_composition.dart';
import '../classification/application/classification_queue_processor.dart';
import '../library/data/media_item_repository.dart';
import '../library/data/media_item_store.dart';
import '../ocr/data/ocr_repository.dart';
import '../ocr/data/ocr_result_store.dart';
import '../processing/data/ocr_job_scheduler.dart';
import '../processing/data/ocr_queue_processor.dart';
import '../processing/data/processing_job_store.dart';
import '../review_notifications/application/review_notification_coordinator.dart';
import 'background_processing_runner.dart';

class BackgroundProcessingComposition {
  BackgroundProcessingComposition._({
    required this.runner,
    required this._database,
    required this._ocrQueue,
    required this._classificationQueue,
    required this.notificationCoordinator,
  });

  final ContextoDatabase _database;
  final LocalOcrQueueProcessor _ocrQueue;
  final LocalClassificationQueueProcessor _classificationQueue;
  final BackgroundProcessingRunner runner;
  final ReviewNotificationCoordinator notificationCoordinator;

  static BackgroundProcessingComposition create() {
    final database = ContextoDatabase();
    final processingStore = DriftProcessingJobStore(database);
    final ocrResultStore = DriftOcrResultStore(database);
    final classificationRepository = createLocalClassificationRepository(
      database,
    );
    final categoryRepository = LocalCategoryRepository(
      store: DriftCategoryStore(database),
    );
    final mediaRepository = LocalMediaItemRepository(
      store: DriftMediaItemStore(database),
      storage: PrivateScreenshotStorage(),
      ocrJobScheduler: LocalOcrJobScheduler(processingStore),
    );
    final ocrRepository = LocalOcrRepository(
      store: ocrResultStore,
      recognitionService: const MlKitTextRecognitionService(),
    );
    final classificationQueue = createLocalClassificationQueue(
      database: database,
      suggestionRepository: classificationRepository,
      categoryRepository: categoryRepository,
      mediaRepository: mediaRepository,
      ocrRepository: ocrRepository,
      processingExpiration: Duration.zero,
    );
    final ocrQueue = LocalOcrQueueProcessor(
      jobStore: processingStore,
      resultStore: ocrResultStore,
      recognitionService: const MlKitTextRecognitionService(),
      classificationJobScheduler: createLocalClassificationJobScheduler(
        database,
      ),
      processingExpiration: Duration.zero,
    );
    final runner = BackgroundProcessingRunner(
      settingsRepository: DriftAutomaticImportSettingsRepository(database),
      inboxSource: const MethodChannelAutomaticScreenshotSource(),
      mediaRepository: mediaRepository,
      ocrQueue: ocrQueue,
      classificationQueue: classificationQueue,
    );
    final notificationCoordinator = ReviewNotificationCoordinator(
      snapshotRepository: classificationRepository,
      gateway: const MethodChannelReviewNotificationGateway(),
    );
    return BackgroundProcessingComposition._(
      database: database,
      ocrQueue: ocrQueue,
      classificationQueue: classificationQueue,
      runner: runner,
      notificationCoordinator: notificationCoordinator,
    );
  }

  Future<void> close() async {
    await _ocrQueue.close();
    await _classificationQueue.close();
    await _database.close();
  }
}

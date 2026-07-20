import '../../../core/database/contexto_database.dart';
import '../../../core/ocr/media_ocr_input.dart';
import '../../../core/visual/local_visual_analyzer.dart';
import '../../categories/data/category_repository.dart';
import '../../library/data/media_item_repository.dart';
import '../../library/data/capture_app_context_repository.dart';
import '../../ocr/data/ocr_repository.dart';
import '../data/classification_job_store.dart';
import '../data/classification_suggestion_repository.dart';
import '../data/classification_suggestion_store.dart';
import '../data/review_decision_store.dart';
import '../domain/local_classification_engine.dart';
import '../domain/contextual_classification.dart';
import '../domain/stored_classification_suggestion.dart';
import 'classification_processor.dart';
import 'classification_queue_processor.dart';
import 'automatic_classification.dart';
import 'review_decision.dart';

ClassificationSuggestionRepository createLocalClassificationRepository(
  ContextoDatabase database,
) {
  return LocalClassificationSuggestionRepository(
    DriftClassificationSuggestionStore(database),
  );
}

ReviewDecisionProcessor createLocalReviewDecisionProcessor(
  ContextoDatabase database,
) {
  return LocalReviewDecisionProcessor(DriftReviewDecisionStore(database));
}

AutomaticClassificationApplier createLocalAutomaticClassificationApplier(
  ContextoDatabase database,
  CategoryRepository categoryRepository,
) {
  return LocalAutomaticClassificationApplier(
    categoryRepository: categoryRepository,
    store: DriftReviewDecisionStore(database),
  );
}

AutomaticClassificationApplier createContextualAutomaticClassificationApplier(
  ContextoDatabase database,
) {
  return ContextualAutomaticClassificationApplier(
    store: DriftReviewDecisionStore(database),
  );
}

ClassificationProcessor createLocalClassificationProcessor(
  ClassificationSuggestionRepository repository, {
  AutomaticClassificationApplier? automaticApplier,
}) {
  return LocalClassificationProcessor(
    engine: const LocalClassificationEngine(),
    repository: repository,
    now: DateTime.now,
    engineVersion: currentClassificationEngineVersion,
    automaticApplier: automaticApplier,
  );
}

ClassificationJobScheduler createLocalClassificationJobScheduler(
  ContextoDatabase database,
) {
  return LocalClassificationJobScheduler(
    store: DriftClassificationJobStore(database),
    engineVersion: currentClassificationEngineVersion,
    now: DateTime.now,
  );
}

LocalClassificationQueueProcessor createLocalClassificationQueue({
  required ContextoDatabase database,
  required ClassificationSuggestionRepository suggestionRepository,
  required CategoryRepository categoryRepository,
  required MediaItemRepository mediaRepository,
  required OcrRepository ocrRepository,
  Duration processingExpiration = classificationProcessingExpiration,
}) {
  final processor = ContextualClassificationProcessor(
    engine: const ContextualClassificationEngine(),
    visualAnalyzer: createLocalVisualAnalyzer(),
    inputResolver: createMediaOcrInputResolver(),
    repository: suggestionRepository,
    categoryRepository: categoryRepository,
    ocrRepository: ocrRepository,
    now: DateTime.now,
    engineVersion: currentClassificationEngineVersion,
    automaticApplier: createContextualAutomaticClassificationApplier(database),
    captureAppContextRepository: DriftCaptureAppContextRepository(database),
  );
  return LocalClassificationQueueProcessor(
    jobStore: DriftClassificationJobStore(database),
    classificationProcessor: processor,
    suggestionRepository: suggestionRepository,
    mediaRepository: mediaRepository,
    ocrRepository: ocrRepository,
    now: DateTime.now,
    processingExpiration: processingExpiration,
  );
}

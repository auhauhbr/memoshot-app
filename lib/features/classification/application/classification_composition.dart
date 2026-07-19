import '../../../core/database/contexto_database.dart';
import '../../categories/data/category_repository.dart';
import '../data/classification_suggestion_repository.dart';
import '../data/classification_suggestion_store.dart';
import '../data/review_decision_store.dart';
import '../domain/local_classification_engine.dart';
import '../domain/stored_classification_suggestion.dart';
import 'classification_processor.dart';
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

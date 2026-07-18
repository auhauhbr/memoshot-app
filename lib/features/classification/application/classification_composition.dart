import '../../../core/database/contexto_database.dart';
import '../data/classification_suggestion_repository.dart';
import '../data/classification_suggestion_store.dart';
import '../domain/local_classification_engine.dart';
import '../domain/stored_classification_suggestion.dart';
import 'classification_processor.dart';

ClassificationProcessor createLocalClassificationProcessor(
  ContextoDatabase database,
) {
  return LocalClassificationProcessor(
    engine: const LocalClassificationEngine(),
    repository: LocalClassificationSuggestionRepository(
      DriftClassificationSuggestionStore(database),
    ),
    now: DateTime.now,
    engineVersion: currentClassificationEngineVersion,
  );
}

import '../../library/domain/media_item.dart';
import '../../ocr/domain/ocr_result.dart';
import '../data/classification_suggestion_repository.dart';
import '../domain/classification_models.dart';
import '../domain/local_classification_engine.dart';
import '../domain/stored_classification_suggestion.dart';

const strongClassificationConfidenceThreshold = 0.72;

abstract interface class ClassificationProcessor {
  Future<StoredClassificationSuggestion> process({
    required MediaItem mediaItem,
    required OcrResult ocrResult,
  });
}

class LocalClassificationProcessor implements ClassificationProcessor {
  LocalClassificationProcessor({
    required LocalClassificationEngine engine,
    required ClassificationSuggestionRepository repository,
    required DateTime Function() now,
    required int engineVersion,
  }) : this._(engine, repository, now, engineVersion);

  LocalClassificationProcessor._(
    this._engine,
    this._repository,
    this._now,
    this._engineVersion,
  );

  final LocalClassificationEngine _engine;
  final ClassificationSuggestionRepository _repository;
  final DateTime Function() _now;
  final int _engineVersion;
  final Map<int, Future<StoredClassificationSuggestion>> _inFlight = {};

  @override
  Future<StoredClassificationSuggestion> process({
    required MediaItem mediaItem,
    required OcrResult ocrResult,
  }) {
    final running = _inFlight[mediaItem.id];
    if (running != null) return running;

    final operation = _process(mediaItem: mediaItem, ocrResult: ocrResult);
    _inFlight[mediaItem.id] = operation;
    return operation.whenComplete(() {
      if (identical(_inFlight[mediaItem.id], operation)) {
        _inFlight.remove(mediaItem.id);
      }
    });
  }

  Future<StoredClassificationSuggestion> _process({
    required MediaItem mediaItem,
    required OcrResult ocrResult,
  }) async {
    final existing = await _repository.loadByMediaItemId(mediaItem.id);
    if (existing != null &&
        (!_isPending(existing) ||
            _isCurrentForOcr(existing, ocrResult.processedAt))) {
      return existing;
    }

    final suggestion = _engine.classify(
      ClassificationInput(
        ocrText: ocrResult.fullText,
        sourceMimeType: mediaItem.mimeType,
        capturedAt: mediaItem.capturedAt,
      ),
    );
    final now = _now();
    final stored = StoredClassificationSuggestion.fromEngine(
      mediaItemId: mediaItem.id,
      suggestion: suggestion,
      reviewReason: classificationReviewReasonFor(suggestion),
      createdAt: now,
      engineVersion: _engineVersion,
    );
    return _repository.saveAutomaticSuggestion(
      stored,
      ocrProcessedAt: ocrResult.processedAt,
    );
  }

  bool _isPending(StoredClassificationSuggestion suggestion) {
    return suggestion.status == ClassificationSuggestionStatus.pendingReview;
  }

  bool _isCurrentForOcr(
    StoredClassificationSuggestion suggestion,
    DateTime ocrProcessedAt,
  ) {
    return suggestion.engineVersion == _engineVersion &&
        !ocrProcessedAt.isAfter(suggestion.updatedAt);
  }
}

ClassificationReviewReason classificationReviewReasonFor(
  ClassificationSuggestion suggestion, {
  double strongConfidenceThreshold = strongClassificationConfidenceThreshold,
}) {
  if (!suggestion.hasSuggestion) {
    return ClassificationReviewReason.noSuggestion;
  }
  if (suggestion.suggestedCategoryName == null &&
      suggestion.suggestedTags.isNotEmpty) {
    return ClassificationReviewReason.noCategory;
  }
  if (suggestion.confidence < strongConfidenceThreshold) {
    return ClassificationReviewReason.lowConfidence;
  }
  return ClassificationReviewReason.manualReview;
}

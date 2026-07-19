import '../../../core/ocr/media_ocr_input.dart';
import '../../../core/visual/local_visual_analyzer.dart';
import '../../categories/data/category_repository.dart';
import '../../library/domain/media_item.dart';
import '../../ocr/data/ocr_repository.dart';
import '../../ocr/domain/ocr_result.dart';
import '../data/classification_suggestion_repository.dart';
import '../domain/classification_models.dart';
import '../domain/contextual_classification.dart';
import '../domain/local_classification_engine.dart';
import '../domain/stored_classification_suggestion.dart';
import 'automatic_classification.dart';

const strongClassificationConfidenceThreshold = 0.72;

abstract interface class ClassificationProcessor {
  Future<StoredClassificationSuggestion> process({
    required MediaItem mediaItem,
    required OcrResult ocrResult,
  });
}

abstract interface class ClosableClassificationProcessor {
  Future<void> close();
}

enum IndividualReprocessStatus { applied, uncertain, preservedManual }

final class IndividualReprocessResult {
  const IndividualReprocessResult(this.status);

  final IndividualReprocessStatus status;
}

abstract interface class IndividualClassificationReprocessor {
  Future<IndividualReprocessResult> reprocess(MediaItem mediaItem);
}

class LocalClassificationProcessor implements ClassificationProcessor {
  LocalClassificationProcessor({
    required LocalClassificationEngine engine,
    required ClassificationSuggestionRepository repository,
    required DateTime Function() now,
    required int engineVersion,
    AutomaticClassificationApplier? automaticApplier,
  }) : this._(engine, repository, now, engineVersion, automaticApplier);

  LocalClassificationProcessor._(
    this._engine,
    this._repository,
    this._now,
    this._engineVersion,
    this._automaticApplier,
  );

  final LocalClassificationEngine _engine;
  final ClassificationSuggestionRepository _repository;
  final DateTime Function() _now;
  final int _engineVersion;
  final AutomaticClassificationApplier? _automaticApplier;
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
    if (existing != null) {
      if (!_isPending(existing)) return existing;
      if (_isCurrentForOcr(existing, ocrResult.processedAt)) {
        return _autoApplySafely(existing);
      }
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
    final saved = await _repository.saveAutomaticSuggestion(
      stored,
      ocrProcessedAt: ocrResult.processedAt,
    );
    return _autoApplySafely(saved);
  }

  Future<StoredClassificationSuggestion> _autoApplySafely(
    StoredClassificationSuggestion suggestion,
  ) async {
    try {
      return await _automaticApplier?.apply(suggestion) ?? suggestion;
    } catch (_) {
      return suggestion;
    }
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

class ContextualClassificationProcessor
    implements
        ClassificationProcessor,
        ClosableClassificationProcessor,
        IndividualClassificationReprocessor {
  ContextualClassificationProcessor({
    required ContextualClassificationEngine engine,
    required LocalVisualAnalyzer visualAnalyzer,
    required MediaOcrInputResolver inputResolver,
    required ClassificationSuggestionRepository repository,
    required CategoryRepository categoryRepository,
    required OcrRepository ocrRepository,
    required DateTime Function() now,
    required int engineVersion,
    AutomaticClassificationApplier? automaticApplier,
  }) : this._(
         engine,
         visualAnalyzer,
         inputResolver,
         repository,
         categoryRepository,
         ocrRepository,
         now,
         engineVersion,
         automaticApplier,
       );

  ContextualClassificationProcessor._(
    this._engine,
    this._visualAnalyzer,
    this._inputResolver,
    this._repository,
    this._categoryRepository,
    this._ocrRepository,
    this._now,
    this._engineVersion,
    this._automaticApplier,
  );

  final ContextualClassificationEngine _engine;
  final LocalVisualAnalyzer _visualAnalyzer;
  final MediaOcrInputResolver _inputResolver;
  final ClassificationSuggestionRepository _repository;
  final CategoryRepository _categoryRepository;
  final OcrRepository _ocrRepository;
  final DateTime Function() _now;
  final int _engineVersion;
  final AutomaticClassificationApplier? _automaticApplier;
  final Map<int, Future<StoredClassificationSuggestion>> _inFlight = {};
  bool _closed = false;

  @override
  Future<StoredClassificationSuggestion> process({
    required MediaItem mediaItem,
    required OcrResult ocrResult,
  }) => _singleFlight(
    mediaItem.id,
    () => _process(mediaItem: mediaItem, ocrResult: ocrResult, force: false),
  );

  @override
  Future<IndividualReprocessResult> reprocess(MediaItem mediaItem) async {
    if (_closed) throw StateError('Classificador contextual encerrado.');
    final manualCategories = await _categoryRepository.loadForMedia(
      mediaItem.id,
    );
    if (manualCategories.isNotEmpty) {
      return const IndividualReprocessResult(
        IndividualReprocessStatus.preservedManual,
      );
    }
    final ocrResult = await _ocrRepository.loadFor(mediaItem.id);
    if (ocrResult == null) throw StateError('OCR ainda não disponível.');
    final stored = await _singleFlight(
      mediaItem.id,
      () => _process(mediaItem: mediaItem, ocrResult: ocrResult, force: true),
    );
    return IndividualReprocessResult(
      stored.status == ClassificationSuggestionStatus.autoApplied
          ? IndividualReprocessStatus.applied
          : IndividualReprocessStatus.uncertain,
    );
  }

  Future<StoredClassificationSuggestion> _singleFlight(
    int mediaItemId,
    Future<StoredClassificationSuggestion> Function() operation,
  ) {
    if (_closed) throw StateError('Classificador contextual encerrado.');
    final running = _inFlight[mediaItemId];
    if (running != null) return running;
    final future = operation();
    _inFlight[mediaItemId] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[mediaItemId], future)) {
        _inFlight.remove(mediaItemId);
      }
    });
  }

  Future<StoredClassificationSuggestion> _process({
    required MediaItem mediaItem,
    required OcrResult ocrResult,
    required bool force,
  }) async {
    final existing = await _repository.loadByMediaItemId(mediaItem.id);
    if (!force && existing != null) {
      if (existing.status != ClassificationSuggestionStatus.pendingReview) {
        return existing;
      }
      if (existing.engineVersion == _engineVersion &&
          !ocrResult.processedAt.isAfter(existing.updatedAt)) {
        return _autoApplySafely(existing);
      }
    }

    final visual = await _analyzeSafely(mediaItem);
    final result = _engine.classify(
      ocrText: ocrResult.fullText,
      visualAnalysis: visual,
    );
    final suggestion = result.toSuggestion();
    final now = _now();
    final stored = StoredClassificationSuggestion.fromEngine(
      mediaItemId: mediaItem.id,
      suggestion: suggestion,
      reviewReason: classificationReviewReasonFor(suggestion),
      createdAt: now,
      engineVersion: _engineVersion,
    );
    final saved = force
        ? await _repository.replaceSuggestion(stored)
        : await _repository.saveAutomaticSuggestion(
            stored,
            ocrProcessedAt: ocrResult.processedAt,
          );
    return _autoApplySafely(saved);
  }

  Future<VisualAnalysisResult?> _analyzeSafely(MediaItem mediaItem) async {
    OcrInputLease? lease;
    try {
      lease = await _inputResolver.resolve(mediaItem);
      return await _visualAnalyzer.analyze(lease.localPath);
    } catch (_) {
      // OCR e regras contextuais continuam disponíveis sem o sinal visual.
      return null;
    } finally {
      try {
        await lease?.release();
      } catch (_) {
        // A falha de limpeza não substitui o resultado da classificação.
      }
    }
  }

  Future<StoredClassificationSuggestion> _autoApplySafely(
    StoredClassificationSuggestion suggestion,
  ) async {
    try {
      return await _automaticApplier?.apply(suggestion) ?? suggestion;
    } catch (_) {
      return suggestion;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait(
      _inFlight.values.map(
        (future) => future.then<void>((_) {}, onError: (_) {}),
      ),
    );
    await _inputResolver.close();
    await _visualAnalyzer.close();
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

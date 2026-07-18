import '../domain/stored_classification_suggestion.dart';
import 'classification_suggestion_store.dart';

abstract interface class ClassificationSuggestionRepository {
  Future<StoredClassificationSuggestion> saveSuggestion(
    StoredClassificationSuggestion suggestion,
  );

  Future<StoredClassificationSuggestion> replaceSuggestion(
    StoredClassificationSuggestion suggestion,
  );

  Future<StoredClassificationSuggestion> saveAutomaticSuggestion(
    StoredClassificationSuggestion suggestion, {
    required DateTime ocrProcessedAt,
  });

  Future<StoredClassificationSuggestion?> loadByMediaItemId(int mediaItemId);

  Future<void> deleteForMediaItem(int mediaItemId);

  Future<List<StoredClassificationSuggestion>> loadPendingReview();

  Future<int> countPendingReview();

  Future<StoredClassificationSuggestion> updateStatus(
    int mediaItemId,
    ClassificationSuggestionStatus status,
  );

  Future<StoredClassificationSuggestion> markAccepted(int mediaItemId);

  Future<StoredClassificationSuggestion> markRejected(int mediaItemId);

  Future<StoredClassificationSuggestion> markAutoApplied(int mediaItemId);
}

class LocalClassificationSuggestionRepository
    implements ClassificationSuggestionRepository {
  LocalClassificationSuggestionRepository(
    this._store, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ClassificationSuggestionStore _store;
  final DateTime Function() _now;

  @override
  Future<StoredClassificationSuggestion> saveSuggestion(
    StoredClassificationSuggestion suggestion,
  ) {
    return _store.saveSuggestion(suggestion);
  }

  @override
  Future<StoredClassificationSuggestion> replaceSuggestion(
    StoredClassificationSuggestion suggestion,
  ) {
    return _store.saveSuggestion(suggestion);
  }

  @override
  Future<StoredClassificationSuggestion> saveAutomaticSuggestion(
    StoredClassificationSuggestion suggestion, {
    required DateTime ocrProcessedAt,
  }) {
    return _store.saveAutomaticSuggestion(
      suggestion,
      ocrProcessedAt: ocrProcessedAt,
    );
  }

  @override
  Future<StoredClassificationSuggestion?> loadByMediaItemId(int mediaItemId) {
    return _store.loadByMediaItemId(mediaItemId);
  }

  @override
  Future<void> deleteForMediaItem(int mediaItemId) {
    return _store.deleteForMediaItem(mediaItemId);
  }

  @override
  Future<List<StoredClassificationSuggestion>> loadPendingReview() {
    return _store.loadPendingReview();
  }

  @override
  Future<int> countPendingReview() => _store.countPendingReview();

  @override
  Future<StoredClassificationSuggestion> updateStatus(
    int mediaItemId,
    ClassificationSuggestionStatus status,
  ) {
    return _store.updateStatus(
      mediaItemId: mediaItemId,
      status: status,
      updatedAt: _now(),
    );
  }

  @override
  Future<StoredClassificationSuggestion> markAccepted(int mediaItemId) {
    return updateStatus(mediaItemId, ClassificationSuggestionStatus.accepted);
  }

  @override
  Future<StoredClassificationSuggestion> markRejected(int mediaItemId) {
    return updateStatus(mediaItemId, ClassificationSuggestionStatus.rejected);
  }

  @override
  Future<StoredClassificationSuggestion> markAutoApplied(int mediaItemId) {
    return updateStatus(
      mediaItemId,
      ClassificationSuggestionStatus.autoApplied,
    );
  }
}

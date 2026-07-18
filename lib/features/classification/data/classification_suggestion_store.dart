import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart' as database;
import '../domain/stored_classification_suggestion.dart';
import 'classification_suggestion_codec.dart';

abstract interface class ClassificationSuggestionStore {
  Future<StoredClassificationSuggestion> saveSuggestion(
    StoredClassificationSuggestion suggestion,
  );

  Future<StoredClassificationSuggestion?> loadByMediaItemId(int mediaItemId);

  Future<StoredClassificationSuggestion> saveAutomaticSuggestion(
    StoredClassificationSuggestion suggestion, {
    required DateTime ocrProcessedAt,
  });

  Future<void> deleteForMediaItem(int mediaItemId);

  Future<List<StoredClassificationSuggestion>> loadPendingReview();

  Future<int> countPendingReview();

  Future<StoredClassificationSuggestion> updateStatus({
    required int mediaItemId,
    required ClassificationSuggestionStatus status,
    required DateTime updatedAt,
  });
}

class ClassificationSuggestionNotFoundException implements Exception {
  const ClassificationSuggestionNotFoundException(this.mediaItemId);

  final int mediaItemId;
}

class DriftClassificationSuggestionStore
    implements ClassificationSuggestionStore {
  DriftClassificationSuggestionStore(
    this._database, [
    this._codec = const ClassificationSuggestionPayloadCodec(),
  ]);

  final database.ContextoDatabase _database;
  final ClassificationSuggestionPayloadCodec _codec;

  @override
  Future<StoredClassificationSuggestion> saveSuggestion(
    StoredClassificationSuggestion suggestion,
  ) {
    return _database.transaction(() async {
      final existing = await loadByMediaItemId(suggestion.mediaItemId);
      final value = existing == null
          ? suggestion
          : StoredClassificationSuggestion(
              mediaItemId: suggestion.mediaItemId,
              suggestedCategoryName: suggestion.suggestedCategoryName,
              confidence: suggestion.confidence,
              hasSuggestion: suggestion.hasSuggestion,
              suggestedTags: suggestion.suggestedTags,
              evidence: suggestion.evidence,
              status: ClassificationSuggestionStatus.pendingReview,
              reviewReason: suggestion.reviewReason,
              engineVersion: suggestion.engineVersion,
              createdAt: existing.createdAt,
              updatedAt: suggestion.updatedAt,
            );
      await _database
          .into(_database.classificationSuggestions)
          .insert(_toCompanion(value), mode: InsertMode.insertOrReplace);
      return value;
    });
  }

  @override
  Future<StoredClassificationSuggestion> saveAutomaticSuggestion(
    StoredClassificationSuggestion suggestion, {
    required DateTime ocrProcessedAt,
  }) {
    return _database.transaction(() async {
      final existing = await loadByMediaItemId(suggestion.mediaItemId);
      if (existing != null) {
        final isResolved =
            existing.status != ClassificationSuggestionStatus.pendingReview;
        final isCurrent =
            existing.engineVersion == suggestion.engineVersion &&
            !ocrProcessedAt.isAfter(existing.updatedAt);
        if (isResolved || isCurrent) return existing;
      }

      final value = StoredClassificationSuggestion(
        mediaItemId: suggestion.mediaItemId,
        suggestedCategoryName: suggestion.suggestedCategoryName,
        confidence: suggestion.confidence,
        hasSuggestion: suggestion.hasSuggestion,
        suggestedTags: suggestion.suggestedTags,
        evidence: suggestion.evidence,
        status: ClassificationSuggestionStatus.pendingReview,
        reviewReason: suggestion.reviewReason,
        engineVersion: suggestion.engineVersion,
        createdAt: existing?.createdAt ?? suggestion.createdAt,
        updatedAt: suggestion.updatedAt,
      );
      await _database
          .into(_database.classificationSuggestions)
          .insert(_toCompanion(value), mode: InsertMode.insertOrReplace);
      return value;
    });
  }

  @override
  Future<StoredClassificationSuggestion?> loadByMediaItemId(
    int mediaItemId,
  ) async {
    final row = await (_database.select(
      _database.classificationSuggestions,
    )..where((item) => item.mediaItemId.equals(mediaItemId))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> deleteForMediaItem(int mediaItemId) async {
    await (_database.delete(
      _database.classificationSuggestions,
    )..where((item) => item.mediaItemId.equals(mediaItemId))).go();
  }

  @override
  Future<List<StoredClassificationSuggestion>> loadPendingReview() async {
    final reasonPriority = const CustomExpression<int>(
      "CASE review_reason "
      "WHEN 'lowConfidence' THEN 0 "
      "WHEN 'ambiguous' THEN 1 "
      "WHEN 'noCategory' THEN 2 "
      "WHEN 'noSuggestion' THEN 3 "
      "WHEN 'manualReview' THEN 4 ELSE 5 END",
    );
    final rows =
        await (_database.select(_database.classificationSuggestions)
              ..where(
                (item) => item.status.equals(
                  ClassificationSuggestionStatus.pendingReview.name,
                ),
              )
              ..orderBy([
                (_) => OrderingTerm.asc(reasonPriority),
                (item) => OrderingTerm.asc(item.confidence),
                (item) => OrderingTerm.asc(item.createdAt),
                (item) => OrderingTerm.asc(item.mediaItemId),
              ]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<int> countPendingReview() async {
    final count = _database.classificationSuggestions.mediaItemId.count();
    final query = _database.selectOnly(_database.classificationSuggestions)
      ..addColumns([count])
      ..where(
        _database.classificationSuggestions.status.equals(
          ClassificationSuggestionStatus.pendingReview.name,
        ),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }

  @override
  Future<StoredClassificationSuggestion> updateStatus({
    required int mediaItemId,
    required ClassificationSuggestionStatus status,
    required DateTime updatedAt,
  }) {
    return _database.transaction(() async {
      final current = await loadByMediaItemId(mediaItemId);
      if (current == null) {
        throw ClassificationSuggestionNotFoundException(mediaItemId);
      }
      final resolvedAt = status == ClassificationSuggestionStatus.pendingReview
          ? null
          : updatedAt;
      await (_database.update(
        _database.classificationSuggestions,
      )..where((item) => item.mediaItemId.equals(mediaItemId))).write(
        database.ClassificationSuggestionsCompanion(
          status: Value(status.name),
          updatedAt: Value(updatedAt),
          resolvedAt: Value(resolvedAt),
        ),
      );
      return current.copyWith(
        status: status,
        updatedAt: updatedAt,
        resolvedAt: resolvedAt,
        clearResolvedAt: resolvedAt == null,
      );
    });
  }

  database.ClassificationSuggestionsCompanion _toCompanion(
    StoredClassificationSuggestion suggestion,
  ) {
    return database.ClassificationSuggestionsCompanion.insert(
      mediaItemId: Value(suggestion.mediaItemId),
      suggestedCategoryName: Value(suggestion.suggestedCategoryName),
      confidence: suggestion.confidence,
      hasSuggestion: suggestion.hasSuggestion,
      suggestedTagsJson: _codec.encodeTags(suggestion.suggestedTags),
      evidenceJson: _codec.encodeEvidence(suggestion.evidence),
      status: suggestion.status.name,
      reviewReason: Value(suggestion.reviewReason?.name),
      engineVersion: suggestion.engineVersion,
      createdAt: suggestion.createdAt,
      updatedAt: suggestion.updatedAt,
      resolvedAt: Value(suggestion.resolvedAt),
    );
  }

  StoredClassificationSuggestion _toDomain(
    database.ClassificationSuggestion row,
  ) {
    return StoredClassificationSuggestion(
      mediaItemId: row.mediaItemId,
      suggestedCategoryName: row.suggestedCategoryName,
      confidence: row.confidence,
      hasSuggestion: row.hasSuggestion,
      suggestedTags: _codec.decodeTags(row.suggestedTagsJson),
      evidence: _codec.decodeEvidence(row.evidenceJson),
      status: _parseStatus(row.status),
      reviewReason: _parseReviewReason(row.reviewReason),
      engineVersion: row.engineVersion,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      resolvedAt: row.resolvedAt,
    );
  }

  ClassificationSuggestionStatus _parseStatus(String value) {
    final matches = ClassificationSuggestionStatus.values.where(
      (item) => item.name == value,
    );
    if (matches.length != 1) {
      throw FormatException('Status de sugestão inválido: $value');
    }
    return matches.single;
  }

  ClassificationReviewReason? _parseReviewReason(String? value) {
    if (value == null) return null;
    final matches = ClassificationReviewReason.values.where(
      (item) => item.name == value,
    );
    if (matches.length != 1) {
      throw FormatException('Motivo de revisão inválido: $value');
    }
    return matches.single;
  }
}

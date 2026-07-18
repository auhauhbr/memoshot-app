import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../../../core/text/text_normalizer.dart';
import '../application/review_decision.dart';
import '../data/classification_suggestion_codec.dart';
import '../domain/stored_classification_suggestion.dart';

class DriftReviewDecisionStore implements ReviewDecisionStore {
  DriftReviewDecisionStore(
    ContextoDatabase database, {
    TextNormalizer normalizer = const TextNormalizer(),
    ClassificationSuggestionPayloadCodec codec =
        const ClassificationSuggestionPayloadCodec(),
  }) : this._(database, normalizer, codec);

  DriftReviewDecisionStore._(this._database, this._normalizer, this._codec);

  final ContextoDatabase _database;
  final TextNormalizer _normalizer;
  final ClassificationSuggestionPayloadCodec _codec;

  @override
  Future<StoredClassificationSuggestion> resolve(
    ReviewDecision decision, {
    required DateTime resolvedAt,
  }) {
    return _database.transaction(() async {
      final suggestion =
          await (_database.select(_database.classificationSuggestions)
                ..where((row) => row.mediaItemId.equals(decision.mediaItemId)))
              .getSingleOrNull();
      if (suggestion == null) {
        throw const ReviewDecisionException(
          ReviewDecisionFailure.suggestionNotFound,
        );
      }
      if (suggestion.status !=
          ClassificationSuggestionStatus.pendingReview.name) {
        throw const ReviewDecisionException(
          ReviewDecisionFailure.alreadyResolved,
        );
      }
      final mediaExists =
          await (_database.selectOnly(_database.mediaItems)
                ..addColumns([_database.mediaItems.id])
                ..where(_database.mediaItems.id.equals(decision.mediaItemId)))
              .getSingleOrNull() !=
          null;
      if (!mediaExists) {
        throw const ReviewDecisionException(
          ReviewDecisionFailure.mediaNotFound,
        );
      }

      if (decision.type == ReviewDecisionType.confirm) {
        await _applyAssociations(decision, resolvedAt);
      }
      final status = decision.type == ReviewDecisionType.confirm
          ? ClassificationSuggestionStatus.accepted
          : ClassificationSuggestionStatus.rejected;
      final updated =
          await (_database.update(_database.classificationSuggestions)..where(
                (row) =>
                    row.mediaItemId.equals(decision.mediaItemId) &
                    row.status.equals(
                      ClassificationSuggestionStatus.pendingReview.name,
                    ),
              ))
              .write(
                ClassificationSuggestionsCompanion(
                  status: Value(status.name),
                  updatedAt: Value(resolvedAt),
                  resolvedAt: Value(resolvedAt),
                ),
              );
      if (updated != 1) {
        throw const ReviewDecisionException(
          ReviewDecisionFailure.alreadyResolved,
        );
      }
      return StoredClassificationSuggestion(
        mediaItemId: suggestion.mediaItemId,
        suggestedCategoryName: suggestion.suggestedCategoryName,
        confidence: suggestion.confidence,
        hasSuggestion: suggestion.hasSuggestion,
        suggestedTags: _codec.decodeTags(suggestion.suggestedTagsJson),
        evidence: _codec.decodeEvidence(suggestion.evidenceJson),
        status: status,
        reviewReason: _parseReason(suggestion.reviewReason),
        engineVersion: suggestion.engineVersion,
        createdAt: suggestion.createdAt,
        updatedAt: resolvedAt,
        resolvedAt: resolvedAt,
      );
    });
  }

  Future<void> _applyAssociations(
    ReviewDecision decision,
    DateTime resolvedAt,
  ) async {
    final categoryId = decision.selectedCategoryId;
    if (categoryId != null) {
      final category = await (_database.select(
        _database.categories,
      )..where((row) => row.id.equals(categoryId))).getSingleOrNull();
      if (category == null) {
        throw const ReviewDecisionException(
          ReviewDecisionFailure.categoryNotFound,
        );
      }
    }

    final tagIds = <int>{};
    for (final tagId in decision.selectedTagIds) {
      final tag = await (_database.select(
        _database.tags,
      )..where((row) => row.id.equals(tagId))).getSingleOrNull();
      if (tag == null) {
        throw const ReviewDecisionException(ReviewDecisionFailure.tagNotFound);
      }
      tagIds.add(tag.id);
    }
    for (final rawName in decision.newTagNames) {
      final visibleName = rawName.trim();
      final normalizedName = _normalizer.normalize(visibleName);
      if (normalizedName.isEmpty || visibleName.length > 40) {
        throw const ReviewDecisionException(ReviewDecisionFailure.invalidTag);
      }
      var tag =
          await (_database.select(_database.tags)
                ..where((row) => row.normalizedName.equals(normalizedName)))
              .getSingleOrNull();
      if (tag == null) {
        final id = await _database
            .into(_database.tags)
            .insert(
              TagsCompanion.insert(
                name: visibleName,
                normalizedName: normalizedName,
                createdAt: resolvedAt,
                updatedAt: resolvedAt,
              ),
            );
        tag = await (_database.select(
          _database.tags,
        )..where((row) => row.id.equals(id))).getSingle();
      }
      tagIds.add(tag.id);
    }

    if (categoryId != null) {
      await _database
          .into(_database.mediaCategories)
          .insert(
            MediaCategoriesCompanion.insert(
              mediaItemId: decision.mediaItemId,
              categoryId: categoryId,
              createdAt: resolvedAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    for (final tagId in tagIds) {
      await _database
          .into(_database.mediaTags)
          .insert(
            MediaTagsCompanion.insert(
              mediaItemId: decision.mediaItemId,
              tagId: tagId,
              createdAt: resolvedAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  ClassificationReviewReason? _parseReason(String? value) {
    if (value == null) return null;
    return ClassificationReviewReason.values
        .where((reason) => reason.name == value)
        .firstOrNull;
  }
}

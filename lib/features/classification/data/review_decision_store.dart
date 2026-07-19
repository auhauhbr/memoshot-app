import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../../../core/text/text_normalizer.dart';
import '../../categories/domain/category.dart' as category_domain;
import '../application/automatic_classification.dart';
import '../application/review_decision.dart';
import '../data/classification_suggestion_codec.dart';
import '../domain/local_classification_engine.dart';
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
  Future<StoredClassificationSuggestion> autoApply({
    required int mediaItemId,
    required int expectedCategoryId,
    required Set<String> safeTagNames,
    required DateTime resolvedAt,
  }) {
    return _database.transaction(() async {
      final row =
          await (_database.select(_database.classificationSuggestions)
                ..where((item) => item.mediaItemId.equals(mediaItemId)))
              .getSingleOrNull();
      if (row == null) {
        throw const ReviewDecisionException(
          ReviewDecisionFailure.suggestionNotFound,
        );
      }
      final suggestion = _toDomain(row);
      if (suggestion.status != ClassificationSuggestionStatus.pendingReview) {
        return suggestion;
      }
      final mediaExists =
          await (_database.selectOnly(_database.mediaItems)
                ..addColumns([_database.mediaItems.id])
                ..where(_database.mediaItems.id.equals(mediaItemId)))
              .getSingleOrNull() !=
          null;
      if (!mediaExists) {
        throw const ReviewDecisionException(
          ReviewDecisionFailure.mediaNotFound,
        );
      }
      final rootRows = await (_database.select(
        _database.categories,
      )..where((category) => category.parentId.isNull())).get();
      final roots = rootRows
          .map(
            (category) => category_domain.Category(
              id: category.id,
              name: category.name,
              normalizedName: category.normalizedName,
              createdAt: category.createdAt,
            ),
          )
          .toList(growable: false);
      final category = const AutoClassificationPolicy().eligibleRoot(
        suggestion: suggestion,
        rootCategories: roots,
      );
      if (category == null || category.id != expectedCategoryId) {
        return suggestion;
      }

      final allowedNames = {
        for (final name in safeTagNames)
          if (LocalClassificationTagCatalog.contains(name))
            _normalizer.normalize(name),
      };
      final namesToApply = <String>[];
      final seenNames = <String>{};
      for (final tag in suggestion.suggestedTags) {
        final normalized = _normalizer.normalize(tag.name);
        if (allowedNames.contains(normalized) &&
            LocalClassificationTagCatalog.contains(tag.name) &&
            seenNames.add(normalized)) {
          namesToApply.add(tag.name.trim());
        }
      }

      final tagIds = <int>{};
      for (final visibleName in namesToApply) {
        final normalizedName = _normalizer.normalize(visibleName);
        var tag =
            await (_database.select(_database.tags)
                  ..where((item) => item.normalizedName.equals(normalizedName)))
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
          )..where((item) => item.id.equals(id))).getSingle();
        }
        tagIds.add(tag.id);
      }

      await _database
          .into(_database.mediaCategories)
          .insert(
            MediaCategoriesCompanion.insert(
              mediaItemId: mediaItemId,
              categoryId: category.id,
              createdAt: resolvedAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      for (final tagId in tagIds) {
        await _database
            .into(_database.mediaTags)
            .insert(
              MediaTagsCompanion.insert(
                mediaItemId: mediaItemId,
                tagId: tagId,
                createdAt: resolvedAt,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
      final updated =
          await (_database.update(_database.classificationSuggestions)..where(
                (item) =>
                    item.mediaItemId.equals(mediaItemId) &
                    item.status.equals(
                      ClassificationSuggestionStatus.pendingReview.name,
                    ),
              ))
              .write(
                ClassificationSuggestionsCompanion(
                  status: Value(
                    ClassificationSuggestionStatus.autoApplied.name,
                  ),
                  updatedAt: Value(resolvedAt),
                  resolvedAt: Value(resolvedAt),
                ),
              );
      if (updated != 1) {
        throw const ReviewDecisionException(
          ReviewDecisionFailure.alreadyResolved,
        );
      }
      return suggestion.copyWith(
        status: ClassificationSuggestionStatus.autoApplied,
        updatedAt: resolvedAt,
        resolvedAt: resolvedAt,
      );
    });
  }

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

  StoredClassificationSuggestion _toDomain(ClassificationSuggestion row) {
    return StoredClassificationSuggestion(
      mediaItemId: row.mediaItemId,
      suggestedCategoryName: row.suggestedCategoryName,
      confidence: row.confidence,
      hasSuggestion: row.hasSuggestion,
      suggestedTags: _codec.decodeTags(row.suggestedTagsJson),
      evidence: _codec.decodeEvidence(row.evidenceJson),
      status: ClassificationSuggestionStatus.values.firstWhere(
        (status) => status.name == row.status,
      ),
      reviewReason: _parseReason(row.reviewReason),
      engineVersion: row.engineVersion,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      resolvedAt: row.resolvedAt,
    );
  }
}

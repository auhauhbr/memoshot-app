import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../../../core/text/text_normalizer.dart';
import '../../categories/domain/category.dart' as category_domain;
import '../../library/domain/media_item.dart';
import '../application/automatic_classification.dart';
import '../application/review_decision.dart';
import '../data/classification_suggestion_codec.dart';
import '../domain/local_classification_engine.dart';
import '../domain/contextual_classification.dart';
import '../domain/stored_classification_suggestion.dart';

class DriftReviewDecisionStore
    implements ReviewDecisionStore, ContextualAutomaticClassificationStore {
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
  Future<StoredClassificationSuggestion> autoApplyContextual({
    required StoredClassificationSuggestion suggestion,
    required DateTime resolvedAt,
  }) {
    return _database.transaction(() async {
      final row =
          await (_database.select(_database.classificationSuggestions)..where(
                (item) => item.mediaItemId.equals(suggestion.mediaItemId),
              ))
              .getSingleOrNull();
      if (row == null) return suggestion;
      final current = _toDomain(row);
      final destination = ContextualFolderCatalog.parse(
        current.suggestedCategoryName,
      );
      final margin = current.evidence
          .where((item) => item.ruleId == 'context.destination.margin')
          .map((item) => item.weight)
          .firstOrNull;
      if (current.status != ClassificationSuggestionStatus.pendingReview ||
          destination == null ||
          current.confidence < contextualExistingDestinationThreshold ||
          (margin ?? 0) < contextualDestinationMargin) {
        return current;
      }
      final mediaItem =
          await (_database.select(_database.mediaItems)
                ..where((item) => item.id.equals(suggestion.mediaItemId)))
              .getSingleOrNull();
      if (mediaItem == null ||
          mediaItem.importOrigin != ImportOrigin.automatic.databaseValue) {
        return current;
      }

      final priorAssociation =
          await (_database.selectOnly(_database.mediaCategories)
                ..addColumns([_database.mediaCategories.categoryId])
                ..where(
                  _database.mediaCategories.mediaItemId.equals(
                    suggestion.mediaItemId,
                  ),
                )
                ..limit(1))
              .getSingleOrNull();
      if (priorAssociation != null) return current;

      final (catalogRoot, childName) = destination;
      final rootName = catalogRoot == 'Produtos'
          ? await _compatibleProductsRootName()
          : catalogRoot;
      var root = await _findCategory(rootName, null);
      var child = root == null || childName == null
          ? null
          : await _findCategory(childName, root.id);
      final needsCreation =
          root == null || (childName != null && child == null);
      if (needsCreation &&
          current.confidence < contextualNewDestinationThreshold) {
        return current;
      }
      await _ensureControlledRoots(resolvedAt);
      root ??= await _findCategory(rootName, null);
      root ??= await _createCategory(rootName, null, resolvedAt);
      if (childName != null) {
        child ??= await _createCategory(childName, root.id, resolvedAt);
      }
      final categoryId = child?.id ?? root.id;

      await _database
          .into(_database.mediaCategories)
          .insert(
            MediaCategoriesCompanion.insert(
              mediaItemId: suggestion.mediaItemId,
              categoryId: categoryId,
              createdAt: resolvedAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      final tags = current.suggestedTags
          .where(
            (tag) =>
                tag.confidence >= contextualTagThreshold &&
                ContextualTagCatalog.contains(tag.name),
          )
          .take(maximumContextualTags);
      final appliedNames = <String>{};
      for (final suggestedTag in tags) {
        final visibleName = suggestedTag.name.trim();
        final normalizedName = _normalizer.normalize(visibleName);
        if (!appliedNames.add(normalizedName)) continue;
        var tag =
            await (_database.select(_database.tags)
                  ..where((item) => item.normalizedName.equals(normalizedName)))
                .getSingleOrNull();
        if (tag == null) {
          await _database
              .into(_database.tags)
              .insert(
                TagsCompanion.insert(
                  name: visibleName,
                  normalizedName: normalizedName,
                  createdAt: resolvedAt,
                  updatedAt: resolvedAt,
                ),
                mode: InsertMode.insertOrIgnore,
              );
          tag =
              await (_database.select(_database.tags)..where(
                    (item) => item.normalizedName.equals(normalizedName),
                  ))
                  .getSingleOrNull();
        }
        if (tag != null) {
          await _database
              .into(_database.mediaTags)
              .insert(
                MediaTagsCompanion.insert(
                  mediaItemId: suggestion.mediaItemId,
                  tagId: tag.id,
                  createdAt: resolvedAt,
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      }
      final updated =
          await (_database.update(_database.classificationSuggestions)..where(
                (item) =>
                    item.mediaItemId.equals(suggestion.mediaItemId) &
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
      if (updated != 1) return current;
      return current.copyWith(
        status: ClassificationSuggestionStatus.autoApplied,
        updatedAt: resolvedAt,
        resolvedAt: resolvedAt,
      );
    });
  }

  Future<String> _compatibleProductsRootName() async {
    if (await _findCategory('Produtos', null) != null) return 'Produtos';
    if (await _findCategory('Compras', null) != null) return 'Compras';
    return 'Produtos';
  }

  Future<void> _ensureControlledRoots(DateTime createdAt) async {
    for (final name in const [
      'Conversas',
      'Carreira',
      'Estudos',
      'Livros',
      'Documentos',
      'Desenvolvimento',
      'Produtos',
      'Esportes',
      'Outros',
    ]) {
      if (name == 'Produtos' && await _findCategory('Compras', null) != null) {
        continue;
      }
      if (await _findCategory(name, null) == null) {
        await _createCategory(name, null, createdAt);
      }
    }
  }

  Future<Category?> _findCategory(String name, int? parentId) {
    final normalized = _normalizer.normalize(name);
    return (_database.select(_database.categories)..where(
          (item) =>
              item.normalizedName.equals(normalized) &
              (parentId == null
                  ? item.parentId.isNull()
                  : item.parentId.equals(parentId)),
        ))
        .getSingleOrNull();
  }

  Future<Category> _createCategory(
    String name,
    int? parentId,
    DateTime createdAt,
  ) async {
    final normalized = _normalizer.normalize(name);
    await _database
        .into(_database.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            normalizedName: normalized,
            parentId: Value(parentId),
            createdAt: createdAt,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return (await _findCategory(name, parentId))!;
  }

  @override
  Future<StoredClassificationSuggestion> autoApply({
    required int mediaItemId,
    required int? expectedCategoryId,
    required String officialCategoryName,
    required bool allowSafeRootCreation,
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
      final plan = const AutoClassificationPolicy().plan(
        suggestion: suggestion,
        rootCategories: roots,
      );
      if (plan == null || plan.officialCategoryName != officialCategoryName) {
        return suggestion;
      }
      int categoryId;
      if (plan.type == AutoClassificationPlanType.useExistingRoot) {
        final root = plan.existingRoot!;
        if ((expectedCategoryId != null && root.id != expectedCategoryId) ||
            (expectedCategoryId == null && !allowSafeRootCreation)) {
          return suggestion;
        }
        categoryId = root.id;
      } else {
        if (!allowSafeRootCreation || expectedCategoryId != null) {
          return suggestion;
        }
        final normalizedName = _normalizer.normalize(plan.officialCategoryName);
        await _database
            .into(_database.categories)
            .insert(
              CategoriesCompanion.insert(
                name: plan.officialCategoryName,
                normalizedName: normalizedName,
                parentId: const Value(null),
                createdAt: resolvedAt,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        final createdOrConcurrent =
            await (_database.select(_database.categories)..where(
                  (category) =>
                      category.parentId.isNull() &
                      category.normalizedName.equals(normalizedName),
                ))
                .getSingleOrNull();
        if (createdOrConcurrent == null) return suggestion;
        categoryId = createdOrConcurrent.id;
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
              categoryId: categoryId,
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

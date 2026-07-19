import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/database/contexto_database.dart';
import 'package:memoshot/features/categories/data/category_repository.dart';
import 'package:memoshot/features/categories/data/category_store.dart';
import 'package:memoshot/features/categories/domain/category.dart' as domain;
import 'package:memoshot/features/classification/application/automatic_classification.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_repository.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_store.dart';
import 'package:memoshot/features/classification/data/review_decision_store.dart';
import 'package:memoshot/features/classification/domain/classification_models.dart';
import 'package:memoshot/features/classification/domain/stored_classification_suggestion.dart';
import 'package:memoshot/features/tags/data/tag_repository.dart';
import 'package:memoshot/features/tags/data/tag_store.dart';

void main() {
  const policy = AutoClassificationPolicy();
  final root = domain.Category(
    id: 1,
    name: 'Carrêira',
    normalizedName: 'carreira',
    createdAt: DateTime.utc(2026),
  );
  final child = domain.Category(
    id: 2,
    name: 'Carreira',
    normalizedName: 'carreira',
    parentId: 9,
    createdAt: DateTime.utc(2026),
  );

  group('política conservadora', () {
    test('confiança 0.85 e raiz equivalente são elegíveis', () {
      expect(
        policy
            .eligibleRoot(
              suggestion: _suggestion(confidence: 0.85),
              rootCategories: [root],
            )
            ?.id,
        root.id,
      );
    });

    test('normaliza correspondência exata sem aceitar parcial', () {
      expect(
        policy.eligibleRoot(
          suggestion: _suggestion(category: ' CARREIRA '),
          rootCategories: [root],
        ),
        root,
      );
      expect(
        policy.eligibleRoot(
          suggestion: _suggestion(category: 'Carre'),
          rootCategories: [root],
        ),
        isNull,
      );
    });

    test('abaixo de 0.85 não é elegível', () {
      expect(
        policy.eligibleRoot(
          suggestion: _suggestion(confidence: 0.849),
          rootCategories: [root],
        ),
        isNull,
      );
    });

    test('categoria nula e hasSuggestion false não são elegíveis', () {
      expect(
        policy.eligibleRoot(
          suggestion: _suggestion(category: null),
          rootCategories: [root],
        ),
        isNull,
      );
      expect(
        policy.eligibleRoot(
          suggestion: _suggestion(hasSuggestion: false),
          rootCategories: [root],
        ),
        isNull,
      );
    });

    for (final reason in [
      ClassificationReviewReason.lowConfidence,
      ClassificationReviewReason.ambiguous,
      ClassificationReviewReason.noCategory,
      ClassificationReviewReason.noSuggestion,
    ]) {
      test('$reason não é elegível', () {
        expect(
          policy.eligibleRoot(
            suggestion: _suggestion(reason: reason),
            rootCategories: [root],
          ),
          isNull,
        );
      });
    }

    test('somente subpasta, pasta inexistente e mídia ausente não elegem', () {
      final suggestion = _suggestion();
      expect(
        policy.eligibleRoot(suggestion: suggestion, rootCategories: [child]),
        isNull,
      );
      expect(
        policy.eligibleRoot(suggestion: suggestion, rootCategories: const []),
        isNull,
      );
      expect(
        policy.eligibleRoot(
          suggestion: suggestion,
          rootCategories: [root],
          mediaItemExists: false,
        ),
        isNull,
      );
    });

    test('mais de uma raiz equivalente não permite escolha silenciosa', () {
      final duplicate = domain.Category(
        id: 3,
        name: 'Carreira',
        normalizedName: 'carreira',
        createdAt: DateTime.utc(2026),
      );
      expect(
        policy.eligibleRoot(
          suggestion: _suggestion(),
          rootCategories: [root, duplicate],
        ),
        isNull,
      );
    });

    for (final status in [
      ClassificationSuggestionStatus.accepted,
      ClassificationSuggestionStatus.rejected,
      ClassificationSuggestionStatus.autoApplied,
    ]) {
      test('$status não é elegível', () {
        expect(
          policy.eligibleRoot(
            suggestion: _suggestion(status: status),
            rootCategories: [root],
          ),
          isNull,
        );
      });
    }
  });

  group('aplicação transacional', () {
    late ContextoDatabase database;
    late LocalCategoryRepository categories;
    late LocalTagRepository tags;
    late LocalClassificationSuggestionRepository suggestions;
    late DriftReviewDecisionStore store;
    late LocalAutomaticClassificationApplier applier;
    late int mediaItemId;
    final createdAt = DateTime.utc(2026, 7, 18, 10);
    final resolvedAt = DateTime.utc(2026, 7, 18, 11);

    setUp(() async {
      database = ContextoDatabase.forTesting(NativeDatabase.memory());
      categories = LocalCategoryRepository(store: DriftCategoryStore(database));
      tags = LocalTagRepository(store: DriftTagStore(database));
      suggestions = LocalClassificationSuggestionRepository(
        DriftClassificationSuggestionStore(database),
      );
      store = DriftReviewDecisionStore(database);
      applier = LocalAutomaticClassificationApplier(
        categoryRepository: categories,
        store: store,
        now: () => resolvedAt,
      );
      mediaItemId = await database
          .into(database.mediaItems)
          .insert(
            MediaItemsCompanion.insert(
              privatePath: '/tmp/automatic.png',
              internalName: 'automatic.png',
              importedAt: createdAt,
              sourceMode: 'photoPicker',
              status: 'ready',
            ),
          );
    });

    tearDown(() => database.close());

    Future<StoredClassificationSuggestion> save({
      List<String> tagNames = const ['Urgente', 'Entrevista', 'Arbitrária'],
      ClassificationSuggestionStatus status =
          ClassificationSuggestionStatus.pendingReview,
    }) async {
      final value = _suggestion(
        mediaItemId: mediaItemId,
        tagNames: tagNames,
        status: status,
      );
      return suggestions.saveSuggestion(value);
    }

    test(
      'associa raiz, cria/reutiliza tags seguras e preserva relações',
      () async {
        final previousCategory = await categories.createRootCategory(
          'Anterior',
        );
        final career = await categories.createRootCategory('Carreira');
        await categories.replaceForMedia(mediaItemId, {previousCategory.id});
        final previousTag = await tags.createTag('Anterior');
        final urgent = await tags.createTag(' urgente ');
        await tags.addToMedia(tagId: previousTag.id, mediaItemId: mediaItemId);
        final suggestion = await save();

        final result = await applier.apply(suggestion);

        expect(result.status, ClassificationSuggestionStatus.autoApplied);
        expect(result.resolvedAt, resolvedAt);
        expect(result.confidence, 0.9);
        expect(result.evidence.single.description, 'Evidência sanitizada.');
        expect(
          (await categories.loadForMedia(mediaItemId)).map((item) => item.id),
          containsAll([previousCategory.id, career.id]),
        );
        expect(
          (await tags.loadForMedia(mediaItemId)).map((item) => item.name),
          containsAll(['Anterior', urgent.name, 'Entrevista']),
        );
        expect(await tags.findByNormalizedName('Arbitrária'), isNull);
      },
    );

    test('associações existentes e retry não duplicam', () async {
      final career = await categories.createRootCategory('Carreira');
      final urgent = await tags.createTag('Urgente');
      await categories.replaceForMedia(mediaItemId, {career.id});
      await tags.addToMedia(tagId: urgent.id, mediaItemId: mediaItemId);
      final suggestion = await save(tagNames: ['Urgente']);

      final first = await applier.apply(suggestion);
      final second = await applier.apply(first);

      expect(second.status, ClassificationSuggestionStatus.autoApplied);
      expect(
        await database.select(database.mediaCategories).get(),
        hasLength(1),
      );
      expect(await database.select(database.mediaTags).get(), hasLength(1));
    });

    test('sem raiz equivalente permanece pending e não cria pasta', () async {
      final suggestion = await save();

      final result = await applier.apply(suggestion);

      expect(result.status, ClassificationSuggestionStatus.pendingReview);
      expect(await categories.loadCategories(), isEmpty);
      expect(await tags.loadTags(), isEmpty);
    });

    test('somente subpasta equivalente permanece pending', () async {
      final parent = await categories.createRootCategory('Trabalho');
      await categories.createSubcategory(parentId: parent.id, name: 'Carreira');
      final suggestion = await save();

      expect(
        (await applier.apply(suggestion)).status,
        ClassificationSuggestionStatus.pendingReview,
      );
      expect(await database.select(database.mediaCategories).get(), isEmpty);
    });

    test('pasta removida antes da transação mantém pending', () async {
      final career = await categories.createRootCategory('Carreira');
      await save();
      await categories.deleteCategory(career.id);

      final result = await store.autoApply(
        mediaItemId: mediaItemId,
        expectedCategoryId: career.id,
        safeTagNames: {'Urgente'},
        resolvedAt: resolvedAt,
      );

      expect(result.status, ClassificationSuggestionStatus.pendingReview);
      expect(await database.select(database.mediaCategories).get(), isEmpty);
      expect(await tags.loadTags(), isEmpty);
    });

    test('chamadas concorrentes aplicam uma única vez', () async {
      await categories.createRootCategory('Carreira');
      final suggestion = await save(tagNames: ['Urgente']);

      final results = await Future.wait([
        applier.apply(suggestion),
        applier.apply(suggestion),
      ]);

      expect(
        results.map((item) => item.status),
        everyElement(ClassificationSuggestionStatus.autoApplied),
      );
      expect(
        await database.select(database.mediaCategories).get(),
        hasLength(1),
      );
      expect(await database.select(database.mediaTags).get(), hasLength(1));
    });

    for (final status in [
      ClassificationSuggestionStatus.accepted,
      ClassificationSuggestionStatus.rejected,
      ClassificationSuggestionStatus.autoApplied,
    ]) {
      test('$status é preservado pelo store', () async {
        await categories.createRootCategory('Carreira');
        await save();
        await suggestions.updateStatus(mediaItemId, status);
        final current = (await suggestions.loadByMediaItemId(mediaItemId))!;

        final result = await applier.apply(current);

        expect(result.status, status);
        expect(await database.select(database.mediaCategories).get(), isEmpty);
      });
    }

    test('screenshot removido não deixa organização parcial', () async {
      await categories.createRootCategory('Carreira');
      await save();
      await database.delete(database.mediaItems).go();

      await expectLater(
        applier.apply(_suggestion(mediaItemId: mediaItemId)),
        throwsA(anything),
      );
      expect(await database.select(database.mediaCategories).get(), isEmpty);
      expect(await database.select(database.mediaTags).get(), isEmpty);
    });
  });
}

StoredClassificationSuggestion _suggestion({
  int mediaItemId = 1,
  String? category = 'Carreira',
  double confidence = 0.9,
  bool hasSuggestion = true,
  ClassificationReviewReason reason = ClassificationReviewReason.manualReview,
  ClassificationSuggestionStatus status =
      ClassificationSuggestionStatus.pendingReview,
  List<String> tagNames = const [],
}) {
  final evidence = ClassificationEvidence(
    ruleId: 'safe.rule',
    type: ClassificationEvidenceType.keyword,
    description: 'Evidência sanitizada.',
    weight: confidence,
    safeMatch: 'carreira',
  );
  return StoredClassificationSuggestion(
    mediaItemId: mediaItemId,
    suggestedCategoryName: category,
    confidence: confidence,
    hasSuggestion: hasSuggestion,
    suggestedTags: [
      for (final name in tagNames)
        SuggestedTag(name: name, confidence: confidence, evidence: [evidence]),
    ],
    evidence: [evidence],
    status: status,
    reviewReason: reason,
    engineVersion: 1,
    createdAt: DateTime.utc(2026, 7, 18, 10),
    updatedAt: DateTime.utc(2026, 7, 18, 10),
  );
}

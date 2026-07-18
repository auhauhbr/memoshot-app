import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/database/contexto_database.dart';
import 'package:memoshot/features/categories/data/category_repository.dart';
import 'package:memoshot/features/categories/data/category_store.dart';
import 'package:memoshot/features/classification/application/review_decision.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_repository.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_store.dart';
import 'package:memoshot/features/classification/data/review_decision_store.dart';
import 'package:memoshot/features/classification/domain/classification_models.dart';
import 'package:memoshot/features/classification/domain/stored_classification_suggestion.dart';
import 'package:memoshot/features/tags/data/tag_repository.dart';
import 'package:memoshot/features/tags/data/tag_store.dart';

void main() {
  late ContextoDatabase database;
  late LocalClassificationSuggestionRepository suggestions;
  late LocalCategoryRepository categories;
  late LocalTagRepository tags;
  late LocalReviewDecisionProcessor processor;
  late int mediaItemId;
  final createdAt = DateTime.utc(2026, 7, 18, 10);
  final resolvedAt = DateTime.utc(2026, 7, 18, 11);

  setUp(() async {
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    suggestions = LocalClassificationSuggestionRepository(
      DriftClassificationSuggestionStore(database),
    );
    categories = LocalCategoryRepository(store: DriftCategoryStore(database));
    tags = LocalTagRepository(store: DriftTagStore(database));
    processor = LocalReviewDecisionProcessor(
      DriftReviewDecisionStore(database),
      now: () => resolvedAt,
    );
    mediaItemId = await database
        .into(database.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            privatePath: '/tmp/review.png',
            internalName: 'review.png',
            importedAt: createdAt,
            sourceMode: 'photoPicker',
            status: 'ready',
          ),
        );
    await database
        .into(database.ocrResults)
        .insert(
          OcrResultsCompanion.insert(
            mediaItemId: Value(mediaItemId),
            fullText: 'OCR privado que deve ser preservado',
            normalizedText: const Value('ocr privado que deve ser preservado'),
            engine: 'teste',
            engineVersion: '1',
            processedAt: createdAt,
          ),
        );
  });

  tearDown(() => database.close());

  Future<void> saveSuggestion({
    String? category = 'Carreira',
    List<String> tagNames = const [],
  }) {
    return suggestions
        .saveSuggestion(
          StoredClassificationSuggestion(
            mediaItemId: mediaItemId,
            suggestedCategoryName: category,
            confidence: 0.68,
            hasSuggestion: category != null || tagNames.isNotEmpty,
            suggestedTags: [
              for (final name in tagNames)
                SuggestedTag(name: name, confidence: 0.68, evidence: const []),
            ],
            evidence: [
              ClassificationEvidence(
                ruleId: 'safe.rule',
                type: ClassificationEvidenceType.keyword,
                description: 'Evidência sanitizada.',
                weight: 0.68,
                safeMatch: 'termo seguro',
              ),
            ],
            status: ClassificationSuggestionStatus.pendingReview,
            reviewReason: ClassificationReviewReason.manualReview,
            engineVersion: 1,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        )
        .then<void>((_) {});
  }

  Future<ReviewSelection> loadSelection() async {
    final suggestion = await suggestions.loadByMediaItemId(mediaItemId);
    if (suggestion == null) throw StateError('Sugestão ausente no teste.');
    return ReviewSelectionLoader(
      categoryRepository: categories,
      tagRepository: tags,
    ).load(suggestion);
  }

  group('pré-seleção', () {
    test('seleciona exatamente uma pasta raiz equivalente', () async {
      final root = await categories.createRootCategory('Carrêira');
      await categories.createSubcategory(parentId: root.id, name: 'Vagas');
      await saveSuggestion(category: ' carreira ');

      final selection = await loadSelection();

      expect(selection.selectedCategory?.id, root.id);
    });

    test('não seleciona nome encontrado somente em subpasta', () async {
      final root = await categories.createRootCategory('Trabalho');
      await categories.createSubcategory(parentId: root.id, name: 'Carreira');
      await saveSuggestion(category: 'Carreira');

      expect((await loadSelection()).selectedCategory, isNull);
    });

    test('categoria nula não seleciona pasta', () async {
      await categories.createRootCategory('Carreira');
      await saveSuggestion(category: null);

      expect((await loadSelection()).selectedCategory, isNull);
    });

    test('etiquetas sugeridas começam selecionadas e mantêm ordem', () async {
      final urgent = await tags.createTag('Urgente');
      final date = await tags.createTag('Data');
      await saveSuggestion(tagNames: ['Data', 'Nova', 'Urgente', 'Nóva']);

      final selection = await loadSelection();

      expect(selection.selectedTags.map((tag) => tag.id), [date.id, urgent.id]);
      expect(selection.newTagNames, ['Nova']);
    });
  });

  group('confirmação transacional', () {
    test(
      'associa pasta e etiquetas, preserva relações, OCR e evidências',
      () async {
        final previousCategory = await categories.createRootCategory('Antiga');
        final selectedCategory = await categories.createRootCategory(
          'Carreira',
        );
        await categories.replaceForMedia(mediaItemId, {previousCategory.id});
        final previousTag = await tags.createTag('Anterior');
        final existingTag = await tags.createTag('Urgente');
        await tags.addToMedia(tagId: previousTag.id, mediaItemId: mediaItemId);
        await saveSuggestion(tagNames: ['Urgente', 'Entrevista']);

        final result = await processor.resolve(
          ReviewDecision.confirm(
            mediaItemId: mediaItemId,
            selectedCategoryId: selectedCategory.id,
            selectedTagIds: [existingTag.id],
            newTagNames: ['Entrevista', ' urgente '],
          ),
        );

        expect(result.status, ClassificationSuggestionStatus.accepted);
        expect(result.resolvedAt, resolvedAt);
        expect(result.evidence.single.description, 'Evidência sanitizada.');
        expect(
          (await categories.loadForMedia(mediaItemId)).map((item) => item.id),
          containsAll([previousCategory.id, selectedCategory.id]),
        );
        expect(
          (await tags.loadForMedia(mediaItemId)).map((item) => item.name),
          containsAll(['Anterior', 'Urgente', 'Entrevista']),
        );
        expect(
          await database.select(database.mediaCategories).get(),
          hasLength(2),
        );
        expect(await database.select(database.mediaTags).get(), hasLength(3));
        expect(await database.select(database.mediaItems).get(), hasLength(1));
        expect(
          (await database.select(database.ocrResults).getSingle()).fullText,
          'OCR privado que deve ser preservado',
        );
      },
    );

    test('permite confirmar sem pasta e sem etiquetas', () async {
      await saveSuggestion(category: null);

      await processor.resolve(ReviewDecision.confirm(mediaItemId: mediaItemId));

      expect(await database.select(database.mediaCategories).get(), isEmpty);
      expect(await database.select(database.mediaTags).get(), isEmpty);
      expect(
        (await suggestions.loadByMediaItemId(mediaItemId))?.status,
        ClassificationSuggestionStatus.accepted,
      );
    });

    test('retry não duplica e decisão resolvida é previsível', () async {
      final category = await categories.createRootCategory('Carreira');
      final tag = await tags.createTag('Urgente');
      await saveSuggestion();
      final decision = ReviewDecision.confirm(
        mediaItemId: mediaItemId,
        selectedCategoryId: category.id,
        selectedTagIds: [tag.id],
      );

      await processor.resolve(decision);
      await expectLater(
        processor.resolve(decision),
        throwsA(_failure(ReviewDecisionFailure.alreadyResolved)),
      );

      expect(
        await database.select(database.mediaCategories).get(),
        hasLength(1),
      );
      expect(await database.select(database.mediaTags).get(), hasLength(1));
    });

    test('duas confirmações concorrentes têm somente um sucesso', () async {
      await saveSuggestion();
      final decision = ReviewDecision.confirm(mediaItemId: mediaItemId);

      final outcomes = await Future.wait([
        processor
            .resolve(decision)
            .then<Object>((value) => value)
            .catchError((Object error) => error),
        processor
            .resolve(decision)
            .then<Object>((value) => value)
            .catchError((Object error) => error),
      ]);

      expect(
        outcomes.whereType<StoredClassificationSuggestion>(),
        hasLength(1),
      );
      expect(
        outcomes.whereType<ReviewDecisionException>().single.failure,
        ReviewDecisionFailure.alreadyResolved,
      );
    });

    test('pasta removida reverte toda a operação e mantém pending', () async {
      final removed = await categories.createRootCategory('Removida');
      await saveSuggestion();
      await categories.deleteCategory(removed.id);

      await expectLater(
        processor.resolve(
          ReviewDecision.confirm(
            mediaItemId: mediaItemId,
            selectedCategoryId: removed.id,
            newTagNames: ['Não deve existir'],
          ),
        ),
        throwsA(_failure(ReviewDecisionFailure.categoryNotFound)),
      );

      expect(await tags.loadTags(), isEmpty);
      expect(
        (await suggestions.loadByMediaItemId(mediaItemId))?.status,
        ClassificationSuggestionStatus.pendingReview,
      );
    });

    test('etiqueta removida não aceita nem deixa associação parcial', () async {
      final selectedCategory = await categories.createRootCategory('Carreira');
      final removedTag = await tags.createTag('Removida');
      await saveSuggestion();
      await tags.deleteTag(removedTag.id);

      await expectLater(
        processor.resolve(
          ReviewDecision.confirm(
            mediaItemId: mediaItemId,
            selectedCategoryId: selectedCategory.id,
            selectedTagIds: [removedTag.id],
          ),
        ),
        throwsA(_failure(ReviewDecisionFailure.tagNotFound)),
      );

      expect(await database.select(database.mediaCategories).get(), isEmpty);
      expect(
        (await suggestions.loadByMediaItemId(mediaItemId))?.status,
        ClassificationSuggestionStatus.pendingReview,
      );
    });
  });

  group('rejeição', () {
    test('rejeita sem alterar organização, screenshot ou OCR', () async {
      final category = await categories.createRootCategory('Existente');
      final tag = await tags.createTag('Existente');
      await categories.replaceForMedia(mediaItemId, {category.id});
      await tags.addToMedia(tagId: tag.id, mediaItemId: mediaItemId);
      await saveSuggestion();

      final result = await processor.resolve(
        ReviewDecision.reject(mediaItemId: mediaItemId),
      );

      expect(result.status, ClassificationSuggestionStatus.rejected);
      expect(result.resolvedAt, resolvedAt);
      expect(await categories.loadForMedia(mediaItemId), hasLength(1));
      expect(await tags.loadForMedia(mediaItemId), hasLength(1));
      expect(await database.select(database.mediaItems).get(), hasLength(1));
      expect(await database.select(database.ocrResults).get(), hasLength(1));
    });

    test(
      'screenshot removido elimina sugestão e falha com segurança',
      () async {
        await saveSuggestion();
        await (database.delete(
          database.mediaItems,
        )..where((row) => row.id.equals(mediaItemId))).go();

        await expectLater(
          processor.resolve(ReviewDecision.reject(mediaItemId: mediaItemId)),
          throwsA(_failure(ReviewDecisionFailure.suggestionNotFound)),
        );
      },
    );
  });
}

Matcher _failure(ReviewDecisionFailure failure) {
  return isA<ReviewDecisionException>().having(
    (error) => error.failure,
    'failure',
    failure,
  );
}

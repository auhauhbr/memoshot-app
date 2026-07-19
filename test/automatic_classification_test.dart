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
import 'package:memoshot/features/classification/domain/local_classification_engine.dart';
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

  group('catálogo seguro de pastas', () {
    test('expõe exatamente as oito categorias oficiais', () {
      expect(LocalClassificationCategoryCatalog.names, {
        'Carreira',
        'Estudos',
        'Compras',
        'Finanças',
        'Conversas',
        'Desenvolvimento',
        'Documentos',
        'Viagens',
      });
      expect(LocalClassificationCategoryCatalog.definitions, hasLength(8));
    });

    test('normaliza a consulta e preserva a capitalização oficial', () {
      expect(
        LocalClassificationCategoryCatalog.officialNameFor('  carreira  '),
        'Carreira',
      );
      expect(
        LocalClassificationCategoryCatalog.officialNameFor('FINANCAS'),
        'Finanças',
      );
    });

    test('rejeita nome arbitrário e nome de etiqueta', () {
      expect(LocalClassificationCategoryCatalog.contains('Pessoal'), isFalse);
      expect(LocalClassificationCategoryCatalog.contains('Urgente'), isFalse);
    });

    test('catálogo é imutável', () {
      expect(
        () => LocalClassificationCategoryCatalog.names.add('Outra'),
        throwsUnsupportedError,
      );
      expect(
        () => LocalClassificationCategoryCatalog.definitions.add(
          const LocalClassificationCategoryDefinition(
            ruleId: 'other',
            name: 'Outra',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

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

    test('raiz ausente exige confiança 0.90', () {
      expect(
        policy.plan(
          suggestion: _suggestion(confidence: 0.899),
          rootCategories: const [],
        ),
        isNull,
      );
      expect(
        policy
            .plan(
              suggestion: _suggestion(confidence: 0.90),
              rootCategories: const [],
            )
            ?.type,
        AutoClassificationPlanType.createSafeRoot,
      );
    });

    test('raiz nova exige duas evidências independentes da categoria', () {
      expect(
        policy.plan(
          suggestion: _suggestion(
            evidenceRuleIds: const ['category.career.interview'],
          ),
          rootCategories: const [],
        ),
        isNull,
      );
      expect(
        policy.plan(
          suggestion: _suggestion(
            evidenceRuleIds: const [
              'category.career.interview',
              'category.career.interview',
            ],
          ),
          rootCategories: const [],
        ),
        isNull,
      );
      expect(
        policy.plan(
          suggestion: _suggestion(
            evidenceRuleIds: const [
              'category.career.interview',
              'pattern.date',
              'pattern.url',
            ],
          ),
          rootCategories: const [],
        ),
        isNull,
      );
    });

    test('categoria fora do catálogo nunca é autoaplicada', () {
      final arbitraryRoot = domain.Category(
        id: 4,
        name: 'Pessoal',
        normalizedName: 'pessoal',
        createdAt: DateTime.utc(2026),
      );
      expect(
        policy.plan(
          suggestion: _suggestion(
            category: 'Pessoal',
            evidenceRuleIds: const [
              'category.personal.one',
              'category.personal.two',
            ],
          ),
          rootCategories: [arbitraryRoot],
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
      String? category = 'Carreira',
      double confidence = 0.9,
      List<String> evidenceRuleIds = const [
        'category.career.interview',
        'category.career.recruiter_f',
      ],
      ClassificationSuggestionStatus status =
          ClassificationSuggestionStatus.pendingReview,
    }) async {
      final value = _suggestion(
        mediaItemId: mediaItemId,
        tagNames: tagNames,
        category: category,
        confidence: confidence,
        evidenceRuleIds: evidenceRuleIds,
        status: status,
      );
      return suggestions.saveSuggestion(value);
    }

    Future<void> expectAutomaticRollback(String triggerSql) async {
      final suggestion = await save(tagNames: const ['Urgente']);
      await database.customStatement(triggerSql);
      try {
        await applier.apply(suggestion);
      } catch (_) {
        // O processador do pipeline isola esta falha e mantém a sugestão.
      }
      expect(await categories.loadRootCategories(), isEmpty);
      expect(await tags.loadTags(), isEmpty);
      expect(await database.select(database.mediaCategories).get(), isEmpty);
      expect(await database.select(database.mediaTags).get(), isEmpty);
      expect(
        (await suggestions.loadByMediaItemId(mediaItemId))?.status,
        ClassificationSuggestionStatus.pendingReview,
      );
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
        expect(result.evidence.first.description, 'Evidência sanitizada.');
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

    test('sem raiz equivalente cria e aplica somente a raiz segura', () async {
      final suggestion = await save();

      final result = await applier.apply(suggestion);

      expect(result.status, ClassificationSuggestionStatus.autoApplied);
      final created = await categories.loadRootCategories();
      expect(created, hasLength(1));
      expect(created.single.name, 'Carreira');
      expect(created.single.parentId, isNull);
      expect(await categories.loadForMedia(mediaItemId), hasLength(1));
      expect(
        (await tags.loadTags()).map((tag) => tag.name),
        containsAll(['Urgente', 'Entrevista']),
      );
    });

    test('usa o nome oficial ao receber sugestão normalizada', () async {
      final suggestion = await save(category: ' carreira ');

      expect(
        (await applier.apply(suggestion)).status,
        ClassificationSuggestionStatus.autoApplied,
      );
      expect((await categories.loadRootCategories()).single.name, 'Carreira');
    });

    test('retry após criação não cria pasta ou associação extra', () async {
      final suggestion = await save(tagNames: const []);

      final first = await applier.apply(suggestion);
      final second = await applier.apply(first);

      expect(second.status, ClassificationSuggestionStatus.autoApplied);
      expect(await categories.loadRootCategories(), hasLength(1));
      expect(
        await database.select(database.mediaCategories).get(),
        hasLength(1),
      );
    });

    test('criação preserva pasta e etiqueta anteriores', () async {
      final previousCategory = await categories.createRootCategory('Anterior');
      final previousTag = await tags.createTag('Anterior');
      await categories.replaceForMedia(mediaItemId, {previousCategory.id});
      await tags.addToMedia(tagId: previousTag.id, mediaItemId: mediaItemId);
      final suggestion = await save(tagNames: const ['Urgente']);

      await applier.apply(suggestion);

      expect(
        (await categories.loadForMedia(mediaItemId)).map((item) => item.name),
        containsAll(['Anterior', 'Carreira']),
      );
      expect(
        (await tags.loadForMedia(mediaItemId)).map((item) => item.name),
        containsAll(['Anterior', 'Urgente']),
      );
    });

    test(
      'somente subpasta equivalente não é reutilizada e cria raiz',
      () async {
        final parent = await categories.createRootCategory('Trabalho');
        await categories.createSubcategory(
          parentId: parent.id,
          name: 'Carreira',
        );
        final suggestion = await save();

        expect(
          (await applier.apply(suggestion)).status,
          ClassificationSuggestionStatus.autoApplied,
        );
        final careerRoots = (await categories.loadRootCategories()).where(
          (category) => category.normalizedName == 'carreira',
        );
        expect(careerRoots, hasLength(1));
        expect(careerRoots.single.parentId, isNull);
      },
    );

    test('confiança 0.85 sem raiz permanece pending', () async {
      final suggestion = await save(confidence: 0.85);

      expect(
        (await applier.apply(suggestion)).status,
        ClassificationSuggestionStatus.pendingReview,
      );
      expect(await categories.loadRootCategories(), isEmpty);
    });

    test('pasta removida antes da transação mantém pending', () async {
      final career = await categories.createRootCategory('Carreira');
      await save();
      await categories.deleteCategory(career.id);

      final result = await store.autoApply(
        mediaItemId: mediaItemId,
        expectedCategoryId: career.id,
        officialCategoryName: 'Carreira',
        allowSafeRootCreation: false,
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

    test('duas classificações criam e reutilizam uma única raiz', () async {
      final secondMediaItemId = await database
          .into(database.mediaItems)
          .insert(
            MediaItemsCompanion.insert(
              privatePath: '/tmp/automatic-2.png',
              internalName: 'automatic-2.png',
              importedAt: createdAt,
              sourceMode: 'photoPicker',
              status: 'ready',
            ),
          );
      final first = await save(tagNames: const []);
      final second = await suggestions.saveSuggestion(
        _suggestion(mediaItemId: secondMediaItemId),
      );

      final results = await Future.wait([
        applier.apply(first),
        applier.apply(second),
      ]);

      expect(
        results.map((result) => result.status),
        everyElement(ClassificationSuggestionStatus.autoApplied),
      );
      expect(await categories.loadRootCategories(), hasLength(1));
      expect(
        await database.select(database.mediaCategories).get(),
        hasLength(2),
      );
    });

    test('falha ao criar pasta não deixa estrutura parcial', () async {
      await expectAutomaticRollback('''
        CREATE TRIGGER fail_category_insert
        BEFORE INSERT ON categories
        BEGIN
          SELECT RAISE(ABORT, 'forced test failure');
        END;
      ''');
    });

    test('falha ao criar etiqueta reverte a pasta criada', () async {
      await expectAutomaticRollback('''
        CREATE TRIGGER fail_tag_insert
        BEFORE INSERT ON tags
        BEGIN
          SELECT RAISE(ABORT, 'forced test failure');
        END;
      ''');
    });

    test('falha ao associar pasta reverte pasta e etiqueta', () async {
      await expectAutomaticRollback('''
        CREATE TRIGGER fail_media_category_insert
        BEFORE INSERT ON media_categories
        BEGIN
          SELECT RAISE(ABORT, 'forced test failure');
        END;
      ''');
    });

    test('falha ao atualizar status reverte toda a transação', () async {
      await expectAutomaticRollback('''
        CREATE TRIGGER fail_auto_applied_status
        BEFORE UPDATE OF status ON classification_suggestions
        WHEN NEW.status = 'autoApplied'
        BEGIN
          SELECT RAISE(ABORT, 'forced test failure');
        END;
      ''');
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
  List<String> evidenceRuleIds = const [
    'category.career.interview',
    'category.career.recruiter_f',
  ],
}) {
  final evidence = [
    for (final ruleId in evidenceRuleIds)
      ClassificationEvidence(
        ruleId: ruleId,
        type: ClassificationEvidenceType.keyword,
        description: 'Evidência sanitizada.',
        weight: confidence,
        safeMatch: 'termo seguro',
      ),
  ];
  return StoredClassificationSuggestion(
    mediaItemId: mediaItemId,
    suggestedCategoryName: category,
    confidence: confidence,
    hasSuggestion: hasSuggestion,
    suggestedTags: [
      for (final name in tagNames)
        SuggestedTag(name: name, confidence: confidence, evidence: evidence),
    ],
    evidence: evidence,
    status: status,
    reviewReason: reason,
    engineVersion: 1,
    createdAt: DateTime.utc(2026, 7, 18, 10),
    updatedAt: DateTime.utc(2026, 7, 18, 10),
  );
}

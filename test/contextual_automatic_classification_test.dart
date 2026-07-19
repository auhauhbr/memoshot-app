import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/database/contexto_database.dart';
import 'package:memoshot/features/categories/data/category_repository.dart';
import 'package:memoshot/features/categories/data/category_store.dart';
import 'package:memoshot/features/classification/application/automatic_classification.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_repository.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_store.dart';
import 'package:memoshot/features/classification/data/review_decision_store.dart';
import 'package:memoshot/features/classification/domain/classification_models.dart';
import 'package:memoshot/features/classification/domain/stored_classification_suggestion.dart';

void main() {
  late ContextoDatabase database;
  late LocalCategoryRepository categories;
  late LocalClassificationSuggestionRepository suggestions;
  late ContextualAutomaticClassificationApplier applier;
  late int mediaItemId;
  final now = DateTime.utc(2026, 7, 19, 10);

  setUp(() async {
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    categories = LocalCategoryRepository(store: DriftCategoryStore(database));
    suggestions = LocalClassificationSuggestionRepository(
      DriftClassificationSuggestionStore(database),
    );
    applier = ContextualAutomaticClassificationApplier(
      store: DriftReviewDecisionStore(database),
      now: () => now,
    );
    mediaItemId = await database
        .into(database.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            privatePath: const Value('/tmp/contextual.png'),
            internalName: const Value('contextual.png'),
            importedAt: now,
            sourceMode: 'photoPicker',
            status: 'ready',
          ),
        );
  });

  tearDown(() => database.close());

  Future<StoredClassificationSuggestion> save({
    String destination = 'Livros / Capas',
    double confidence = 0.91,
    double margin = 0.20,
    List<String> tags = const ['Amazon', 'Livro'],
  }) {
    final evidence = [
      ClassificationEvidence(
        ruleId: 'context.destination.margin',
        type: ClassificationEvidenceType.pattern,
        description: 'Margem técnica.',
        weight: margin,
      ),
    ];
    return suggestions.saveSuggestion(
      StoredClassificationSuggestion(
        mediaItemId: mediaItemId,
        suggestedCategoryName: destination,
        confidence: confidence,
        hasSuggestion: true,
        suggestedTags: [
          for (final name in tags)
            SuggestedTag(name: name, confidence: 0.90, evidence: evidence),
        ],
        evidence: evidence,
        status: ClassificationSuggestionStatus.pendingReview,
        reviewReason: ClassificationReviewReason.manualReview,
        engineVersion: 1,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('cria somente raiz e subpasta oficiais com confiança segura', () async {
    final result = await applier.apply(await save());

    expect(result.status, ClassificationSuggestionStatus.autoApplied);
    final roots = await categories.loadRootCategories();
    expect(roots.single.name, 'Livros');
    final children = await categories.loadChildCategories(roots.single.id);
    expect(children.single.name, 'Capas');
    expect(
      (await categories.loadForMedia(mediaItemId)).single.id,
      children.single.id,
    );
  });

  test('destino existente usa limite 0.82 e exige margem 0.15', () async {
    final root = await categories.createRootCategory('Produtos');
    final applied = await applier.apply(
      await save(destination: 'Produtos', confidence: 0.82, margin: 0.15),
    );
    expect(applied.status, ClassificationSuggestionStatus.autoApplied);
    expect((await categories.loadForMedia(mediaItemId)).single.id, root.id);
  });

  test('confiança ou margem insuficiente mantém item incerto', () async {
    await categories.createRootCategory('Produtos');
    final low = await applier.apply(
      await save(destination: 'Produtos', confidence: 0.81),
    );
    expect(low.status, ClassificationSuggestionStatus.pendingReview);
    expect(await categories.loadForMedia(mediaItemId), isEmpty);
  });

  test('empate ou margem insuficiente não é autoaplicado', () async {
    await categories.createRootCategory('Produtos');
    final result = await applier.apply(
      await save(destination: 'Produtos', confidence: 0.95, margin: 0.14),
    );
    expect(result.status, ClassificationSuggestionStatus.pendingReview);
    expect(await categories.loadForMedia(mediaItemId), isEmpty);
  });

  test('decisão manual existente nunca é sobrescrita', () async {
    final manual = await categories.createRootCategory('Pessoal');
    await categories.replaceForMedia(mediaItemId, {manual.id});

    final result = await applier.apply(await save());

    expect(result.status, ClassificationSuggestionStatus.pendingReview);
    expect(
      (await categories.loadForMedia(mediaItemId)).map((item) => item.name),
      ['Pessoal'],
    );
    expect((await categories.loadRootCategories()).map((item) => item.name), [
      'Pessoal',
    ]);
  });

  test(
    'Compras existente é compatível e evita raiz Produtos duplicada',
    () async {
      final compras = await categories.createRootCategory('Compras');

      final result = await applier.apply(
        await save(destination: 'Produtos', tags: const ['Produto', 'Amazon']),
      );

      expect(result.status, ClassificationSuggestionStatus.autoApplied);
      expect(
        (await categories.loadForMedia(mediaItemId)).single.id,
        compras.id,
      );
      expect((await categories.loadRootCategories()).map((item) => item.name), [
        'Compras',
      ]);
    },
  );

  test('aplica no máximo quatro etiquetas da allowlist', () async {
    await categories.createRootCategory('Produtos');
    await applier.apply(
      await save(
        destination: 'Produtos',
        tags: const [
          'Amazon',
          'Produto',
          'Teclado',
          'Notebook',
          'Carro',
          'Label crua',
        ],
      ),
    );

    final rows = await database.select(database.mediaTags).get();
    expect(rows.length, 4);
    expect(
      (await database.select(database.tags).get()).map((tag) => tag.name),
      isNot(contains('Label crua')),
    );
  });
}

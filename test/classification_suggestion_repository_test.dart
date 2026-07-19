import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/database/contexto_database.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_repository.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_store.dart';
import 'package:memoshot/features/classification/domain/classification_models.dart';
import 'package:memoshot/features/classification/domain/local_classification_engine.dart';
import 'package:memoshot/features/classification/domain/stored_classification_suggestion.dart';

void main() {
  late ContextoDatabase database;
  late LocalClassificationSuggestionRepository repository;
  late int mediaItemId;
  var now = DateTime.utc(2026, 7, 18, 10);

  setUp(() async {
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    repository = LocalClassificationSuggestionRepository(
      DriftClassificationSuggestionStore(database),
      now: () => now,
    );
    mediaItemId = await _insertMedia(database);
  });

  tearDown(() => database.close());

  test('salva e carrega todos os campos da sugestão', () async {
    final suggestion = _suggestion(mediaItemId, now);

    await repository.saveSuggestion(suggestion);
    final loaded = await repository.loadByMediaItemId(mediaItemId);

    expect(loaded, isNotNull);
    expect(loaded!.suggestedCategoryName, 'Carreira');
    expect(loaded.confidence, 0.42);
    expect(loaded.hasSuggestion, isTrue);
    expect(loaded.suggestedTags.map((tag) => tag.name), ['Vaga', 'Urgente']);
    expect(loaded.evidence.map((item) => item.ruleId), [
      'category.carreira.vaga',
      'pattern.email',
    ]);
    expect(loaded.status, ClassificationSuggestionStatus.pendingReview);
    expect(loaded.reviewReason, ClassificationReviewReason.lowConfidence);
    expect(loaded.engineVersion, 1);
    expect(loaded.createdAt.isAtSameMomentAs(now), isTrue);
    expect(loaded.updatedAt.isAtSameMomentAs(now), isTrue);
  });

  test('aceita categoria nula e listas imutáveis', () async {
    final value = StoredClassificationSuggestion(
      mediaItemId: mediaItemId,
      suggestedCategoryName: null,
      confidence: -2,
      hasSuggestion: false,
      suggestedTags: const [],
      evidence: const [],
      status: ClassificationSuggestionStatus.pendingReview,
      reviewReason: ClassificationReviewReason.noSuggestion,
      engineVersion: 1,
      createdAt: now,
      updatedAt: now,
    );

    await repository.saveSuggestion(value);
    final loaded = (await repository.loadByMediaItemId(mediaItemId))!;

    expect(loaded.suggestedCategoryName, isNull);
    expect(loaded.confidence, 0);
    expect(
      () => loaded.suggestedTags.add(_tag('Outra')),
      throwsUnsupportedError,
    );
    expect(() => loaded.evidence.clear(), throwsUnsupportedError);
  });

  test(
    'substituição não duplica, preserva criação e volta a pendente',
    () async {
      await repository.saveSuggestion(_suggestion(mediaItemId, now));
      now = now.add(const Duration(hours: 1));
      await repository.markAccepted(mediaItemId);
      final replacement = StoredClassificationSuggestion(
        mediaItemId: mediaItemId,
        suggestedCategoryName: 'Estudos',
        confidence: 0.8,
        hasSuggestion: true,
        suggestedTags: [_tag('Curso')],
        evidence: [_evidence('category.estudos.curso')],
        status: ClassificationSuggestionStatus.rejected,
        reviewReason: ClassificationReviewReason.manualReview,
        engineVersion: 2,
        createdAt: now,
        updatedAt: now,
        resolvedAt: now,
      );

      final saved = await repository.replaceSuggestion(replacement);
      final rows = await database
          .select(database.classificationSuggestions)
          .get();

      expect(rows, hasLength(1));
      expect(saved.suggestedCategoryName, 'Estudos');
      expect(saved.suggestedTags.single.name, 'Curso');
      expect(saved.evidence.single.ruleId, 'category.estudos.curso');
      expect(saved.status, ClassificationSuggestionStatus.pendingReview);
      expect(
        saved.createdAt.isAtSameMomentAs(DateTime.utc(2026, 7, 18, 10)),
        isTrue,
      );
      expect(saved.updatedAt.isAtSameMomentAs(now), isTrue);
      expect(saved.resolvedAt, isNull);
    },
  );

  test('operações concorrentes mantêm uma sugestão por screenshot', () async {
    await Future.wait([
      repository.saveSuggestion(_suggestion(mediaItemId, now)),
      repository.saveSuggestion(_suggestion(mediaItemId, now)),
      repository.saveSuggestion(_suggestion(mediaItemId, now)),
    ]);

    expect(
      await database.select(database.classificationSuggestions).get(),
      hasLength(1),
    );
  });

  test(
    'atualiza os quatro status sem modificar relações do screenshot',
    () async {
      final categoryId = await database
          .into(database.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Carreira',
              normalizedName: 'carreira',
              createdAt: now,
            ),
          );
      final tagId = await database
          .into(database.tags)
          .insert(
            TagsCompanion.insert(
              name: 'Original',
              normalizedName: 'original',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.mediaCategories)
          .insert(
            MediaCategoriesCompanion.insert(
              mediaItemId: mediaItemId,
              categoryId: categoryId,
              createdAt: now,
            ),
          );
      await database
          .into(database.mediaTags)
          .insert(
            MediaTagsCompanion.insert(
              mediaItemId: mediaItemId,
              tagId: tagId,
              createdAt: now,
            ),
          );
      await repository.saveSuggestion(_suggestion(mediaItemId, now));

      for (final status in ClassificationSuggestionStatus.values) {
        now = now.add(const Duration(minutes: 1));
        final updated = await repository.updateStatus(mediaItemId, status);
        expect(updated.status, status);
        expect(
          updated.resolvedAt,
          status == ClassificationSuggestionStatus.pendingReview ? isNull : now,
        );
      }
      expect(await database.select(database.mediaItems).get(), hasLength(1));
      expect(
        await database.select(database.mediaCategories).get(),
        hasLength(1),
      );
      expect(await database.select(database.mediaTags).get(), hasLength(1));
    },
  );

  test('fila inclui só pendentes e usa ordem determinística', () async {
    final second = await _insertMedia(database, name: 'second.png');
    final third = await _insertMedia(database, name: 'third.png');
    final fourth = await _insertMedia(database, name: 'fourth.png');
    await repository.saveSuggestion(
      _suggestion(mediaItemId, now, confidence: 0.7),
    );
    await repository.saveSuggestion(_suggestion(second, now, confidence: 0.2));
    await repository.saveSuggestion(
      StoredClassificationSuggestion(
        mediaItemId: third,
        suggestedCategoryName: null,
        confidence: 0.1,
        hasSuggestion: false,
        suggestedTags: const [],
        evidence: const [],
        status: ClassificationSuggestionStatus.pendingReview,
        reviewReason: ClassificationReviewReason.ambiguous,
        engineVersion: 1,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.markRejected(second);
    await repository.saveSuggestion(_suggestion(fourth, now, confidence: 0.9));
    await repository.markAutoApplied(fourth);

    final pending = await repository.loadPendingReview();

    expect(await repository.countPendingReview(), 2);
    expect(pending.map((item) => item.mediaItemId), [mediaItemId, third]);
  });

  test(
    'excluir sugestão preserva item e excluir item remove sugestão',
    () async {
      await repository.saveSuggestion(_suggestion(mediaItemId, now));
      await repository.deleteForMediaItem(mediaItemId);
      expect(await database.select(database.mediaItems).get(), hasLength(1));
      expect(await repository.loadByMediaItemId(mediaItemId), isNull);

      await repository.saveSuggestion(_suggestion(mediaItemId, now));
      await (database.delete(
        database.mediaItems,
      )..where((item) => item.id.equals(mediaItemId))).go();
      expect(await repository.loadByMediaItemId(mediaItemId), isNull);
    },
  );

  test('screenshot inexistente é rejeitado pela chave estrangeira', () async {
    await expectLater(
      repository.saveSuggestion(_suggestion(999, now)),
      throwsA(anything),
    );
  });

  test('payload persiste evidência estrutural sem dados sensíveis', () async {
    const ocr =
        'segredo@empresa.com +55 (81) 99999-1234 '
        'https://privado.example/caminho R\$ 8.450,00';
    final result = const LocalClassificationEngine().classify(
      const ClassificationInput(ocrText: ocr),
    );
    await repository.saveSuggestion(
      StoredClassificationSuggestion.fromEngine(
        mediaItemId: mediaItemId,
        suggestion: result,
        reviewReason: ClassificationReviewReason.lowConfidence,
        createdAt: now,
        engineVersion: 1,
      ),
    );

    final row = await database
        .select(database.classificationSuggestions)
        .getSingle();
    final payload = '${row.suggestedTagsJson} ${row.evidenceJson}';
    expect(payload, isNot(contains(ocr)));
    expect(payload, isNot(contains('segredo@empresa.com')));
    expect(payload, isNot(contains('99999-1234')));
    expect(payload, isNot(contains('privado.example')));
    expect(payload, isNot(contains('8.450,00')));
    expect(payload, contains('pattern.email'));
    expect(payload, contains('pattern.phone'));
    expect(payload, contains('pattern.url'));
    expect(payload, contains('pattern.brl'));
  });

  test('persiste após fechar e reabrir o banco', () async {
    await database.close();
    final directory = Directory.systemTemp.createTempSync('suggestion_test_');
    final file = File('${directory.path}/database.sqlite');
    database = ContextoDatabase.forTesting(NativeDatabase(file));
    repository = LocalClassificationSuggestionRepository(
      DriftClassificationSuggestionStore(database),
    );
    mediaItemId = await _insertMedia(database);
    await repository.saveSuggestion(_suggestion(mediaItemId, now));
    await database.close();

    database = ContextoDatabase.forTesting(NativeDatabase(file));
    repository = LocalClassificationSuggestionRepository(
      DriftClassificationSuggestionStore(database),
    );
    expect(
      (await repository.loadByMediaItemId(mediaItemId))?.suggestedCategoryName,
      'Carreira',
    );
    await database.close();
    directory.deleteSync(recursive: true);
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
  });

  test(
    'snapshot conta somente pendências sem carregar payload privado',
    () async {
      final secondId = await _insertMedia(database, name: 'second.png');
      final thirdId = await _insertMedia(database, name: 'third.png');
      await repository.saveSuggestion(_suggestion(mediaItemId, now));
      final latestAt = now.add(const Duration(minutes: 2));
      await repository.saveSuggestion(_suggestion(secondId, latestAt));
      await repository.saveSuggestion(
        _suggestion(thirdId, now.add(const Duration(minutes: 1))),
      );
      now = now.add(const Duration(minutes: 3));
      await repository.markAccepted(thirdId);

      final snapshot = await repository.loadReviewNotificationSnapshot();

      expect(snapshot.pendingCount, 2);
      expect(
        snapshot.latestPendingCreatedAt?.isAtSameMomentAs(latestAt),
        isTrue,
      );
      expect(snapshot.latestPendingMediaItemId, secondId);
      expect(snapshot.marker, '${latestAt.microsecondsSinceEpoch}:$secondId');
    },
  );
}

Future<int> _insertMedia(
  ContextoDatabase database, {
  String name = 'item.png',
}) {
  return database
      .into(database.mediaItems)
      .insert(
        MediaItemsCompanion.insert(
          privatePath: '/tmp/$name',
          internalName: name,
          importedAt: DateTime.utc(2026),
          sourceMode: 'picker',
          status: 'ready',
        ),
      );
}

StoredClassificationSuggestion _suggestion(
  int mediaItemId,
  DateTime at, {
  double confidence = 0.42,
}) {
  final evidence = [
    _evidence('category.carreira.vaga', safeMatch: 'vaga'),
    ClassificationEvidence(
      ruleId: 'pattern.email',
      type: ClassificationEvidenceType.pattern,
      description: 'Encontrou um endereço de e-mail.',
      weight: 0.2,
      count: 1,
    ),
  ];
  return StoredClassificationSuggestion(
    mediaItemId: mediaItemId,
    suggestedCategoryName: 'Carreira',
    confidence: confidence,
    hasSuggestion: true,
    suggestedTags: [_tag('Vaga'), _tag('Urgente')],
    evidence: evidence,
    status: ClassificationSuggestionStatus.pendingReview,
    reviewReason: ClassificationReviewReason.lowConfidence,
    engineVersion: 1,
    createdAt: at,
    updatedAt: at,
  );
}

SuggestedTag _tag(String name) {
  return SuggestedTag(name: name, confidence: 0.5, evidence: const []);
}

ClassificationEvidence _evidence(String ruleId, {String? safeMatch}) {
  return ClassificationEvidence(
    ruleId: ruleId,
    type: ClassificationEvidenceType.keyword,
    description: 'Termo fixo do catálogo.',
    weight: 0.4,
    safeMatch: safeMatch,
    count: 1,
  );
}

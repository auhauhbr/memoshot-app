import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/database/contexto_database.dart'
    show ContextoDatabase, MediaItemsCompanion;
import 'package:memoshot/features/classification/application/classification_processor.dart';
import 'package:memoshot/features/classification/application/automatic_classification.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_repository.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_store.dart';
import 'package:memoshot/features/classification/domain/classification_models.dart';
import 'package:memoshot/features/classification/domain/local_classification_engine.dart';
import 'package:memoshot/features/classification/domain/stored_classification_suggestion.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/ocr/domain/ocr_result.dart';

void main() {
  late ContextoDatabase database;
  late LocalClassificationSuggestionRepository repository;
  final processedAt = DateTime.utc(2026, 7, 18, 9);
  final now = DateTime.utc(2026, 7, 18, 10);

  setUp(() {
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    repository = LocalClassificationSuggestionRepository(
      DriftClassificationSuggestionStore(database),
    );
  });

  tearDown(() => database.close());

  test(
    'OCR concluído persiste categoria, tags, evidências e metadados',
    () async {
      final item = await _insertMedia(database);
      final processor = _processor(repository, now: now);

      final saved = await processor.process(
        mediaItem: item,
        ocrResult: _ocr(
          item.id,
          'Vaga entrevista recrutadora urgente processo seletivo',
          processedAt,
        ),
      );
      final loaded = await repository.loadByMediaItemId(item.id);

      expect(loaded?.suggestedCategoryName, 'Carreira');
      expect(
        loaded?.suggestedTags.map((tag) => tag.name),
        containsAll(['Entrevista', 'Urgente', 'Vaga']),
      );
      expect(loaded?.evidence, isNotEmpty);
      expect(loaded?.hasSuggestion, isTrue);
      expect(saved.engineVersion, currentClassificationEngineVersion);
      expect(saved.engineVersion, 1);
      expect(saved.status, ClassificationSuggestionStatus.pendingReview);
      expect(saved.reviewReason, ClassificationReviewReason.manualReview);
      expect(saved.createdAt, now);
      expect(saved.updatedAt, now);
    },
  );

  test('texto vazio persiste noSuggestion pendente', () async {
    final item = await _insertMedia(database);

    final saved = await _processor(
      repository,
      now: now,
    ).process(mediaItem: item, ocrResult: _ocr(item.id, '', processedAt));

    expect(saved.hasSuggestion, isFalse);
    expect(saved.suggestedCategoryName, isNull);
    expect(saved.suggestedTags, isEmpty);
    expect(saved.reviewReason, ClassificationReviewReason.noSuggestion);
    expect(saved.status, ClassificationSuggestionStatus.pendingReview);
  });

  test('mapeamento de reviewReason é determinístico', () {
    expect(
      classificationReviewReasonFor(ClassificationSuggestion.empty()),
      ClassificationReviewReason.noSuggestion,
    );
    expect(
      classificationReviewReasonFor(_suggestion(category: null, confidence: 1)),
      ClassificationReviewReason.noCategory,
    );
    expect(
      classificationReviewReasonFor(_suggestion(confidence: 0.71)),
      ClassificationReviewReason.lowConfidence,
    );
    expect(
      classificationReviewReasonFor(_suggestion(confidence: 0.72)),
      ClassificationReviewReason.manualReview,
    );
  });

  test('mesma entrada produz payload determinístico', () async {
    final first = await _insertMedia(database, name: 'first.png');
    final second = await _insertMedia(database, name: 'second.png');
    final processor = _processor(repository, now: now);

    final values = await Future.wait([
      processor.process(
        mediaItem: first,
        ocrResult: _ocr(first.id, 'curso aula certificado', processedAt),
      ),
      processor.process(
        mediaItem: second,
        ocrResult: _ocr(second.id, 'curso aula certificado', processedAt),
      ),
    ]);

    expect(values[0].suggestedCategoryName, values[1].suggestedCategoryName);
    expect(values[0].suggestedTags, values[1].suggestedTags);
    expect(values[0].evidence, values[1].evidence);
    expect(values[0].confidence, values[1].confidence);
    expect(values[0].hasSuggestion, values[1].hasSuggestion);
  });

  test(
    'sugestão atual evita motor e chamadas concorrentes não duplicam',
    () async {
      final item = await _insertMedia(database);
      final engine = _CountingEngine(_suggestion(confidence: 0.8));
      final processor = _processor(repository, now: now, engine: engine);
      final ocr = _ocr(item.id, 'texto', processedAt);

      await Future.wait([
        processor.process(mediaItem: item, ocrResult: ocr),
        processor.process(mediaItem: item, ocrResult: ocr),
      ]);
      await processor.process(mediaItem: item, ocrResult: ocr);

      expect(engine.calls, 1);
      expect(
        await database.select(database.classificationSuggestions).get(),
        hasLength(1),
      );
    },
  );

  test('processadores concorrentes mantêm uma única sugestão', () async {
    final item = await _insertMedia(database);
    final firstEngine = _CountingEngine(_suggestion(confidence: 0.8));
    final secondEngine = _CountingEngine(_suggestion(confidence: 0.8));
    final ocr = _ocr(item.id, 'texto', processedAt);

    await Future.wait([
      _processor(
        repository,
        now: now,
        engine: firstEngine,
      ).process(mediaItem: item, ocrResult: ocr),
      _processor(
        repository,
        now: now,
        engine: secondEngine,
      ).process(mediaItem: item, ocrResult: ocr),
    ]);

    expect(
      await database.select(database.classificationSuggestions).get(),
      hasLength(1),
    );
  });

  for (final status in [
    ClassificationSuggestionStatus.accepted,
    ClassificationSuggestionStatus.rejected,
    ClassificationSuggestionStatus.autoApplied,
  ]) {
    test('$status não é sobrescrito por retomada automática', () async {
      final item = await _insertMedia(database);
      final engine = _CountingEngine(_suggestion(confidence: 0.8));
      final processor = _processor(repository, now: now, engine: engine);
      final first = await processor.process(
        mediaItem: item,
        ocrResult: _ocr(item.id, 'original', processedAt),
      );
      await repository.updateStatus(item.id, status);

      final result = await processor.process(
        mediaItem: item,
        ocrResult: _ocr(
          item.id,
          'novo texto',
          processedAt.add(const Duration(days: 1)),
        ),
      );

      expect(engine.calls, 1);
      expect(result.status, status);
      expect(result.suggestedCategoryName, first.suggestedCategoryName);
    });
  }

  test(
    'OCR explicitamente mais novo pode substituir sugestão pendente',
    () async {
      final item = await _insertMedia(database);
      final engine = _CountingEngine(_suggestion(confidence: 0.8));
      final processor = _processor(repository, now: now, engine: engine);
      await processor.process(
        mediaItem: item,
        ocrResult: _ocr(item.id, 'primeiro', processedAt),
      );

      final newerProcessor = _processor(
        repository,
        now: now.add(const Duration(days: 2)),
        engine: engine,
      );
      await newerProcessor.process(
        mediaItem: item,
        ocrResult: _ocr(item.id, 'segundo', now.add(const Duration(days: 1))),
      );

      expect(engine.calls, 2);
      expect(
        await database.select(database.classificationSuggestions).get(),
        hasLength(1),
      );
    },
  );

  test('versão atual substitui análise pendente de versão anterior', () async {
    final item = await _insertMedia(database);
    final engine = _CountingEngine(_suggestion(confidence: 0.8));
    await _processor(
      repository,
      now: now,
      engine: engine,
      engineVersion: 0,
    ).process(mediaItem: item, ocrResult: _ocr(item.id, 'antigo', processedAt));

    final current = await _processor(
      repository,
      now: now.add(const Duration(hours: 1)),
      engine: engine,
    ).process(mediaItem: item, ocrResult: _ocr(item.id, 'atual', processedAt));

    expect(engine.calls, 2);
    expect(current.engineVersion, currentClassificationEngineVersion);
    expect(
      await database.select(database.classificationSuggestions).get(),
      hasLength(1),
    );
  });

  test('payload automático não contém OCR nem dados sensíveis', () async {
    final item = await _insertMedia(database);
    const text =
        'Segredo completo segredo@empresa.com +55 (81) 99999-1234 '
        'https://privado.example/caminho R\$ 8.450,00';

    final logs = <String>[];
    await runZoned(
      () => _processor(
        repository,
        now: now,
      ).process(mediaItem: item, ocrResult: _ocr(item.id, text, processedAt)),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => logs.add(line),
      ),
    );
    final row = await database
        .select(database.classificationSuggestions)
        .getSingle();
    final payload =
        '${row.suggestedCategoryName} ${row.suggestedTagsJson} ${row.evidenceJson}';

    expect(payload, isNot(contains(text)));
    expect(payload, isNot(contains('segredo@empresa.com')));
    expect(payload, isNot(contains('99999-1234')));
    expect(payload, isNot(contains('privado.example')));
    expect(payload, isNot(contains('8.450,00')));
    expect(logs.join(' '), isNot(contains(text)));
    expect(logs.join(' '), isNot(contains('segredo@empresa.com')));
  });

  test(
    'falha do autoaplicador preserva sugestões e permite próximo item',
    () async {
      final first = await _insertMedia(database, name: 'first-failure.png');
      final second = await _insertMedia(database, name: 'second-failure.png');
      final applier = _FailingAutomaticApplier();
      final processor = _processor(
        repository,
        now: now,
        automaticApplier: applier,
      );

      final results = await Future.wait([
        processor.process(
          mediaItem: first,
          ocrResult: _ocr(first.id, 'vaga entrevista', processedAt),
        ),
        processor.process(
          mediaItem: second,
          ocrResult: _ocr(second.id, 'curso certificado', processedAt),
        ),
      ]);

      expect(applier.calls, 2);
      expect(
        results.map((item) => item.status),
        everyElement(ClassificationSuggestionStatus.pendingReview),
      );
      expect(await repository.countPendingReview(), 2);
    },
  );

  test(
    'retry pendente tenta autoaplicação sem executar novamente o motor',
    () async {
      final item = await _insertMedia(database, name: 'retry-auto.png');
      final engine = _CountingEngine(_suggestion(confidence: 0.9));
      final applier = _FailingAutomaticApplier();
      final processor = _processor(
        repository,
        now: now,
        engine: engine,
        automaticApplier: applier,
      );
      final ocr = _ocr(item.id, 'vaga entrevista', processedAt);

      await processor.process(mediaItem: item, ocrResult: ocr);
      await processor.process(mediaItem: item, ocrResult: ocr);

      expect(engine.calls, 1);
      expect(applier.calls, 2);
      expect(
        (await repository.loadByMediaItemId(item.id))?.status,
        ClassificationSuggestionStatus.pendingReview,
      );
    },
  );
}

LocalClassificationProcessor _processor(
  ClassificationSuggestionRepository repository, {
  required DateTime now,
  LocalClassificationEngine engine = const LocalClassificationEngine(),
  int engineVersion = currentClassificationEngineVersion,
  AutomaticClassificationApplier? automaticApplier,
}) {
  return LocalClassificationProcessor(
    engine: engine,
    repository: repository,
    now: () => now,
    engineVersion: engineVersion,
    automaticApplier: automaticApplier,
  );
}

class _FailingAutomaticApplier implements AutomaticClassificationApplier {
  int calls = 0;

  @override
  Future<StoredClassificationSuggestion> apply(
    StoredClassificationSuggestion suggestion,
  ) async {
    calls++;
    throw StateError('falha técnica sanitizada');
  }
}

class _CountingEngine extends LocalClassificationEngine {
  _CountingEngine(this.result);

  final ClassificationSuggestion result;
  int calls = 0;

  @override
  ClassificationSuggestion classify(ClassificationInput input) {
    calls++;
    return result;
  }
}

ClassificationSuggestion _suggestion({
  String? category = 'Carreira',
  required double confidence,
}) {
  final evidence = ClassificationEvidence(
    ruleId: 'test.safe',
    type: ClassificationEvidenceType.keyword,
    description: 'Evidência segura de teste.',
    weight: confidence,
    safeMatch: 'teste',
  );
  return ClassificationSuggestion(
    suggestedCategoryName: category,
    suggestedTags: [
      SuggestedTag(name: 'Teste', confidence: confidence, evidence: [evidence]),
    ],
    confidence: confidence,
    evidence: [evidence],
  );
}

Future<MediaItem> _insertMedia(
  ContextoDatabase database, {
  String name = 'item.png',
}) async {
  final importedAt = DateTime.utc(2026, 7, 18, 8);
  final id = await database
      .into(database.mediaItems)
      .insert(
        MediaItemsCompanion.insert(
          privatePath: '/tmp/$name',
          internalName: name,
          mimeType: const Value('image/png'),
          importedAt: importedAt,
          capturedAt: Value(importedAt),
          sourceMode: 'photoPicker',
          status: 'ready',
        ),
      );
  return MediaItem(
    id: id,
    privatePath: '/tmp/$name',
    internalName: name,
    mimeType: 'image/png',
    importedAt: importedAt,
    capturedAt: importedAt,
    sourceMode: 'photoPicker',
    status: 'ready',
  );
}

OcrResult _ocr(int mediaItemId, String text, DateTime processedAt) {
  return OcrResult(
    mediaItemId: mediaItemId,
    fullText: text,
    engine: 'OCR de teste',
    engineVersion: '1',
    processedAt: processedAt,
  );
}

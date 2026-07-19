import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/database/contexto_database.dart'
    show ContextoDatabase, ClassificationJobsCompanion, MediaItemsCompanion;
import 'package:memoshot/features/classification/application/classification_processor.dart';
import 'package:memoshot/features/classification/application/classification_queue_processor.dart';
import 'package:memoshot/features/classification/application/automatic_classification.dart';
import 'package:memoshot/features/classification/data/classification_job_store.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_repository.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_store.dart';
import 'package:memoshot/features/classification/data/review_decision_store.dart';
import 'package:memoshot/features/classification/domain/classification_job.dart';
import 'package:memoshot/features/classification/domain/classification_models.dart';
import 'package:memoshot/features/classification/domain/local_classification_engine.dart';
import 'package:memoshot/features/classification/domain/stored_classification_suggestion.dart';
import 'package:memoshot/features/categories/data/category_repository.dart';
import 'package:memoshot/features/categories/data/category_store.dart';
import 'package:memoshot/features/library/data/media_item_repository.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/library/domain/screenshot_search_result.dart';
import 'package:memoshot/features/library/domain/selected_screenshot.dart';
import 'package:memoshot/features/ocr/data/ocr_repository.dart';
import 'package:memoshot/features/ocr/data/ocr_result_store.dart';
import 'package:memoshot/features/ocr/domain/ocr_result.dart';

void main() {
  group('persistência da fila de classificação', () {
    late ContextoDatabase database;
    late DriftClassificationJobStore store;
    final now = DateTime.utc(2026, 7, 19, 10);

    setUp(() {
      database = ContextoDatabase.forTesting(NativeDatabase.memory());
      store = DriftClassificationJobStore(database);
    });

    tearDown(() => database.close());

    test(
      'enfileira uma linha idempotente com versão, estado e datas',
      () async {
        final item = await _insertMedia(database, 1);
        await _saveOcr(database, item.id, now);

        expect(
          await store.enqueueIfNeeded(
            mediaItemId: item.id,
            engineVersion: currentClassificationEngineVersion,
            now: now,
          ),
          isTrue,
        );
        expect(
          await store.enqueueIfNeeded(
            mediaItemId: item.id,
            engineVersion: currentClassificationEngineVersion,
            now: now,
          ),
          isFalse,
        );

        final job = await store.findByMediaItemId(item.id);
        expect(job?.state, ClassificationJobState.pending);
        expect(job?.attempts, 0);
        expect(job?.availableAt.toUtc(), now);
        expect(job?.createdAt.toUtc(), now);
        expect(job?.updatedAt.toUtc(), now);
        expect(job?.engineVersion, currentClassificationEngineVersion);
        expect(
          await database.select(database.classificationJobs).get(),
          hasLength(1),
        );
      },
    );

    test(
      'excluir screenshot remove job e excluir job preserva screenshot',
      () async {
        final first = await _insertMedia(database, 2);
        final second = await _insertMedia(database, 3);
        await _saveOcr(database, first.id, now);
        await _saveOcr(database, second.id, now);
        await store.enqueueIfNeeded(
          mediaItemId: first.id,
          engineVersion: 1,
          now: now,
        );
        await store.enqueueIfNeeded(
          mediaItemId: second.id,
          engineVersion: 1,
          now: now,
        );

        await (database.delete(
          database.mediaItems,
        )..where((row) => row.id.equals(first.id))).go();
        await store.deleteForMediaItem(second.id);

        expect(await store.findByMediaItemId(first.id), isNull);
        expect(await store.findByMediaItemId(second.id), isNull);
        expect(
          await (database.select(
            database.mediaItems,
          )..where((row) => row.id.equals(second.id))).getSingleOrNull(),
          isNotNull,
        );
      },
    );

    test('tabela não possui OCR, caminho, payload ou mensagem livre', () async {
      await database.customSelect('SELECT 1').get();
      final columns = await database
          .customSelect('PRAGMA table_info(classification_jobs)')
          .get();
      final names = columns.map((row) => row.read<String>('name')).toSet();

      expect(names, {
        'media_item_id',
        'state',
        'attempts',
        'available_at',
        'engine_version',
        'created_at',
        'updated_at',
        'processing_started_at',
        'last_error_code',
      });
      expect(names.any((name) => name.contains('ocr')), isFalse);
      expect(names.any((name) => name.contains('path')), isFalse);
      expect(names.any((name) => name.contains('json')), isFalse);
      expect(names.any((name) => name.contains('message')), isFalse);
    });
  });

  test('job persiste após fechar e reabrir o banco', () async {
    final directory = Directory.systemTemp.createTempSync(
      'memoshot_classification_job_',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/contexto.sqlite');
    final now = DateTime.utc(2026, 7, 19, 10);
    var database = ContextoDatabase.forTesting(NativeDatabase(file));
    final item = await _insertMedia(database, 4);
    await _saveOcr(database, item.id, now);
    await DriftClassificationJobStore(
      database,
    ).enqueueIfNeeded(mediaItemId: item.id, engineVersion: 1, now: now);
    await database.close();

    database = ContextoDatabase.forTesting(NativeDatabase(file));
    final job = await DriftClassificationJobStore(
      database,
    ).findByMediaItemId(item.id);
    expect(job?.state, ClassificationJobState.pending);
    expect(job?.engineVersion, 1);
    await database.close();
  });

  group('processamento, retry e recuperação', () {
    late ContextoDatabase database;
    late DriftClassificationJobStore jobStore;
    late LocalClassificationSuggestionRepository suggestions;
    late DriftOcrResultStore ocrStore;
    late _MediaRepository mediaRepository;
    late _OcrRepository ocrRepository;
    late DateTime clock;
    final start = DateTime.utc(2026, 7, 19, 12);

    setUp(() {
      database = ContextoDatabase.forTesting(NativeDatabase.memory());
      jobStore = DriftClassificationJobStore(database);
      suggestions = LocalClassificationSuggestionRepository(
        DriftClassificationSuggestionStore(database),
      );
      ocrStore = DriftOcrResultStore(database);
      mediaRepository = _MediaRepository();
      ocrRepository = _OcrRepository(ocrStore);
      clock = start;
    });

    tearDown(() => database.close());

    Future<MediaItem> prepare(int marker, {String text = 'texto'}) async {
      final item = await _insertMedia(database, marker);
      mediaRepository.items[item.id] = item;
      await ocrStore.save(
        OcrResult(
          mediaItemId: item.id,
          fullText: text,
          engine: 'Teste',
          engineVersion: '1',
          processedAt: start,
        ),
      );
      await jobStore.enqueueIfNeeded(
        mediaItemId: item.id,
        engineVersion: currentClassificationEngineVersion,
        now: clock,
      );
      return item;
    }

    LocalClassificationQueueProcessor queue(
      ClassificationProcessor processor, {
      int maximumBatchSize = 10,
      Duration expiration = classificationProcessingExpiration,
    }) {
      return LocalClassificationQueueProcessor(
        jobStore: jobStore,
        classificationProcessor: processor,
        suggestionRepository: suggestions,
        mediaRepository: mediaRepository,
        ocrRepository: ocrRepository,
        now: () => clock,
        maximumBatchSize: maximumBatchSize,
        processingExpiration: expiration,
      );
    }

    test('executa sem repetir OCR, persiste sugestão e remove job', () async {
      final item = await prepare(10, text: 'vaga entrevista');
      final processor = _SavingProcessor(suggestions);
      final subject = queue(processor);
      addTearDown(subject.close);

      subject.signal();
      await _waitUntil(
        () async => await jobStore.findByMediaItemId(item.id) == null,
      );

      expect(processor.calls, 1);
      expect(ocrRepository.processCalls, 0);
      expect(await suggestions.loadByMediaItemId(item.id), isNotNull);
    });

    test(
      'autoaplicação e criação segura de raiz continuam funcionando',
      () async {
        final item = await prepare(
          20,
          text:
              'vaga entrevista recrutadora currículo candidatura processo seletivo urgente',
        );
        final categories = LocalCategoryRepository(
          store: DriftCategoryStore(database),
        );
        final processor = LocalClassificationProcessor(
          engine: const LocalClassificationEngine(),
          repository: suggestions,
          now: () => clock,
          engineVersion: currentClassificationEngineVersion,
          automaticApplier: LocalAutomaticClassificationApplier(
            categoryRepository: categories,
            store: DriftReviewDecisionStore(database),
            now: () => clock,
          ),
        );
        final subject = queue(processor);
        addTearDown(subject.close);

        subject.signal();
        await _waitUntil(
          () async => await jobStore.findByMediaItemId(item.id) == null,
        );

        expect(
          (await suggestions.loadByMediaItemId(item.id))?.status,
          ClassificationSuggestionStatus.autoApplied,
        );
        expect((await categories.loadRootCategories()).single.name, 'Carreira');
        expect(await categories.loadForMedia(item.id), hasLength(1));
        expect(ocrRepository.processCalls, 0);
      },
    );

    test('duas filas não reservam o mesmo job', () async {
      final item = await prepare(11);
      final processor = _SavingProcessor(suggestions);
      final first = queue(processor);
      final second = queue(processor);
      addTearDown(first.close);
      addTearDown(second.close);

      first.signal();
      second.signal();
      await _waitUntil(
        () async => await jobStore.findByMediaItemId(item.id) == null,
      );

      expect(processor.calls, 1);
    });

    test('primeira falha agenda retry sem bloquear o próximo item', () async {
      final first = await prepare(12);
      final second = await prepare(13);
      final processor = _SavingProcessor(suggestions, failures: 1);
      final subject = queue(processor);
      addTearDown(subject.close);

      subject.signal();
      await _waitUntil(() async {
        final job = await jobStore.findByMediaItemId(first.id);
        return job?.state == ClassificationJobState.retryScheduled;
      });
      await _waitUntil(
        () async => await jobStore.findByMediaItemId(second.id) == null,
      );

      final retry = await jobStore.findByMediaItemId(first.id);
      expect(retry?.attempts, 1);
      expect(
        retry?.availableAt.toUtc(),
        start.add(const Duration(seconds: 15)),
      );
      expect(retry?.lastErrorCode, ClassificationJobErrorCode.processorFailure);
      expect(await suggestions.loadByMediaItemId(second.id), isNotNull);
      expect(ocrRepository.processCalls, 0);
    });

    test('retry só fica disponível depois de availableAt', () async {
      final item = await prepare(14);
      final processor = _SavingProcessor(suggestions, failures: 1);
      final subject = queue(processor);
      addTearDown(subject.close);

      subject.signal();
      await _waitUntil(() async {
        return (await jobStore.findByMediaItemId(item.id))?.state ==
            ClassificationJobState.retryScheduled;
      });
      subject.signal();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(processor.calls, 1);

      clock = start.add(const Duration(seconds: 15));
      subject.signal();
      await _waitUntil(
        () async => await jobStore.findByMediaItemId(item.id) == null,
      );
      expect(processor.calls, 2);
    });

    test('quinta falha deixa job failed e fila segue utilizável', () async {
      final item = await prepare(15);
      final processor = _SavingProcessor(suggestions, failures: 5);
      final subject = queue(processor);
      addTearDown(subject.close);

      for (var attempt = 1; attempt <= 5; attempt++) {
        subject.signal();
        await _waitUntil(() async {
          final job = await jobStore.findByMediaItemId(item.id);
          return job?.attempts == attempt &&
              job?.state != ClassificationJobState.processing;
        });
        final job = await jobStore.findByMediaItemId(item.id);
        if (job?.state == ClassificationJobState.retryScheduled) {
          clock = job!.availableAt;
        }
      }

      final failed = await jobStore.findByMediaItemId(item.id);
      expect(failed?.state, ClassificationJobState.failed);
      expect(failed?.attempts, 5);
      expect(
        failed?.lastErrorCode,
        ClassificationJobErrorCode.processorFailure,
      );
      expect(await suggestions.loadByMediaItemId(item.id), isNull);
    });

    test('respeita tamanho máximo do lote', () async {
      await prepare(16);
      await prepare(17);
      await prepare(18);
      final processor = _SavingProcessor(suggestions);
      final subject = queue(processor, maximumBatchSize: 2);
      addTearDown(subject.close);

      subject.signal();
      await _waitUntil(() async => processor.calls == 2);

      expect(
        (await database.select(database.classificationJobs).get()).length,
        1,
      );
    });

    test('processing recente não é roubado e expirado é retomado', () async {
      final item = await prepare(19);
      final claimed = await jobStore.claimNextAvailable(
        now: clock,
        engineVersion: 1,
      );
      expect(claimed, isNotNull);
      final processor = _SavingProcessor(suggestions);
      final subject = queue(processor);
      addTearDown(subject.close);

      await subject.recoverAndStart();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(processor.calls, 0);

      clock = start
          .add(classificationProcessingExpiration)
          .add(const Duration(seconds: 1));
      await subject.recoverAndStart();
      await _waitUntil(
        () async => await jobStore.findByMediaItemId(item.id) == null,
      );
      expect(processor.calls, 1);
      expect(ocrRepository.processCalls, 0);
    });

    for (final status in [
      ClassificationSuggestionStatus.pendingReview,
      ClassificationSuggestionStatus.accepted,
      ClassificationSuggestionStatus.rejected,
      ClassificationSuggestionStatus.autoApplied,
    ]) {
      test('sugestão atual $status elimina job redundante', () async {
        final item = await prepare(30 + status.index);
        final stored = StoredClassificationSuggestion.fromEngine(
          mediaItemId: item.id,
          suggestion: ClassificationSuggestion.empty(),
          reviewReason: ClassificationReviewReason.noSuggestion,
          createdAt: start,
        ).copyWith(status: status, updatedAt: start);
        await suggestions.saveSuggestion(stored);
        if (status != ClassificationSuggestionStatus.pendingReview) {
          await suggestions.updateStatus(item.id, status);
        }
        final processor = _SavingProcessor(suggestions);
        final subject = queue(processor);
        addTearDown(subject.close);

        subject.signal();
        await _waitUntil(
          () async => await jobStore.findByMediaItemId(item.id) == null,
        );

        expect(processor.calls, 0);
        expect((await suggestions.loadByMediaItemId(item.id))?.status, status);
      });
    }

    test(
      'screenshot removido e OCR ausente descartam job com segurança',
      () async {
        final removed = await prepare(40);
        await (database.delete(
          database.mediaItems,
        )..where((row) => row.id.equals(removed.id))).go();
        mediaRepository.items.remove(removed.id);
        final withoutOcr = await _insertMedia(database, 41);
        mediaRepository.items[withoutOcr.id] = withoutOcr;
        await database
            .into(database.classificationJobs)
            .insert(
              ClassificationJobsCompanion.insert(
                mediaItemId: Value(withoutOcr.id),
                state: ClassificationJobState.pending.name,
                availableAt: clock,
                engineVersion: 1,
                createdAt: clock,
                updatedAt: clock,
              ),
            );
        final processor = _SavingProcessor(suggestions);
        final subject = queue(processor);
        addTearDown(subject.close);

        subject.signal();
        await _waitUntil(
          () async => await jobStore.findByMediaItemId(withoutOcr.id) == null,
        );

        expect(processor.calls, 0);
        expect(ocrRepository.processCalls, 0);
      },
    );
  });

  group('política e backfill', () {
    test('sequência de atrasos é determinística e limitada', () {
      const policy = ClassificationRetryPolicy();
      expect(policy.delayAfterFailure(1), const Duration(seconds: 15));
      expect(policy.delayAfterFailure(2), const Duration(minutes: 1));
      expect(policy.delayAfterFailure(3), const Duration(minutes: 5));
      expect(policy.delayAfterFailure(4), const Duration(minutes: 30));
      expect(policy.delayAfterFailure(5), isNull);
    });

    test('backfill é limitado, idempotente e preserva decisões', () async {
      final database = ContextoDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final store = DriftClassificationJobStore(database);
      final suggestions = LocalClassificationSuggestionRepository(
        DriftClassificationSuggestionStore(database),
      );
      final now = DateTime.utc(2026, 7, 19);
      final candidates = <MediaItem>[];
      for (var marker = 50; marker < 55; marker++) {
        final item = await _insertMedia(database, marker);
        candidates.add(item);
        await _saveOcr(database, item.id, now);
      }
      final withoutOcr = await _insertMedia(database, 60);
      final current = candidates[1];
      final accepted = candidates[2];
      final rejected = candidates[3];
      final autoApplied = candidates[4];
      for (final entry in [
        (current, ClassificationSuggestionStatus.pendingReview),
        (accepted, ClassificationSuggestionStatus.accepted),
        (rejected, ClassificationSuggestionStatus.rejected),
        (autoApplied, ClassificationSuggestionStatus.autoApplied),
      ]) {
        await suggestions.saveSuggestion(
          StoredClassificationSuggestion.fromEngine(
            mediaItemId: entry.$1.id,
            suggestion: ClassificationSuggestion.empty(),
            reviewReason: ClassificationReviewReason.noSuggestion,
            createdAt: now,
          ),
        );
        if (entry.$2 != ClassificationSuggestionStatus.pendingReview) {
          await suggestions.updateStatus(entry.$1.id, entry.$2);
        }
      }
      final oldVersion = await _insertMedia(database, 62);
      await _saveOcr(database, oldVersion.id, now);
      await suggestions.saveSuggestion(
        StoredClassificationSuggestion.fromEngine(
          mediaItemId: oldVersion.id,
          suggestion: ClassificationSuggestion.empty(),
          reviewReason: ClassificationReviewReason.noSuggestion,
          createdAt: now,
          engineVersion: 0,
        ),
      );

      expect(
        await store.enqueueBackfillBatch(engineVersion: 1, now: now, limit: 1),
        1,
      );
      expect(
        await store.enqueueBackfillBatch(engineVersion: 1, now: now, limit: 1),
        1,
      );
      expect(
        await store.enqueueBackfillBatch(engineVersion: 1, now: now, limit: 1),
        0,
      );
      expect(await store.findByMediaItemId(candidates.first.id), isNotNull);
      expect(await store.findByMediaItemId(oldVersion.id), isNotNull);
      expect(await store.findByMediaItemId(withoutOcr.id), isNull);
      expect(await store.findByMediaItemId(current.id), isNull);
      expect(await store.findByMediaItemId(accepted.id), isNull);
      expect(await store.findByMediaItemId(rejected.id), isNull);
      expect(await store.findByMediaItemId(autoApplied.id), isNull);
    });

    test('erro persistido usa somente código técnico controlado', () async {
      final database = ContextoDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final store = DriftClassificationJobStore(database);
      final now = DateTime.utc(2026, 7, 19);
      final item = await _insertMedia(database, 61);
      await _saveOcr(database, item.id, now);
      await store.enqueueIfNeeded(
        mediaItemId: item.id,
        engineVersion: 1,
        now: now,
      );
      final claimed = await store.claimNextAvailable(
        now: now,
        engineVersion: 1,
      );
      await store.scheduleRetry(
        job: claimed!,
        availableAt: now.add(const Duration(seconds: 15)),
        updatedAt: now,
        errorCode: ClassificationJobErrorCode.unknownFailure,
      );
      final row = await database
          .select(database.classificationJobs)
          .getSingle();
      final payload = '${row.state} ${row.lastErrorCode}';

      expect(payload, 'retryScheduled unknownFailure');
      expect(payload, isNot(contains('segredo@empresa.com')));
      expect(payload, isNot(contains('+55 81 99999-1234')));
      expect(payload, isNot(contains('https://privado.example')));
      expect(payload, isNot(contains(r'R$ 8.450,00')));
      expect(payload, isNot(contains('/dados/privados/imagem.png')));
    });
  });
}

class _SavingProcessor implements ClassificationProcessor {
  _SavingProcessor(this.repository, {this.failures = 0});

  final ClassificationSuggestionRepository repository;
  final int failures;
  int calls = 0;

  @override
  Future<StoredClassificationSuggestion> process({
    required MediaItem mediaItem,
    required OcrResult ocrResult,
  }) async {
    calls++;
    if (calls <= failures) throw StateError('falha técnica sanitizada');
    final value = StoredClassificationSuggestion.fromEngine(
      mediaItemId: mediaItem.id,
      suggestion: ClassificationSuggestion.empty(),
      reviewReason: ClassificationReviewReason.noSuggestion,
      createdAt: ocrResult.processedAt,
    );
    return repository.saveAutomaticSuggestion(
      value,
      ocrProcessedAt: ocrResult.processedAt,
    );
  }
}

class _MediaRepository implements MediaItemRepository {
  final Map<int, MediaItem> items = {};

  @override
  Future<MediaItem?> loadById(int mediaItemId) async => items[mediaItemId];

  @override
  Future<List<MediaItem>> loadAvailableItems({int? tagId}) async =>
      items.values.toList(growable: false);

  @override
  Future<ImportResult> importScreenshots(
    List<SelectedScreenshot> screenshots, {
    ImportOrigin origin = ImportOrigin.picker,
  }) async => const ImportResult(importedItems: [], duplicateCount: 0);

  @override
  Future<void> removeItem(MediaItem item) async => items.remove(item.id);

  @override
  Future<List<ScreenshotSearchResult>> searchRecognizedText(
    String query, {
    int? tagId,
    int limit = 100,
  }) async => const [];

  @override
  Future<void> close() async {}
}

class _OcrRepository implements OcrRepository {
  _OcrRepository(this.store);

  final OcrResultStore store;
  int processCalls = 0;

  @override
  Future<OcrResult?> loadFor(int mediaItemId) =>
      store.findByMediaItemId(mediaItemId);

  @override
  Future<OcrResult> process(MediaItem mediaItem) {
    processCalls++;
    throw StateError('OCR não deve ser repetido');
  }
}

Future<MediaItem> _insertMedia(ContextoDatabase database, int marker) async {
  final id = await database
      .into(database.mediaItems)
      .insert(
        MediaItemsCompanion.insert(
          privatePath: '/privado/imagem-$marker.png',
          internalName: 'imagem-$marker.png',
          mimeType: const Value('image/png'),
          importedAt: DateTime.utc(2026, 1, 1, 0, marker % 60),
          sourceMode: 'photoPicker',
          status: 'ready',
        ),
      );
  return MediaItem(
    id: id,
    privatePath: '/privado/imagem-$marker.png',
    internalName: 'imagem-$marker.png',
    mimeType: 'image/png',
    importedAt: DateTime.utc(2026, 1, 1, 0, marker % 60),
    sourceMode: 'photoPicker',
    status: 'ready',
  );
}

Future<void> _saveOcr(
  ContextoDatabase database,
  int mediaItemId,
  DateTime processedAt,
) {
  return DriftOcrResultStore(database).save(
    OcrResult(
      mediaItemId: mediaItemId,
      fullText: 'OCR sensível que não pertence ao job',
      engine: 'Teste',
      engineVersion: '1',
      processedAt: processedAt,
    ),
  );
}

Future<void> _waitUntil(Future<bool> Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condição assíncrona não foi alcançada.');
}

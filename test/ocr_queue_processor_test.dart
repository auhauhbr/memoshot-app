import 'dart:async';
import 'dart:io';

import 'package:memoshot/core/database/contexto_database.dart'
    show ContextoDatabase;
import 'package:memoshot/core/ocr/text_recognition_service.dart';
import 'package:memoshot/core/ocr/media_ocr_input.dart';
import 'package:memoshot/features/classification/application/classification_processor.dart';
import 'package:memoshot/features/classification/application/classification_queue_processor.dart';
import 'package:memoshot/features/classification/application/automatic_classification.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_repository.dart';
import 'package:memoshot/features/classification/data/classification_job_store.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_store.dart';
import 'package:memoshot/features/classification/data/review_decision_store.dart';
import 'package:memoshot/features/classification/domain/local_classification_engine.dart';
import 'package:memoshot/features/categories/data/category_repository.dart';
import 'package:memoshot/features/categories/data/category_store.dart';
import 'package:memoshot/features/classification/domain/classification_models.dart';
import 'package:memoshot/features/classification/domain/classification_job.dart';
import 'package:memoshot/features/classification/domain/stored_classification_suggestion.dart';
import 'package:memoshot/features/library/data/media_item_store.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/ocr/data/ocr_result_store.dart';
import 'package:memoshot/features/ocr/domain/ocr_result.dart';
import 'package:memoshot/features/processing/data/ocr_job_scheduler.dart';
import 'package:memoshot/features/processing/data/ocr_queue_processor.dart';
import 'package:memoshot/features/processing/data/processing_job_store.dart';
import 'package:memoshot/features/processing/domain/processing_job.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late ContextoDatabase database;
  late DriftMediaItemStore mediaStore;
  late DriftOcrResultStore resultStore;
  late DriftProcessingJobStore jobStore;
  late LocalOcrJobScheduler scheduler;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'memoshot_queue_test_',
    );
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    mediaStore = DriftMediaItemStore(database);
    resultStore = DriftOcrResultStore(database);
    jobStore = DriftProcessingJobStore(database);
    scheduler = LocalOcrJobScheduler(jobStore);
  });

  tearDown(() async {
    await database.close();
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('cria e consulta um único job OCR ativo por item', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 1);

    expect(await scheduler.schedule(item.id), isTrue);
    expect(await scheduler.schedule(item.id), isFalse);

    final job = await jobStore.findOcrJob(item.id);
    expect(job?.status, ProcessingJobStatus.pending);
    expect(job?.attempts, 0);
  });

  test('não cria job quando o item já possui resultado OCR', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 14);
    await resultStore.save(createOcrResult(item.id, 'Já processado'));

    expect(await scheduler.schedule(item.id), isFalse);
    expect(await jobStore.findOcrJob(item.id), isNull);
  });

  test('recupera job interrompido como pending de forma idempotente', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 2);
    await scheduler.schedule(item.id);
    final claimed = await jobStore.claimNextPendingOcr();
    expect(claimed?.status, ProcessingJobStatus.processing);

    expect(await jobStore.recoverInterruptedOcrJobs(), [item.id]);
    expect(
      (await jobStore.findOcrJob(item.id))?.status,
      ProcessingJobStatus.pending,
    );
    expect(await jobStore.recoverInterruptedOcrJobs(), isEmpty);
  });

  test('somente um processador reivindica o mesmo job', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 15);
    await scheduler.schedule(item.id);

    final claims = await Future.wait([
      jobStore.claimNextPendingOcr(),
      jobStore.claimNextPendingOcr(),
    ]);

    expect(claims.whereType<ProcessingJob>(), hasLength(1));
  });

  test('inicialização recupera e processa job interrompido', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 13);
    await scheduler.schedule(item.id);
    await jobStore.claimNextPendingOcr();
    final service = FakeRecognitionService(texts: ['Retomado']);
    final queue = createQueue(
      jobStore,
      resultStore,
      service,
      processingExpiration: Duration.zero,
    );
    addTearDown(queue.close);

    await queue.recoverAndStart();
    await waitForState(queue, item.id, OcrItemState.completedWithText);

    expect(service.callCount, 1);
    expect(
      (await resultStore.findByMediaItemId(item.id))?.fullText,
      'Retomado',
    );
  });

  test('recuperação não rouba OCR processing recente', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 64);
    await scheduler.schedule(item.id);
    await jobStore.claimNextPendingOcr();
    final queue = createQueue(
      jobStore,
      resultStore,
      FakeRecognitionService(texts: ['não deve executar']),
    );
    addTearDown(queue.close);

    expect(await queue.recoverInterrupted(), 0);
    expect(
      (await jobStore.findOcrJob(item.id))?.status,
      ProcessingJobStatus.processing,
    );
  });

  test('remover media_item também remove seu job', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 3);
    await scheduler.schedule(item.id);

    await mediaStore.deleteItem(item.id);

    expect(await jobStore.findOcrJob(item.id), isNull);
  });

  test('processa vários jobs sequencialmente e salva os resultados', () async {
    final first = await createMediaItem(mediaStore, temporaryDirectory, 4);
    final second = await createMediaItem(mediaStore, temporaryDirectory, 5);
    await scheduler.schedule(first.id);
    await scheduler.schedule(second.id);
    final service = FakeRecognitionService(texts: ['Primeiro', 'Segundo']);
    final queue = createQueue(jobStore, resultStore, service);
    addTearDown(queue.close);

    queue.signal();
    await waitForState(queue, first.id, OcrItemState.completedWithText);
    await waitForState(queue, second.id, OcrItemState.completedWithText);

    expect(
      (await resultStore.findByMediaItemId(first.id))?.fullText,
      'Primeiro',
    );
    expect(
      (await resultStore.findByMediaItemId(second.id))?.fullText,
      'Segundo',
    );
    expect(service.callCount, 2);
    expect(service.maxConcurrentCalls, 1);
  });

  test('resultado vazio conclui o job como sem texto', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 6);
    await scheduler.schedule(item.id);
    final queue = createQueue(
      jobStore,
      resultStore,
      FakeRecognitionService(texts: ['']),
    );
    addTearDown(queue.close);

    queue.signal();
    await waitForState(queue, item.id, OcrItemState.completedWithoutText);

    expect(await resultStore.findByMediaItemId(item.id), isNotNull);
    expect((await resultStore.findByMediaItemId(item.id))?.fullText, isEmpty);
  });

  test('classifica uma vez e somente depois de persistir o OCR', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 16);
    await scheduler.schedule(item.id);
    final classification = FakeClassificationProcessor(
      onProcess: (mediaItem, ocrResult) async {
        expect(
          (await resultStore.findByMediaItemId(mediaItem.id))?.fullText,
          ocrResult.fullText,
        );
      },
    );
    final queue = createQueue(
      jobStore,
      resultStore,
      FakeRecognitionService(texts: ['Vaga entrevista']),
      classificationProcessor: classification,
    );
    addTearDown(queue.close);

    queue.signal();
    await waitForState(queue, item.id, OcrItemState.completedWithText);

    expect(classification.calls, 1);
  });

  test('OCR persistido cria job durável antes de concluir', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 62);
    await scheduler.schedule(item.id);
    final classificationJobs = DriftClassificationJobStore(database);
    final classificationScheduler = LocalClassificationJobScheduler(
      store: classificationJobs,
      engineVersion: currentClassificationEngineVersion,
      now: () => DateTime.utc(2026, 7, 19),
    );
    final recognition = FakeRecognitionService(texts: ['Texto persistido']);
    final queue = LocalOcrQueueProcessor(
      jobStore: jobStore,
      resultStore: resultStore,
      recognitionService: recognition,
      inputResolver: _privateInputResolver(),
      classificationJobScheduler: classificationScheduler,
    );
    addTearDown(queue.close);

    queue.signal();
    await waitForState(queue, item.id, OcrItemState.completedWithText);

    expect(
      (await classificationJobs.findByMediaItemId(item.id))?.state,
      ClassificationJobState.pending,
    );
    expect(recognition.callCount, 1);
    queue.signal();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(recognition.callCount, 1);
  });

  test(
    'falha ao enfileirar classificação mantém OCR recuperável sem reconhecê-lo de novo',
    () async {
      final item = await createMediaItem(mediaStore, temporaryDirectory, 63);
      await scheduler.schedule(item.id);
      final classificationJobs = DriftClassificationJobStore(database);
      final classificationScheduler = LocalClassificationJobScheduler(
        store: classificationJobs,
        engineVersion: currentClassificationEngineVersion,
        now: () => DateTime.utc(2026, 7, 19),
      );
      final failingScheduler = _FailingOnceClassificationScheduler(
        classificationScheduler,
      );
      final recognition = FakeRecognitionService(texts: ['Texto persistido']);
      final firstQueue = LocalOcrQueueProcessor(
        jobStore: jobStore,
        resultStore: resultStore,
        recognitionService: recognition,
        inputResolver: _privateInputResolver(),
        classificationJobScheduler: failingScheduler,
      );

      firstQueue.signal();
      await waitForResult(resultStore, item.id, 'Texto persistido');
      await firstQueue.close();

      expect(
        (await jobStore.findOcrJob(item.id))?.status,
        ProcessingJobStatus.processing,
      );
      expect(await classificationJobs.findByMediaItemId(item.id), isNull);

      final resumedQueue = LocalOcrQueueProcessor(
        jobStore: jobStore,
        resultStore: resultStore,
        recognitionService: recognition,
        inputResolver: _privateInputResolver(),
        classificationJobScheduler: classificationScheduler,
        processingExpiration: Duration.zero,
      );
      addTearDown(resumedQueue.close);

      await resumedQueue.recoverAndStart();
      await waitForState(resumedQueue, item.id, OcrItemState.completedWithText);

      expect(
        (await classificationJobs.findByMediaItemId(item.id))?.state,
        ClassificationJobState.pending,
      );
      expect(recognition.callCount, 1);
    },
  );

  test(
    'origens manual, compartilhada e automática convergem para classificação',
    () async {
      final items = <MediaItem>[];
      var marker = 20;
      for (final origin in ImportOrigin.values) {
        final item = await createMediaItem(
          mediaStore,
          temporaryDirectory,
          marker++,
          origin: origin,
        );
        items.add(item);
        await scheduler.schedule(item.id);
      }
      final classification = FakeClassificationProcessor();
      final queue = createQueue(
        jobStore,
        resultStore,
        FakeRecognitionService(
          texts: ['Manual', 'Compartilhada', 'Automática'],
        ),
        classificationProcessor: classification,
      );
      addTearDown(queue.close);

      queue.signal();
      for (final item in items) {
        await waitForState(queue, item.id, OcrItemState.completedWithText);
      }

      expect(classification.mediaItemIds, items.map((item) => item.id));
      expect(classification.calls, 3);
    },
  );

  test('falha marca job como failed sem criar resultado falso', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 7);
    await scheduler.schedule(item.id);
    final queue = createQueue(
      jobStore,
      resultStore,
      FakeRecognitionService(error: StateError('conteúdo privado')),
    );
    addTearDown(queue.close);

    queue.signal();
    await waitForState(queue, item.id, OcrItemState.failed);

    expect(await resultStore.findByMediaItemId(item.id), isNull);
    expect((await jobStore.findOcrJob(item.id))?.errorCode, 'ocr_failed');
  });

  test('falha no OCR não executa classificação', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 17);
    await scheduler.schedule(item.id);
    final classification = FakeClassificationProcessor();
    final queue = createQueue(
      jobStore,
      resultStore,
      FakeRecognitionService(error: StateError('conteúdo privado')),
      classificationProcessor: classification,
    );
    addTearDown(queue.close);

    queue.signal();
    await waitForState(queue, item.id, OcrItemState.failed);

    expect(classification.calls, 0);
  });

  test(
    'falha na classificação preserva OCR e não bloqueia próximo item',
    () async {
      final first = await createMediaItem(mediaStore, temporaryDirectory, 18);
      final second = await createMediaItem(mediaStore, temporaryDirectory, 19);
      await scheduler.schedule(first.id);
      await scheduler.schedule(second.id);
      final classification = FakeClassificationProcessor(failFirst: true);
      final queue = createQueue(
        jobStore,
        resultStore,
        FakeRecognitionService(texts: ['Primeiro privado', 'Segundo privado']),
        classificationProcessor: classification,
      );
      addTearDown(queue.close);

      queue.signal();
      await waitForState(queue, first.id, OcrItemState.completedWithText);
      await waitForState(queue, second.id, OcrItemState.completedWithText);

      expect(await resultStore.findByMediaItemId(first.id), isNotNull);
      expect(await resultStore.findByMediaItemId(second.id), isNotNull);
      expect(classification.calls, 2);
    },
  );

  test(
    'resultado existente impede processamento automático desnecessário',
    () async {
      final item = await createMediaItem(mediaStore, temporaryDirectory, 8);
      await scheduler.schedule(item.id);
      await resultStore.save(createOcrResult(item.id, 'Persistido'));
      final service = FakeRecognitionService(texts: ['não deve executar']);
      final queue = createQueue(jobStore, resultStore, service);
      addTearDown(queue.close);

      queue.signal();
      await waitForState(queue, item.id, OcrItemState.completedWithText);

      expect(service.callCount, 0);
      expect(
        (await resultStore.findByMediaItemId(item.id))?.fullText,
        'Persistido',
      );
    },
  );

  test(
    'retomada classifica OCR já persistido sem reconhecê-lo novamente',
    () async {
      final item = await createMediaItem(mediaStore, temporaryDirectory, 31);
      await scheduler.schedule(item.id);
      await resultStore.save(
        createOcrResult(item.id, 'Persistido antes da pausa'),
      );
      final service = FakeRecognitionService(texts: ['não deve executar']);
      final classification = FakeClassificationProcessor();
      final queue = createQueue(
        jobStore,
        resultStore,
        service,
        classificationProcessor: classification,
      );
      addTearDown(queue.close);

      queue.signal();
      await waitForState(queue, item.id, OcrItemState.completedWithText);

      expect(service.callCount, 0);
      expect(classification.calls, 1);
    },
  );

  test('dois disparos não executam o mesmo job duas vezes', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 9);
    await scheduler.schedule(item.id);
    final service = FakeRecognitionService(texts: ['Único']);
    final queue = createQueue(jobStore, resultStore, service);
    addTearDown(queue.close);

    queue
      ..signal()
      ..signal();
    await waitForState(queue, item.id, OcrItemState.completedWithText);

    expect(service.callCount, 1);
  });

  test('arquivo ausente resulta em falha controlada', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 10);
    File(item.privatePath!).deleteSync();
    await scheduler.schedule(item.id);
    final service = FakeRecognitionService(texts: ['não deve executar']);
    final queue = createQueue(jobStore, resultStore, service);
    addTearDown(queue.close);

    queue.signal();
    await waitForState(queue, item.id, OcrItemState.failed);

    expect(service.callCount, 0);
    expect((await jobStore.findOcrJob(item.id))?.errorCode, 'file_unavailable');
  });

  test(
    'referência MediaStore usa temporário, persiste OCR e agenda classificação',
    () async {
      final temporary = File('${temporaryDirectory.path}/ocr-temporary.png')
        ..writeAsBytesSync([9, 8, 7]);
      final item = await createReferencedMediaItem(mediaStore, 70);
      await scheduler.schedule(item.id);
      final bridge = _QueueMediaStoreOcrBridge(temporary.path);
      final recognition = FakeRecognitionService(texts: ['Texto referenciado']);
      final classificationJobs = DriftClassificationJobStore(database);
      final queue = LocalOcrQueueProcessor(
        jobStore: jobStore,
        resultStore: resultStore,
        recognitionService: recognition,
        inputResolver: LocalMediaOcrInputResolver(bridge),
        classificationJobScheduler: LocalClassificationJobScheduler(
          store: classificationJobs,
          engineVersion: currentClassificationEngineVersion,
          now: () => DateTime.utc(2026, 7, 19),
        ),
      );
      addTearDown(queue.close);

      queue.signal();
      await waitForState(queue, item.id, OcrItemState.completedWithText);

      final stored = await jobStore.findMediaItem(item.id);
      expect(recognition.paths, [temporary.path]);
      expect(bridge.releasedTokens, ['token-1']);
      expect(
        (await resultStore.findByMediaItemId(item.id))?.fullText,
        'Texto referenciado',
      );
      expect(
        (await jobStore.findOcrJob(item.id))?.status,
        ProcessingJobStatus.completed,
      );
      expect(await classificationJobs.findByMediaItemId(item.id), isNotNull);
      expect(stored?.privatePath, isNull);
      expect(stored?.mediaHash, isNull);
      expect(stored?.sourceKey, 'external_primary:70');
    },
  );

  test('falha do ML Kit ainda libera temporário referenciado', () async {
    final item = await createReferencedMediaItem(mediaStore, 71);
    await scheduler.schedule(item.id);
    final bridge = _QueueMediaStoreOcrBridge(
      '${temporaryDirectory.path}/ml-kit-failure.png',
    );
    final queue = LocalOcrQueueProcessor(
      jobStore: jobStore,
      resultStore: resultStore,
      recognitionService: FakeRecognitionService(error: StateError('falha')),
      inputResolver: LocalMediaOcrInputResolver(bridge),
    );
    addTearDown(queue.close);

    queue.signal();
    await waitForState(queue, item.id, OcrItemState.failed);

    expect(bridge.releasedTokens, ['token-1']);
    expect((await jobStore.findOcrJob(item.id))?.errorCode, 'ocr_failed');
  });

  test('falha ao persistir OCR ainda libera temporário referenciado', () async {
    final item = await createReferencedMediaItem(mediaStore, 72);
    await scheduler.schedule(item.id);
    final bridge = _QueueMediaStoreOcrBridge(
      '${temporaryDirectory.path}/persistence-failure.png',
    );
    final queue = LocalOcrQueueProcessor(
      jobStore: jobStore,
      resultStore: _FailingSaveOcrResultStore(resultStore),
      recognitionService: FakeRecognitionService(texts: ['não persiste']),
      inputResolver: LocalMediaOcrInputResolver(bridge),
    );
    addTearDown(queue.close);

    queue.signal();
    await waitForState(queue, item.id, OcrItemState.failed);

    expect(bridge.releasedTokens, ['token-1']);
    expect((await jobStore.findOcrJob(item.id))?.errorCode, 'ocr_failed');
    expect(await resultStore.findByMediaItemId(item.id), isNull);
  });

  for (final code in <String>[
    MediaOcrInputFailureCode.referencedSourceUnavailable,
    MediaOcrInputFailureCode.referencedSourcePermissionDenied,
    MediaOcrInputFailureCode.referencedSourceTooLarge,
    MediaOcrInputFailureCode.referencedSourceInvalid,
    MediaOcrInputFailureCode.unsupportedReferencedMimeType,
    MediaOcrInputFailureCode.referencedSourceTemporaryFailure,
    MediaOcrInputFailureCode.temporaryFileFailure,
  ]) {
    test('falha controlada do resolver persiste somente $code', () async {
      final marker = 80 + code.length;
      final item = await createReferencedMediaItem(mediaStore, marker);
      await scheduler.schedule(item.id);
      final queue = LocalOcrQueueProcessor(
        jobStore: jobStore,
        resultStore: resultStore,
        recognitionService: FakeRecognitionService(texts: ['não executa']),
        inputResolver: _FailingMediaOcrInputResolver(code),
      );
      addTearDown(queue.close);

      queue.signal();
      await waitForState(queue, item.id, OcrItemState.failed);

      expect((await jobStore.findOcrJob(item.id))?.errorCode, code);
      expect(await resultStore.findByMediaItemId(item.id), isNull);
    });
  }

  test('nova tentativa substitui resultado anterior', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 11);
    await scheduler.schedule(item.id);
    await resultStore.save(createOcrResult(item.id, 'Anterior'));
    final service = FakeRecognitionService(texts: ['Atualizado']);
    final queue = createQueue(jobStore, resultStore, service);
    addTearDown(queue.close);
    queue.signal();
    await waitForState(queue, item.id, OcrItemState.completedWithText);

    await queue.retry(item);
    await waitForResult(resultStore, item.id, 'Atualizado');

    expect(service.callCount, 1);
    expect(
      (await resultStore.findByMediaItemId(item.id))?.fullText,
      'Atualizado',
    );
  });

  test('remoção durante processamento não recria item nem resultado', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 12);
    await scheduler.schedule(item.id);
    final completer = Completer<TextRecognitionOutput>();
    final service = FakeRecognitionService(completer: completer);
    final queue = createQueue(jobStore, resultStore, service);
    addTearDown(queue.close);
    queue.signal();
    await waitForState(queue, item.id, OcrItemState.processing);

    await mediaStore.deleteItem(item.id);
    completer.complete(output('Tardio'));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(await jobStore.findMediaItem(item.id), isNull);
    expect(await jobStore.findOcrJob(item.id), isNull);
    expect(await resultStore.findByMediaItemId(item.id), isNull);
  });

  test(
    'remoção antes de persistir classificação é tratada com segurança',
    () async {
      final item = await createMediaItem(mediaStore, temporaryDirectory, 30);
      await scheduler.schedule(item.id);
      final classification = FakeClassificationProcessor(
        onProcess: (mediaItem, _) => mediaStore.deleteItem(mediaItem.id),
      );
      final queue = createQueue(
        jobStore,
        resultStore,
        FakeRecognitionService(texts: ['Texto concluído']),
        classificationProcessor: classification,
      );
      addTearDown(queue.close);

      queue.signal();
      for (
        var attempt = 0;
        attempt < 100 && classification.calls == 0;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(classification.calls, 1);
      expect(await jobStore.findMediaItem(item.id), isNull);
      expect(await jobStore.findOcrJob(item.id), isNull);
      expect(await resultStore.findByMediaItemId(item.id), isNull);
    },
  );

  test('OCR forte aplica pasta existente e sai da revisão', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 40);
    await scheduler.schedule(item.id);
    final categories = LocalCategoryRepository(
      store: DriftCategoryStore(database),
    );
    final career = await categories.createRootCategory('Carreira');
    final suggestions = LocalClassificationSuggestionRepository(
      DriftClassificationSuggestionStore(database),
    );
    final classification = LocalClassificationProcessor(
      engine: const LocalClassificationEngine(),
      repository: suggestions,
      now: () => DateTime.utc(2026, 7, 18, 12),
      engineVersion: 1,
      automaticApplier: LocalAutomaticClassificationApplier(
        categoryRepository: categories,
        store: DriftReviewDecisionStore(database),
        now: () => DateTime.utc(2026, 7, 18, 12, 1),
      ),
    );
    final queue = createQueue(
      jobStore,
      resultStore,
      FakeRecognitionService(
        texts: [
          'vaga entrevista recrutadora currículo candidatura processo seletivo urgente',
        ],
      ),
      classificationProcessor: classification,
    );
    addTearDown(queue.close);

    queue.signal();
    await waitForState(queue, item.id, OcrItemState.completedWithText);

    final stored = await suggestions.loadByMediaItemId(item.id);
    expect(stored?.status, ClassificationSuggestionStatus.autoApplied);
    expect(stored?.resolvedAt, isNotNull);
    expect((await categories.loadForMedia(item.id)).map((item) => item.id), [
      career.id,
    ]);
    expect(await suggestions.countPendingReview(), 0);
  });

  test('OCR fraco fica pendente e OCR forte cria pasta segura ausente', () async {
    final weak = await createMediaItem(mediaStore, temporaryDirectory, 41);
    final noFolder = await createMediaItem(mediaStore, temporaryDirectory, 42);
    await scheduler.schedule(weak.id);
    await scheduler.schedule(noFolder.id);
    final categories = LocalCategoryRepository(
      store: DriftCategoryStore(database),
    );
    final suggestions = LocalClassificationSuggestionRepository(
      DriftClassificationSuggestionStore(database),
    );
    final classification = LocalClassificationProcessor(
      engine: const LocalClassificationEngine(),
      repository: suggestions,
      now: () => DateTime.utc(2026, 7, 18, 12),
      engineVersion: 1,
      automaticApplier: LocalAutomaticClassificationApplier(
        categoryRepository: categories,
        store: DriftReviewDecisionStore(database),
      ),
    );
    final queue = createQueue(
      jobStore,
      resultStore,
      FakeRecognitionService(
        texts: [
          'vaga',
          'vaga entrevista recrutadora currículo candidatura processo seletivo',
        ],
      ),
      classificationProcessor: classification,
    );
    addTearDown(queue.close);

    queue.signal();
    await waitForState(queue, weak.id, OcrItemState.completedWithText);
    await waitForState(queue, noFolder.id, OcrItemState.completedWithText);

    expect(
      (await suggestions.loadByMediaItemId(weak.id))?.status,
      ClassificationSuggestionStatus.pendingReview,
    );
    expect(
      (await suggestions.loadByMediaItemId(noFolder.id))?.status,
      ClassificationSuggestionStatus.autoApplied,
    );
    expect(await suggestions.countPendingReview(), 1);
    final roots = await categories.loadRootCategories();
    expect(roots, hasLength(1));
    expect(roots.single.name, 'Carreira');
    expect(roots.single.parentId, isNull);
    expect(
      (await categories.loadForMedia(noFolder.id)).map((item) => item.id),
      [roots.single.id],
    );
  });
}

LocalOcrQueueProcessor createQueue(
  ProcessingJobStore jobStore,
  OcrResultStore resultStore,
  TextRecognitionService service, {
  ClassificationProcessor? classificationProcessor,
  Duration processingExpiration = ocrProcessingExpiration,
}) {
  final bridge = classificationProcessor == null
      ? null
      : _InlineClassificationBridge(
          jobStore,
          resultStore,
          classificationProcessor,
        );
  return LocalOcrQueueProcessor(
    jobStore: jobStore,
    resultStore: resultStore,
    recognitionService: service,
    inputResolver: _privateInputResolver(),
    classificationJobScheduler: bridge,
    classificationQueue: bridge,
    processingExpiration: processingExpiration,
  );
}

MediaOcrInputResolver _privateInputResolver() =>
    LocalMediaOcrInputResolver(_UnexpectedMediaStoreOcrBridge());

class _UnexpectedMediaStoreOcrBridge implements MediaStoreOcrInputBridge {
  @override
  Future<ReferencedOcrInput> prepare(MediaStoreReferenceLocation location) =>
      throw StateError('Referência inesperada neste teste.');

  @override
  Future<void> release(String token) async {}
}

Future<void> waitForState(
  OcrQueue queue,
  int mediaItemId,
  OcrItemState expected,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (await queue.loadState(mediaItemId) == expected) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Estado OCR esperado não foi alcançado.');
}

Future<void> waitForResult(
  OcrResultStore store,
  int mediaItemId,
  String expected,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if ((await store.findByMediaItemId(mediaItemId))?.fullText == expected) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Resultado OCR esperado não foi salvo.');
}

class FakeRecognitionService implements TextRecognitionService {
  FakeRecognitionService({this.texts = const [], this.error, this.completer});

  final List<String> texts;
  final Object? error;
  final Completer<TextRecognitionOutput>? completer;
  int callCount = 0;
  int concurrentCalls = 0;
  int maxConcurrentCalls = 0;
  final List<String> paths = [];

  @override
  Future<TextRecognitionOutput> recognize(String imagePath) async {
    paths.add(imagePath);
    final index = callCount++;
    concurrentCalls++;
    if (concurrentCalls > maxConcurrentCalls) {
      maxConcurrentCalls = concurrentCalls;
    }
    try {
      if (error != null) {
        throw error!;
      }
      if (completer != null) {
        return await completer!.future;
      }
      await Future<void>.delayed(Duration.zero);
      return output(texts[index]);
    } finally {
      concurrentCalls--;
    }
  }
}

class _QueueMediaStoreOcrBridge implements MediaStoreOcrInputBridge {
  _QueueMediaStoreOcrBridge(this.path);

  final String path;
  int prepareCount = 0;
  final List<String> releasedTokens = [];

  @override
  Future<ReferencedOcrInput> prepare(
    MediaStoreReferenceLocation location,
  ) async {
    prepareCount++;
    return ReferencedOcrInput(localPath: path, token: 'token-$prepareCount');
  }

  @override
  Future<void> release(String token) async => releasedTokens.add(token);
}

class _FailingMediaOcrInputResolver implements MediaOcrInputResolver {
  _FailingMediaOcrInputResolver(this.code);

  final String code;

  @override
  Future<OcrInputLease> resolve(MediaItem mediaItem) =>
      Future<OcrInputLease>.error(MediaOcrInputException(code));

  @override
  Future<void> close() async {}
}

class _FailingSaveOcrResultStore implements OcrResultStore {
  _FailingSaveOcrResultStore(this.delegate);

  final OcrResultStore delegate;

  @override
  Future<OcrResult?> findByMediaItemId(int mediaItemId) =>
      delegate.findByMediaItemId(mediaItemId);

  @override
  Future<void> save(OcrResult result) =>
      Future<void>.error(StateError('falha de persistência'));
}

class FakeClassificationProcessor implements ClassificationProcessor {
  FakeClassificationProcessor({this.onProcess, this.failFirst = false});

  final Future<void> Function(MediaItem, OcrResult)? onProcess;
  final bool failFirst;
  int calls = 0;
  final List<int> mediaItemIds = [];

  @override
  Future<StoredClassificationSuggestion> process({
    required MediaItem mediaItem,
    required OcrResult ocrResult,
  }) async {
    calls++;
    mediaItemIds.add(mediaItem.id);
    await onProcess?.call(mediaItem, ocrResult);
    if (failFirst && calls == 1) throw StateError('falha técnica sanitizada');
    return StoredClassificationSuggestion.fromEngine(
      mediaItemId: mediaItem.id,
      suggestion: ClassificationSuggestion.empty(),
      reviewReason: ClassificationReviewReason.noSuggestion,
      createdAt: DateTime(2026),
    );
  }
}

class _InlineClassificationBridge
    implements ClassificationJobScheduler, ClassificationQueue {
  _InlineClassificationBridge(
    this._jobStore,
    this._resultStore,
    this._processor,
  );

  final ProcessingJobStore _jobStore;
  final OcrResultStore _resultStore;
  final ClassificationProcessor _processor;

  @override
  Stream<int> get changes => const Stream.empty();

  @override
  Future<bool> schedule(int mediaItemId) async {
    final mediaItem = await _jobStore.findMediaItem(mediaItemId);
    final ocrResult = await _resultStore.findByMediaItemId(mediaItemId);
    if (mediaItem == null || ocrResult == null) return false;
    try {
      await _processor.process(mediaItem: mediaItem, ocrResult: ocrResult);
    } catch (_) {
      // Ponte exclusiva dos testes legados: em produção o scheduler apenas
      // persiste o job e a fila de classificação isola esta falha.
    }
    return true;
  }

  @override
  Future<void> recoverAndStart() async {}

  @override
  void signal() {}

  @override
  Future<void> close() async {}
}

class _FailingOnceClassificationScheduler
    implements ClassificationJobScheduler {
  _FailingOnceClassificationScheduler(this._delegate);

  final ClassificationJobScheduler _delegate;
  var _failed = false;

  @override
  Future<bool> schedule(int mediaItemId) {
    if (!_failed) {
      _failed = true;
      throw StateError('falha técnica controlada');
    }
    return _delegate.schedule(mediaItemId);
  }
}

TextRecognitionOutput output(String text) {
  return TextRecognitionOutput(
    fullText: text,
    engine: 'Serviço falso',
    engineVersion: 'teste',
  );
}

OcrResult createOcrResult(int mediaItemId, String text) {
  return OcrResult(
    mediaItemId: mediaItemId,
    fullText: text,
    engine: 'Serviço falso',
    engineVersion: 'teste',
    processedAt: DateTime(2026),
  );
}

Future<MediaItem> createMediaItem(
  DriftMediaItemStore store,
  Directory directory,
  int marker, {
  ImportOrigin origin = ImportOrigin.picker,
}) async {
  final file = File('${directory.path}/imagem-$marker.png')
    ..writeAsBytesSync([1, 2, marker]);
  final id = await store.insertItem(
    privatePath: file.path,
    internalName: 'imagem-$marker.png',
    mimeType: 'image/png',
    mediaHash: 'hash-$marker',
    importedAt: DateTime(2026, 1, 1, 0, marker),
    sourceMode: 'photoPicker',
    status: 'ready',
    importOrigin: origin,
  );
  return MediaItem(
    id: id,
    privatePath: file.path,
    internalName: 'imagem-$marker.png',
    mimeType: 'image/png',
    mediaHash: 'hash-$marker',
    importedAt: DateTime(2026, 1, 1, 0, marker),
    sourceMode: 'photoPicker',
    status: 'ready',
    importOrigin: origin,
  );
}

Future<MediaItem> createReferencedMediaItem(
  DriftMediaItemStore store,
  int marker,
) async {
  final location = MediaStoreReferenceLocation(
    sourceKey: 'external_primary:$marker',
    mediaStoreId: marker,
    volumeName: 'external_primary',
    contentUri: 'content://media/external_primary/images/media/$marker',
  );
  final id = await store.insertMediaStoreReference(
    location: location,
    mimeType: 'image/png',
    importedAt: DateTime(2026, 1, 1),
    capturedAt: DateTime(2025, 12, 31),
    sourceMode: 'mediaStoreReference',
    status: 'ready',
  );
  return (await store.findById(id))!;
}

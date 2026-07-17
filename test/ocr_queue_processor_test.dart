import 'dart:async';
import 'dart:io';

import 'package:contexto/core/database/contexto_database.dart'
    show ContextoDatabase;
import 'package:contexto/core/ocr/text_recognition_service.dart';
import 'package:contexto/features/library/data/media_item_store.dart';
import 'package:contexto/features/library/domain/media_item.dart';
import 'package:contexto/features/ocr/data/ocr_result_store.dart';
import 'package:contexto/features/ocr/domain/ocr_result.dart';
import 'package:contexto/features/processing/data/ocr_job_scheduler.dart';
import 'package:contexto/features/processing/data/ocr_queue_processor.dart';
import 'package:contexto/features/processing/data/processing_job_store.dart';
import 'package:contexto/features/processing/domain/processing_job.dart';
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
      'contexto_queue_test_',
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
    final queue = createQueue(jobStore, resultStore, service);
    addTearDown(queue.close);

    await queue.recoverAndStart();
    await waitForState(queue, item.id, OcrItemState.completedWithText);

    expect(service.callCount, 1);
    expect(
      (await resultStore.findByMediaItemId(item.id))?.fullText,
      'Retomado',
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
    File(item.privatePath).deleteSync();
    await scheduler.schedule(item.id);
    final service = FakeRecognitionService(texts: ['não deve executar']);
    final queue = createQueue(jobStore, resultStore, service);
    addTearDown(queue.close);

    queue.signal();
    await waitForState(queue, item.id, OcrItemState.failed);

    expect(service.callCount, 0);
    expect((await jobStore.findOcrJob(item.id))?.errorCode, 'file_unavailable');
  });

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
}

LocalOcrQueueProcessor createQueue(
  ProcessingJobStore jobStore,
  OcrResultStore resultStore,
  TextRecognitionService service,
) {
  return LocalOcrQueueProcessor(
    jobStore: jobStore,
    resultStore: resultStore,
    recognitionService: service,
  );
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

  @override
  Future<TextRecognitionOutput> recognize(String imagePath) async {
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
  int marker,
) async {
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
  );
}

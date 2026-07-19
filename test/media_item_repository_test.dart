import 'dart:convert';
import 'dart:io';

import 'package:memoshot/core/database/contexto_database.dart'
    show
        ClassificationSuggestionsCompanion,
        ContextoDatabase,
        MediaTagsCompanion,
        OcrResultsCompanion,
        TagsCompanion;
import 'package:memoshot/core/media/file_hash_calculator.dart';
import 'package:memoshot/core/media/screenshot_storage.dart';
import 'package:memoshot/features/library/data/media_item_repository.dart';
import 'package:memoshot/features/library/data/media_item_store.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/library/domain/selected_screenshot.dart';
import 'package:memoshot/features/ocr/data/ocr_result_store.dart';
import 'package:memoshot/features/ocr/domain/ocr_result.dart';
import 'package:memoshot/features/processing/data/ocr_job_scheduler.dart';
import 'package:memoshot/features/processing/data/processing_job_store.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late Directory privateDirectory;
  late ContextoDatabase database;
  late DriftMediaItemStore store;
  late PrivateScreenshotStorage storage;
  late LocalMediaItemRepository repository;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'memoshot_repository_test_',
    );
    privateDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}private',
    )..createSync();
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    store = DriftMediaItemStore(database);
    storage = PrivateScreenshotStorage(
      documentsDirectory: () async => privateDirectory,
    );
    repository = LocalMediaItemRepository(store: store, storage: storage);
  });

  tearDown(() async {
    await repository.close();
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('grava e lê um item persistido', () async {
    final original = createTestImage(temporaryDirectory, 'original.png');

    final imported = await repository.importScreenshots([
      SelectedScreenshot(path: original.path, mimeType: 'image/png'),
    ]);
    final loaded = await repository.loadAvailableItems();

    expect(imported.importedItems, hasLength(1));
    expect(loaded, hasLength(1));
    expect(loaded.single.id, imported.importedItems.single.id);
    expect(loaded.single.sourceMode, 'photoPicker');
    expect(loaded.single.importOrigin, ImportOrigin.picker);
    expect(loaded.single.status, 'ready');
    expect(loaded.single.mimeType, 'image/png');
    expect(File(loaded.single.privatePath!).existsSync(), isTrue);
  });

  test('imagem compartilhada persiste origem shared e cria job OCR', () async {
    final jobStore = DriftProcessingJobStore(database);
    repository = LocalMediaItemRepository(
      store: store,
      storage: storage,
      ocrJobScheduler: LocalOcrJobScheduler(jobStore),
    );
    final original = createTestImage(temporaryDirectory, 'shared.png');

    final result = await repository.importScreenshots([
      SelectedScreenshot(path: original.path, mimeType: 'image/png'),
    ], origin: ImportOrigin.shared);
    final item = result.importedItems.single;

    expect(item.importOrigin, ImportOrigin.shared);
    expect(
      (await repository.loadAvailableItems()).single.importOrigin,
      ImportOrigin.shared,
    );
    expect(await jobStore.findOcrJob(item.id), isNotNull);
    expect(original.existsSync(), isTrue);
  });

  test('imagem automática persiste origem e cria somente um job OCR', () async {
    final jobStore = DriftProcessingJobStore(database);
    repository = LocalMediaItemRepository(
      store: store,
      storage: storage,
      ocrJobScheduler: LocalOcrJobScheduler(jobStore),
    );
    final original = createTestImage(temporaryDirectory, 'automatic.png');

    final first = await repository.importScreenshots([
      SelectedScreenshot(path: original.path, mimeType: 'image/png'),
    ], origin: ImportOrigin.automatic);
    final duplicate = await repository.importScreenshots([
      SelectedScreenshot(path: original.path, mimeType: 'image/png'),
    ], origin: ImportOrigin.automatic);

    expect(first.importedItems.single.importOrigin, ImportOrigin.automatic);
    expect(duplicate.duplicateCount, 1);
    expect(await database.select(database.mediaItems).get(), hasLength(1));
    expect(await database.select(database.processingJobs).get(), hasLength(1));
    expect(privateCopies(privateDirectory), hasLength(1));
    expect(original.existsSync(), isTrue);
  });

  test('persiste múltiplos itens', () async {
    final first = createTestImage(temporaryDirectory, 'primeira.png');
    final second = createTestImage(temporaryDirectory, 'segunda.png', 1);

    await repository.importScreenshots([
      SelectedScreenshot(path: first.path),
      SelectedScreenshot(path: second.path),
    ]);

    expect(await repository.loadAvailableItems(), hasLength(2));
  });

  test(
    'ordena pela captura mesmo quando o processamento ocorre fora de ordem',
    () async {
      final firstProcessed = createTestImage(
        temporaryDirectory,
        'processed-first.png',
        21,
      );
      final secondProcessed = createTestImage(
        temporaryDirectory,
        'processed-second.png',
        22,
      );
      final thirdProcessed = createTestImage(
        temporaryDirectory,
        'processed-third.png',
        23,
      );

      await repository.importScreenshots([
        SelectedScreenshot(
          path: firstProcessed.path,
          capturedAt: DateTime(2026, 1, 3, 10),
        ),
        SelectedScreenshot(
          path: secondProcessed.path,
          capturedAt: DateTime(2026, 1, 1, 10),
        ),
        SelectedScreenshot(
          path: thirdProcessed.path,
          capturedAt: DateTime(2026, 1, 2, 10),
        ),
      ]);

      final firstLoad = await repository.loadAvailableItems();
      final secondLoad = await repository.loadAvailableItems();
      expect(firstLoad.map((item) => item.effectiveCapturedAt.day), [3, 2, 1]);
      expect(
        secondLoad.map((item) => item.id),
        firstLoad.map((item) => item.id),
      );
    },
  );

  test('capturas empatadas usam imported_at e id como desempate', () async {
    final capturedAt = DateTime(2026, 2, 1);
    final firstId = await store.insertItem(
      privatePath: createPrivateImage(privateDirectory, 'tie-a.png').path,
      internalName: 'tie-a.png',
      mimeType: 'image/png',
      mediaHash: 'tie-a',
      importedAt: DateTime(2026, 2, 2),
      capturedAt: capturedAt,
      sourceMode: 'photoPicker',
      status: 'ready',
    );
    final secondId = await store.insertItem(
      privatePath: createPrivateImage(privateDirectory, 'tie-b.png').path,
      internalName: 'tie-b.png',
      mimeType: 'image/png',
      mediaHash: 'tie-b',
      importedAt: DateTime(2026, 2, 3),
      capturedAt: capturedAt,
      sourceMode: 'photoPicker',
      status: 'ready',
    );
    final thirdId = await store.insertItem(
      privatePath: createPrivateImage(privateDirectory, 'tie-c.png').path,
      internalName: 'tie-c.png',
      mimeType: 'image/png',
      mediaHash: 'tie-c',
      importedAt: DateTime(2026, 2, 3),
      capturedAt: capturedAt,
      sourceMode: 'photoPicker',
      status: 'ready',
    );

    expect((await store.readItems()).map((item) => item.id), [
      thirdId,
      secondId,
      firstId,
    ]);
  });

  test(
    'picker usa imported_at como captura e duplicata não altera a data',
    () async {
      final original = createTestImage(
        temporaryDirectory,
        'capture-fallback.png',
      );
      final capturedAt = DateTime(2025, 5, 20);
      final first = await repository.importScreenshots([
        SelectedScreenshot(path: original.path, capturedAt: capturedAt),
      ]);
      await repository.importScreenshots([
        SelectedScreenshot(path: original.path, capturedAt: DateTime(2026)),
      ], origin: ImportOrigin.shared);

      final persisted = (await repository.loadAvailableItems()).single;
      expect(first.importedItems.single.capturedAt, capturedAt);
      expect(persisted.capturedAt, capturedAt);

      final pickerOnly = createTestImage(
        temporaryDirectory,
        'picker-fallback.png',
        24,
      );
      final picker = await repository.importScreenshots([
        SelectedScreenshot(path: pickerOnly.path),
      ]);
      expect(
        picker.importedItems.single.capturedAt,
        picker.importedItems.single.importedAt,
      );

      final invalidSource = createTestImage(
        temporaryDirectory,
        'invalid-capture.png',
        25,
      );
      final invalid = await repository.importScreenshots([
        SelectedScreenshot(
          path: invalidSource.path,
          capturedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ]);
      expect(
        invalid.importedItems.single.capturedAt,
        invalid.importedItems.single.importedAt,
      );
    },
  );

  test('nova importação cria um job e duplicata não cria outro', () async {
    final jobStore = DriftProcessingJobStore(database);
    repository = LocalMediaItemRepository(
      store: store,
      storage: storage,
      ocrJobScheduler: LocalOcrJobScheduler(jobStore),
    );
    final original = createTestImage(temporaryDirectory, 'com-job.png');

    final first = await repository.importScreenshots([
      SelectedScreenshot(path: original.path),
    ]);
    final duplicate = await repository.importScreenshots([
      SelectedScreenshot(path: original.path),
    ], origin: ImportOrigin.shared);

    expect(first.importedItems, hasLength(1));
    expect(duplicate.importedItems, isEmpty);
    expect(duplicate.duplicateCount, 1);
    expect(await jobStore.findOcrJob(first.importedItems.single.id), isNotNull);
    final jobs = await database.select(database.processingJobs).get();
    expect(jobs, hasLength(1));
    expect(
      (await repository.loadAvailableItems()).single.importOrigin,
      ImportOrigin.picker,
    );
  });

  test('múltiplas imagens compartilhadas criam seus jobs', () async {
    final jobStore = DriftProcessingJobStore(database);
    repository = LocalMediaItemRepository(
      store: store,
      storage: storage,
      ocrJobScheduler: LocalOcrJobScheduler(jobStore),
    );
    final first = createTestImage(temporaryDirectory, 'shared-job-a.png');
    final second = createTestImage(temporaryDirectory, 'shared-job-b.png', 1);

    final result = await repository.importScreenshots([
      SelectedScreenshot(path: first.path),
      SelectedScreenshot(path: second.path),
    ], origin: ImportOrigin.shared);

    expect(result.importedItems, hasLength(2));
    expect(await database.select(database.processingJobs).get(), hasLength(2));
  });

  test('falha ao criar job não desfaz a importação', () async {
    repository = LocalMediaItemRepository(
      store: store,
      storage: storage,
      ocrJobScheduler: FailingOcrJobScheduler(),
    );
    final original = createTestImage(temporaryDirectory, 'job-falhou.png');

    final result = await repository.importScreenshots([
      SelectedScreenshot(path: original.path),
    ]);

    expect(result.importedItems, hasLength(1));
    expect(await store.readItems(), hasLength(1));
    expect(File(result.importedItems.single.privatePath!).existsSync(), isTrue);
    expect(original.existsSync(), isTrue);
  });

  test(
    'ignora duplicata na mesma seleção sem criar cópia ou registro',
    () async {
      final original = createTestImage(temporaryDirectory, 'duplicada.png');

      final result = await repository.importScreenshots([
        SelectedScreenshot(path: original.path),
        SelectedScreenshot(path: original.path),
      ]);

      expect(result.importedItems, hasLength(1));
      expect(result.duplicateCount, 1);
      expect(await store.readItems(), hasLength(1));
      expect(privateCopies(privateDirectory), hasLength(1));
    },
  );

  test('ignora duplicata depois de recriar o repositório', () async {
    final original = createTestImage(temporaryDirectory, 'nova-sessao.png');
    await repository.importScreenshots([
      SelectedScreenshot(path: original.path),
    ]);
    final newSessionRepository = LocalMediaItemRepository(
      store: store,
      storage: storage,
    );

    final result = await newSessionRepository.importScreenshots([
      SelectedScreenshot(path: original.path),
    ]);

    expect(result.importedItems, isEmpty);
    expect(result.duplicateCount, 1);
    expect(await store.readItems(), hasLength(1));
    expect(privateCopies(privateDirectory), hasLength(1));
  });

  test('duas importações concorrentes não criam duplicatas', () async {
    final original = createTestImage(temporaryDirectory, 'concorrente.png');
    final otherRepository = LocalMediaItemRepository(
      store: store,
      storage: storage,
    );

    final results = await Future.wait([
      repository.importScreenshots([SelectedScreenshot(path: original.path)]),
      otherRepository.importScreenshots([
        SelectedScreenshot(path: original.path),
      ]),
    ]);

    expect(
      results.fold<int>(
        0,
        (total, result) => total + result.importedItems.length,
      ),
      1,
    );
    expect(
      results.fold<int>(0, (total, result) => total + result.duplicateCount),
      1,
    );
    expect(await store.readItems(), hasLength(1));
    expect(privateCopies(privateDirectory), hasLength(1));
  });

  test('importa múltiplas imagens e ignora somente as repetidas', () async {
    final first = createTestImage(temporaryDirectory, 'lote-a.png');
    final sameContent = createTestImage(temporaryDirectory, 'lote-b.png');
    final different = createTestImage(temporaryDirectory, 'lote-c.png', 2);

    final result = await repository.importScreenshots([
      SelectedScreenshot(path: first.path),
      SelectedScreenshot(path: sameContent.path),
      SelectedScreenshot(path: different.path),
    ]);

    expect(result.importedItems, hasLength(2));
    expect(result.duplicateCount, 1);
    expect(await store.readItems(), hasLength(2));
    expect(privateCopies(privateDirectory), hasLength(2));
  });

  test('mantém o arquivo original intacto', () async {
    final original = createTestImage(temporaryDirectory, 'intacta.png');
    final originalBytes = original.readAsBytesSync();

    final imported = await repository.importScreenshots([
      SelectedScreenshot(path: original.path),
    ]);

    expect(original.existsSync(), isTrue);
    expect(original.readAsBytesSync(), originalBytes);
    expect(imported.importedItems.single.privatePath, isNot(original.path));
    expect(
      File(imported.importedItems.single.privatePath!).readAsBytesSync(),
      originalBytes,
    );
  });

  test('remove registro e cópia privada preservando o original', () async {
    final original = createTestImage(temporaryDirectory, 'remover.png');
    final imported = await repository.importScreenshots([
      SelectedScreenshot(path: original.path),
    ]);
    final item = imported.importedItems.single;
    final privateCopy = File(item.privatePath!);
    final ocrStore = DriftOcrResultStore(database);
    await ocrStore.save(
      OcrResult(
        mediaItemId: item.id,
        fullText: 'Texto fictício',
        engine: 'Teste',
        engineVersion: '1',
        processedAt: DateTime(2026),
      ),
    );

    await repository.removeItem(item);

    expect(await store.readItems(), isEmpty);
    expect(privateCopy.existsSync(), isFalse);
    expect(original.existsSync(), isTrue);
    expect(await ocrStore.findByMediaItemId(item.id), isNull);
  });

  test('remove registro quando a cópia privada já não existe', () async {
    final missingPath = '${privateDirectory.path}/screenshots/ausente.png';
    final id = await store.insertItem(
      privatePath: missingPath,
      internalName: 'ausente.png',
      mimeType: 'image/png',
      mediaHash: 'hash-ausente-remocao',
      importedAt: DateTime(2026),
      sourceMode: 'photoPicker',
      status: 'ready',
    );
    final item = MediaItem(
      id: id,
      privatePath: missingPath,
      internalName: 'ausente.png',
      mediaHash: 'hash-ausente-remocao',
      mimeType: 'image/png',
      importedAt: DateTime(2026),
      sourceMode: 'photoPicker',
      status: 'ready',
    );

    await repository.removeItem(item);

    expect(await store.readItems(), isEmpty);
  });

  test('mantém registro quando a exclusão da cópia privada falha', () async {
    final original = createTestImage(temporaryDirectory, 'falha-remocao.png');
    final imported = await repository.importScreenshots([
      SelectedScreenshot(path: original.path),
    ]);
    final item = imported.importedItems.single;
    final failingRepository = LocalMediaItemRepository(
      store: store,
      storage: FailingDeleteStorage(storage),
    );

    await expectLater(failingRepository.removeItem(item), throwsStateError);

    expect(await store.readItems(), hasLength(1));
    expect(File(item.privatePath!).existsSync(), isTrue);
    expect(original.existsSync(), isTrue);
  });

  test('não grava item quando a cópia falha', () async {
    final missingPath =
        '${temporaryDirectory.path}${Platform.pathSeparator}ausente.png';

    final result = await repository.importScreenshots([
      SelectedScreenshot(path: missingPath),
    ]);

    expect(result.rejectedCount, 1);
    expect(await store.readItems(), isEmpty);
  });

  test('falha em um arquivo não impede os demais do lote', () async {
    final valid = createTestImage(temporaryDirectory, 'valida.png');
    final missing = '${temporaryDirectory.path}/inexistente.png';

    final result = await repository.importScreenshots([
      SelectedScreenshot(path: missing),
      SelectedScreenshot(path: valid.path),
    ], origin: ImportOrigin.shared);

    expect(result.importedItems, hasLength(1));
    expect(result.rejectedCount, 1);
    expect(result.importedItems.single.importOrigin, ImportOrigin.shared);
  });

  test('remove a cópia privada quando a gravação no banco falha', () async {
    final original = createTestImage(temporaryDirectory, 'falha-banco.png');
    final failingRepository = LocalMediaItemRepository(
      store: FailingMediaItemStore(),
      storage: storage,
    );

    final result = await failingRepository.importScreenshots([
      SelectedScreenshot(path: original.path),
    ]);

    expect(result.rejectedCount, 1);
    final screenshotsDirectory = Directory(
      '${privateDirectory.path}${Platform.pathSeparator}screenshots',
    );
    expect(screenshotsDirectory.existsSync(), isTrue);
    expect(screenshotsDirectory.listSync(), isEmpty);
    expect(original.existsSync(), isTrue);
  });

  test('ignora registro cujo arquivo privado não existe', () async {
    final missingPath =
        '${privateDirectory.path}${Platform.pathSeparator}inexistente.png';
    await store.insertItem(
      privatePath: missingPath,
      internalName: 'inexistente.png',
      mimeType: 'image/png',
      mediaHash: 'hash-inexistente',
      importedAt: DateTime(2026),
      sourceMode: 'photoPicker',
      status: 'ready',
    );

    expect(await repository.loadAvailableItems(), isEmpty);
    expect(await store.readItems(), isEmpty);
  });

  test('preenche hash de registro antigo sem recalcular depois', () async {
    final countingCalculator = CountingHashCalculator();
    repository = LocalMediaItemRepository(
      store: store,
      storage: storage,
      hashCalculator: countingCalculator,
    );
    final copy = createPrivateImage(privateDirectory, 'antiga.png');
    await store.insertItem(
      privatePath: copy.path,
      internalName: 'antiga.png',
      mimeType: 'image/png',
      mediaHash: null,
      importedAt: DateTime(2025),
      sourceMode: 'photoPicker',
      status: 'ready',
    );

    final firstLoad = await repository.loadAvailableItems();
    final firstHash = firstLoad.single.mediaHash;
    final secondLoad = await repository.loadAvailableItems();

    expect(firstHash, isNotNull);
    expect(secondLoad.single.mediaHash, firstHash);
    expect(countingCalculator.callCount, 1);
  });

  test(
    'consolida registros antigos idênticos mantendo o mais antigo',
    () async {
      final olderCopy = createPrivateImage(privateDirectory, 'mais-antiga.png');
      final newerCopy = createPrivateImage(privateDirectory, 'mais-nova.png');
      final olderId = await store.insertItem(
        privatePath: olderCopy.path,
        internalName: 'mais-antiga.png',
        mimeType: 'image/png',
        mediaHash: null,
        importedAt: DateTime(2024),
        sourceMode: 'photoPicker',
        status: 'ready',
      );
      await store.insertItem(
        privatePath: newerCopy.path,
        internalName: 'mais-nova.png',
        mimeType: 'image/png',
        mediaHash: null,
        importedAt: DateTime(2025),
        sourceMode: 'photoPicker',
        status: 'ready',
      );

      final loaded = await repository.loadAvailableItems();

      expect(loaded, hasLength(1));
      expect(loaded.single.id, olderId);
      expect(loaded.single.mediaHash, isNotNull);
      expect(olderCopy.existsSync(), isTrue);
      expect(newerCopy.existsSync(), isFalse);
    },
  );

  test('salva e carrega arquivo privado e referência MediaStore', () async {
    final original = createTestImage(temporaryDirectory, 'privada.png');
    final privateItem = (await repository.importScreenshots([
      SelectedScreenshot(path: original.path),
    ])).importedItems.single;
    final reference = await repository.createMediaStoreReference(
      location: mediaStoreLocation('external_primary', 42),
      mimeType: 'image/png',
      capturedAt: DateTime.utc(2025),
      importedAt: DateTime.utc(2026),
    );

    final loaded = await repository.loadAvailableItems();
    expect(loaded.map((item) => item.id), [privateItem.id, reference.id]);
    expect(loaded.first.isPrivateFile, isTrue);
    expect(loaded.last.isMediaStoreReference, isTrue);
    expect(loaded.last.mediaHash, isNull);
    expect(loaded.last.privatePath, isNull);
    expect(
      (await repository.loadBySourceKey('external_primary:42'))?.id,
      reference.id,
    );
  });

  test(
    'sourceKey é idempotente e o mesmo ID existe em volumes distintos',
    () async {
      final first = await repository.createMediaStoreReference(
        location: mediaStoreLocation('external_primary', 7),
        mimeType: 'image/png',
        capturedAt: DateTime.utc(2026, 1, 2),
      );
      final repeated = await repository.createMediaStoreReference(
        location: mediaStoreLocation('external_primary', 7),
        mimeType: 'image/jpeg',
        capturedAt: DateTime.utc(2026, 1, 3),
      );
      final otherVolume = await repository.createMediaStoreReference(
        location: mediaStoreLocation('0123-4567', 7),
        mimeType: 'image/png',
        capturedAt: DateTime.utc(2026, 1, 1),
      );

      expect(repeated.id, first.id);
      expect(otherVolume.id, isNot(first.id));
      expect(await database.select(database.mediaItems).get(), hasLength(2));
      expect(
        (await repository.loadAvailableItems()).map((item) => item.sourceKey),
        ['external_primary:7', '0123-4567:7'],
      );
    },
  );

  test('referência persiste ao reabrir e remoção não apaga original', () async {
    final databaseFile = File('${temporaryDirectory.path}/reference.sqlite');
    var persistentDatabase = ContextoDatabase.forTesting(
      NativeDatabase(databaseFile),
    );
    final recordingStorage = RecordingStorage();
    var persistentRepository = LocalMediaItemRepository(
      store: DriftMediaItemStore(persistentDatabase),
      storage: recordingStorage,
    );
    final item = await persistentRepository.createMediaStoreReference(
      location: mediaStoreLocation('external', 99),
      mimeType: 'image/png',
      capturedAt: DateTime.utc(2024),
    );
    final createdAt = DateTime.utc(2026);
    await persistentDatabase
        .into(persistentDatabase.ocrResults)
        .insert(
          OcrResultsCompanion.insert(
            mediaItemId: Value(item.id),
            fullText: 'OCR anterior preservado até a remoção',
            engine: 'Teste',
            engineVersion: '1',
            processedAt: createdAt,
          ),
        );
    final tagId = await persistentDatabase
        .into(persistentDatabase.tags)
        .insert(
          TagsCompanion.insert(
            name: 'Referência',
            normalizedName: 'referencia-remocao',
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
    await persistentDatabase
        .into(persistentDatabase.mediaTags)
        .insert(
          MediaTagsCompanion.insert(
            mediaItemId: item.id,
            tagId: tagId,
            createdAt: createdAt,
          ),
        );
    await persistentDatabase
        .into(persistentDatabase.classificationSuggestions)
        .insert(
          ClassificationSuggestionsCompanion.insert(
            mediaItemId: Value(item.id),
            confidence: 0.5,
            hasSuggestion: false,
            suggestedTagsJson: '[]',
            evidenceJson: '[]',
            status: 'rejected',
            engineVersion: 1,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
    await persistentRepository.close();

    persistentDatabase = ContextoDatabase.forTesting(
      NativeDatabase(databaseFile),
    );
    persistentRepository = LocalMediaItemRepository(
      store: DriftMediaItemStore(persistentDatabase),
      storage: recordingStorage,
    );
    final reopened = await persistentRepository.loadBySourceKey('external:99');
    expect(reopened?.location, item.location);

    await persistentRepository.removeItem(reopened!);
    expect(recordingStorage.deletedPaths, isEmpty);
    expect(await persistentRepository.loadBySourceKey('external:99'), isNull);
    expect(
      await persistentDatabase.select(persistentDatabase.ocrResults).get(),
      isEmpty,
    );
    expect(
      await persistentDatabase.select(persistentDatabase.mediaTags).get(),
      isEmpty,
    );
    expect(
      await persistentDatabase
          .select(persistentDatabase.classificationSuggestions)
          .get(),
      isEmpty,
    );
    expect(
      await persistentDatabase.select(persistentDatabase.tags).get(),
      hasLength(1),
    );
    await persistentRepository.close();
  });
}

class FailingMediaItemStore implements MediaItemStore {
  @override
  Future<int> insertMediaStoreReference({
    required MediaStoreReferenceLocation location,
    required String? mimeType,
    required DateTime importedAt,
    required DateTime? capturedAt,
    required String sourceMode,
    required String status,
    ImportOrigin importOrigin = ImportOrigin.picker,
  }) {
    throw StateError('Falha simulada no banco');
  }

  @override
  Future<int> insertItem({
    required String privatePath,
    required String internalName,
    required String? mimeType,
    required String? mediaHash,
    required DateTime importedAt,
    DateTime? capturedAt,
    required String sourceMode,
    required String status,
    ImportOrigin importOrigin = ImportOrigin.picker,
  }) {
    throw StateError('Falha simulada no banco');
  }

  @override
  Future<List<MediaItem>> readItems({int? tagId}) async => const [];

  @override
  Future<MediaItem?> findById(int id) async => null;

  @override
  Future<MediaItem?> findByHash(String mediaHash) async => null;

  @override
  Future<MediaItem?> findBySourceKey(String sourceKey) async => null;

  @override
  Future<void> updateHash(int id, String mediaHash) async {}

  @override
  Future<void> deleteItem(int id) async {}

  @override
  Future<List<RecognizedTextMatch>> searchRecognizedText(
    String normalizedQuery, {
    int? tagId,
    required int limit,
  }) async => const [];

  @override
  Future<void> close() async {}
}

class FailingOcrJobScheduler implements OcrJobScheduler {
  @override
  Future<bool> schedule(int mediaItemId) {
    throw StateError('Falha simulada ao criar tarefa');
  }
}

class CountingHashCalculator implements FileHashCalculator {
  final FileHashCalculator _delegate = const Sha256FileHashCalculator();
  int callCount = 0;

  @override
  Future<String> calculate(String filePath) {
    callCount++;
    return _delegate.calculate(filePath);
  }
}

class FailingDeleteStorage implements ScreenshotStorage {
  FailingDeleteStorage(this._delegate);

  final ScreenshotStorage _delegate;

  @override
  Future<StoredScreenshot> copyToPrivate(String sourcePath) {
    return _delegate.copyToPrivate(sourcePath);
  }

  @override
  Future<void> deletePrivateCopy(String privatePath) {
    throw StateError('Falha simulada ao excluir cópia');
  }
}

class RecordingStorage implements ScreenshotStorage {
  final List<String> deletedPaths = [];

  @override
  Future<StoredScreenshot> copyToPrivate(String sourcePath) {
    throw UnsupportedError('Não usado');
  }

  @override
  Future<void> deletePrivateCopy(String privatePath) async {
    deletedPaths.add(privatePath);
  }
}

MediaStoreReferenceLocation mediaStoreLocation(String volume, int id) {
  return MediaStoreReferenceLocation(
    sourceKey: '$volume:$id',
    mediaStoreId: id,
    volumeName: volume,
    contentUri: 'content://media/$volume/images/media/$id',
    dateModified: DateTime.utc(2026),
  );
}

File createTestImage(Directory directory, String name, [int marker = 0]) {
  const minimalPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
  final bytes = [...base64Decode(minimalPng), if (marker != 0) marker];
  return File('${directory.path}${Platform.pathSeparator}$name')
    ..writeAsBytesSync(bytes);
}

List<FileSystemEntity> privateCopies(Directory privateDirectory) {
  final directory = Directory(
    '${privateDirectory.path}${Platform.pathSeparator}screenshots',
  );
  return directory.existsSync() ? directory.listSync() : const [];
}

File createPrivateImage(Directory privateDirectory, String name) {
  final directory = Directory(
    '${privateDirectory.path}${Platform.pathSeparator}screenshots',
  )..createSync(recursive: true);
  return createTestImage(directory, name);
}

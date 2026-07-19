import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/database/contexto_database.dart'
    hide ExistingScreenshotCandidate;
import 'package:memoshot/core/media/screenshot_storage.dart';
import 'package:memoshot/features/existing_screenshots/application/historical_archive_preparation_coordinator.dart';
import 'package:memoshot/features/existing_screenshots/application/historical_media_import_processor.dart';
import 'package:memoshot/features/existing_screenshots/data/existing_screenshot_candidate_repository.dart';
import 'package:memoshot/features/existing_screenshots/data/existing_screenshot_candidate_store.dart';
import 'package:memoshot/features/existing_screenshots/data/historical_media_import_job_store.dart';
import 'package:memoshot/features/existing_screenshots/data/historical_preparation_settings_repository.dart';
import 'package:memoshot/features/existing_screenshots/domain/existing_screenshot_candidate.dart';
import 'package:memoshot/features/existing_screenshots/domain/historical_media_import_job.dart';
import 'package:memoshot/features/library/data/media_item_repository.dart';
import 'package:memoshot/features/library/data/media_item_store.dart';

void main() {
  late ContextoDatabase database;
  late ExistingScreenshotCandidateRepository candidates;
  late DriftHistoricalMediaImportJobStore jobs;
  late LocalMediaItemRepository media;
  late _Settings settings;
  late _NoCopyStorage storage;

  setUp(() {
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    candidates = LocalExistingScreenshotCandidateRepository(
      DriftExistingScreenshotCandidateStore(database),
    );
    jobs = DriftHistoricalMediaImportJobStore(database);
    storage = _NoCopyStorage();
    media = LocalMediaItemRepository(
      store: DriftMediaItemStore(database),
      storage: storage,
    );
    settings = _Settings();
  });

  tearDown(() => database.close());

  test(
    'enfileira disponíveis em lotes idempotentes e ignora indisponível',
    () async {
      await candidates.upsertBatch([
        for (var id = 1; id <= 205; id++) _candidate(id),
      ]);
      await candidates.markUnavailableNotSeenInCompletedScan(
        DateTime.utc(2027),
      );
      await candidates.upsertBatch([
        for (var id = 1; id <= 204; id++) _candidate(id),
      ]);

      final first = await jobs.enqueueAvailableBatch(
        now: DateTime.utc(2026),
        limit: 200,
      );
      final second = await jobs.enqueueAvailableBatch(
        now: DateTime.utc(2026),
        limit: 200,
      );
      final repeated = await jobs.enqueueAvailableBatch(
        now: DateTime.utc(2026),
        limit: 200,
      );

      expect(first, 200);
      expect(second, 4);
      expect(repeated, 0);
      expect(
        await database.select(database.historicalMediaImportJobs).get(),
        hasLength(204),
      );
    },
  );

  for (final total in [5700, 10000]) {
    test(
      '$total candidatos são enfileirados em páginas de no máximo 200',
      () async {
        for (var offset = 1; offset <= total; offset += 200) {
          final end = (offset + 199).clamp(1, total);
          await candidates.upsertBatch([
            for (var id = offset; id <= end; id++) _candidate(id),
          ]);
        }
        var insertedTotal = 0;
        var maximumBatch = 0;
        while (true) {
          final inserted = await jobs.enqueueAvailableBatch(
            now: DateTime.utc(2026),
          );
          if (inserted == 0) break;
          insertedTotal += inserted;
          if (inserted > maximumBatch) maximumBatch = inserted;
        }

        expect(insertedTotal, total);
        expect(maximumBatch, lessThanOrEqualTo(200));
        expect(
          await database.select(database.historicalMediaImportJobs).get(),
          hasLength(total),
        );
      },
      timeout: const Timeout(Duration(seconds: 40)),
    );
  }

  test(
    'processa referência canônica sem cópia, hash, OCR ou classificação',
    () async {
      final capturedAt = DateTime.utc(2024, 5, 6);
      final modifiedAt = DateTime.utc(2024, 5, 7);
      await candidates.upsertBatch([
        _candidate(42, capturedAt: capturedAt, dateModified: modifiedAt),
      ]);
      await settings.start();
      final processor = _processor(jobs, media, settings);
      addTearDown(processor.close);

      final result = await processor.processAvailable(maximumItems: 25);
      final item = await media.loadBySourceKey('external_primary:42');
      final row = await database.select(database.mediaItems).getSingle();

      expect(result.preparedCount, 1);
      expect(item?.sourceKey, 'external_primary:42');
      expect(
        row.contentUri,
        'content://media/external_primary/images/media/42',
      );
      expect(row.capturedAt?.isAtSameMomentAs(capturedAt), isTrue);
      expect(row.sourceDateModified?.isAtSameMomentAs(modifiedAt), isTrue);
      expect(row.mimeType, 'image/png');
      expect(row.storageKind, 'mediaStoreReference');
      expect(row.mediaHash, isNull);
      expect(row.privatePath, isNull);
      expect(storage.copyCalls, 0);
      expect(await database.select(database.ocrResults).get(), isEmpty);
      expect(await database.select(database.processingJobs).get(), isEmpty);
      expect(await database.select(database.classificationJobs).get(), isEmpty);
      expect(
        await database.select(database.historicalMediaImportJobs).get(),
        isEmpty,
      );
    },
  );

  test(
    'dois processadores reservam atomicamente e sourceKey não duplica',
    () async {
      await candidates.upsertBatch([
        for (var id = 1; id <= 200; id++) _candidate(id),
      ]);
      await settings.start();
      final first = _processor(jobs, media, settings);
      final second = _processor(jobs, media, settings);
      addTearDown(first.close);
      addTearDown(second.close);

      await Future.wait([
        first.processAvailable(maximumItems: 100),
        second.processAvailable(maximumItems: 100),
      ]);
      final rows = await database.select(database.mediaItems).get();

      expect(rows, hasLength(200));
      expect(rows.map((row) => row.sourceKey).toSet(), hasLength(200));
      expect(
        await database.select(database.historicalMediaImportJobs).get(),
        isEmpty,
      );
    },
  );

  test('pausa impede nova reserva e retomada preserva a fila', () async {
    await candidates.upsertBatch([_candidate(1), _candidate(2)]);
    await jobs.enqueueAvailableBatch(now: DateTime.utc(2026));
    final processor = _processor(jobs, media, settings);
    addTearDown(processor.close);

    await settings.pause();
    expect(
      (await processor.processAvailable(maximumItems: 25)).processedCount,
      0,
    );
    expect(
      await database.select(database.historicalMediaImportJobs).get(),
      hasLength(2),
    );

    await settings.resume();
    expect(
      (await processor.processAvailable(maximumItems: 25)).preparedCount,
      2,
    );
  });

  test(
    'candidato indisponível falha sem retry e sem criar MediaItem',
    () async {
      await candidates.upsertBatch([_candidate(1)]);
      await jobs.enqueueAvailableBatch(now: DateTime.utc(2026));
      await candidates.markUnavailableNotSeenInCompletedScan(
        DateTime.utc(2027),
      );
      await settings.start();
      final processor = _processor(jobs, media, settings);
      addTearDown(processor.close);

      await processor.processAvailable(maximumItems: 25);
      final job = await database
          .select(database.historicalMediaImportJobs)
          .getSingle();

      expect(job.state, HistoricalMediaImportJobState.failed.name);
      expect(
        job.lastErrorCode,
        HistoricalMediaImportErrorCode.candidateUnavailable.name,
      );
      expect(await database.select(database.mediaItems).get(), isEmpty);
    },
  );

  test('URI estruturalmente inválida falha diretamente', () async {
    final valid = _candidate(1);
    await candidates.upsertBatch([
      ExistingScreenshotCandidate(
        sourceKey: valid.sourceKey,
        mediaStoreId: valid.mediaStoreId,
        volumeName: valid.volumeName,
        contentUri: 'content://media/external/images/media/999',
        mimeType: valid.mimeType,
        capturedAt: valid.capturedAt,
        dateModified: valid.dateModified,
        sizeBytes: valid.sizeBytes,
        width: valid.width,
        height: valid.height,
        discoveredAt: valid.discoveredAt,
        lastSeenAt: valid.lastSeenAt,
        availability: valid.availability,
      ),
    ]);
    await settings.start();
    final processor = _processor(jobs, media, settings);
    addTearDown(processor.close);

    await processor.processAvailable(maximumItems: 25);
    final job = await database
        .select(database.historicalMediaImportJobs)
        .getSingle();

    expect(job.state, HistoricalMediaImportJobState.failed.name);
    expect(
      job.lastErrorCode,
      HistoricalMediaImportErrorCode.invalidReference.name,
    );
    expect(await database.select(database.mediaItems).get(), isEmpty);
  });

  test('recupera processing expirado e preserva reserva recente', () async {
    final now = DateTime.utc(2026, 7, 19, 12);
    await candidates.upsertBatch([_candidate(1), _candidate(2)]);
    await jobs.enqueueAvailableBatch(
      now: now.subtract(const Duration(hours: 1)),
    );
    final old = await jobs.claimNextAvailable(
      now: now.subtract(const Duration(minutes: 20)),
    );
    final recent = await jobs.claimNextAvailable(
      now: now.subtract(const Duration(minutes: 2)),
    );
    expect(old, isNotNull);
    expect(recent, isNotNull);

    final recovered = await jobs.recoverExpired(
      expiredBefore: now.subtract(const Duration(minutes: 10)),
      now: now,
    );
    final rows = await database
        .select(database.historicalMediaImportJobs)
        .get();

    expect(recovered, 1);
    expect(
      rows.singleWhere((row) => row.sourceKey == old!.sourceKey).state,
      HistoricalMediaImportJobState.pending.name,
    );
    expect(
      rows.singleWhere((row) => row.sourceKey == recent!.sourceKey).state,
      HistoricalMediaImportJobState.processing.name,
    );
  });

  test('retry usa atrasos determinísticos e termina na quinta tentativa', () {
    const policy = HistoricalMediaImportRetryPolicy();
    expect(policy.delayAfterFailure(1), const Duration(seconds: 15));
    expect(policy.delayAfterFailure(2), const Duration(minutes: 1));
    expect(policy.delayAfterFailure(3), const Duration(minutes: 5));
    expect(policy.delayAfterFailure(4), const Duration(minutes: 30));
    expect(policy.delayAfterFailure(5), isNull);
  });

  test(
    'fila não persiste URI, caminho, OCR, hash ou mensagens livres',
    () async {
      final columns = await database
          .customSelect('PRAGMA table_info(historical_media_import_jobs)')
          .get();
      final names = columns.map((row) => row.read<String>('name')).toSet();

      expect(names, {
        'source_key',
        'state',
        'attempts',
        'available_at',
        'created_at',
        'updated_at',
        'processing_started_at',
        'last_error_code',
      });
      expect(names, isNot(contains('content_uri')));
      expect(names, isNot(contains('private_path')));
      expect(names, isNot(contains('ocr_text')));
      expect(names, isNot(contains('media_hash')));
      expect(names, isNot(contains('error_message')));
    },
  );

  test(
    'coordenador inicia explicitamente, pausa e agenda trabalho existente',
    () async {
      final scheduler = _Scheduler();
      final coordinator = HistoricalArchivePreparationCoordinator(
        jobStore: jobs,
        settingsRepository: settings,
        scheduler: scheduler,
      );
      await candidates.upsertBatch([_candidate(1)]);

      expect(
        (await coordinator.loadProgress()).state,
        HistoricalPreparationState.notStarted,
      );
      expect(scheduler.calls, 0);
      await coordinator.start();
      expect(
        (await coordinator.loadProgress()).state,
        HistoricalPreparationState.active,
      );
      expect(scheduler.calls, 1);
      await coordinator.pause();
      expect(
        (await coordinator.loadProgress()).state,
        HistoricalPreparationState.paused,
      );
      await coordinator.resume();
      expect(scheduler.calls, 2);
    },
  );
}

LocalHistoricalMediaImportProcessor _processor(
  HistoricalMediaImportJobStore jobs,
  MediaStoreReferenceMediaItemRepository media,
  HistoricalPreparationSettingsRepository settings,
) => LocalHistoricalMediaImportProcessor(
  jobStore: jobs,
  mediaRepository: media,
  settingsRepository: settings,
  now: () => DateTime.utc(2026, 7, 19, 12),
);

ExistingScreenshotCandidate _candidate(
  int id, {
  DateTime? capturedAt,
  DateTime? dateModified,
}) => ExistingScreenshotCandidate(
  sourceKey: 'external_primary:$id',
  mediaStoreId: id,
  volumeName: 'external_primary',
  contentUri: 'content://media/external_primary/images/media/$id',
  mimeType: 'image/png',
  capturedAt: capturedAt ?? DateTime.utc(2024),
  dateModified: dateModified ?? DateTime.utc(2024, 2),
  sizeBytes: 1024,
  width: 1080,
  height: 2400,
  discoveredAt: DateTime.utc(2026),
  lastSeenAt: DateTime.utc(2026),
  availability: ExistingScreenshotAvailability.available,
);

class _Settings implements HistoricalPreparationSettingsRepository {
  HistoricalPreparationState state = HistoricalPreparationState.notStarted;

  @override
  Future<HistoricalPreparationState> load() async => state;

  @override
  Future<void> pause() async => state = HistoricalPreparationState.paused;

  @override
  Future<void> resume() async => state = HistoricalPreparationState.active;

  @override
  Future<void> start() async => state = HistoricalPreparationState.active;

  @override
  Future<void> complete() async => state = HistoricalPreparationState.completed;
}

class _Scheduler implements HistoricalPreparationScheduler {
  int calls = 0;

  @override
  Future<void> schedule() async => calls++;
}

class _NoCopyStorage implements ScreenshotStorage {
  int copyCalls = 0;

  @override
  Future<StoredScreenshot> copyToPrivate(String sourcePath) async {
    copyCalls++;
    throw StateError('não deve copiar');
  }

  @override
  Future<void> deletePrivateCopy(String privatePath) async {}
}

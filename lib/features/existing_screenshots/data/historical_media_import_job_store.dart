import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../domain/existing_screenshot_candidate.dart' as candidate_domain;
import '../domain/historical_media_import_job.dart' as domain;

const historicalMediaEnqueueBatchSize = 200;

abstract interface class HistoricalMediaImportJobStore {
  Future<int> enqueueAvailableBatch({required DateTime now, int limit = 200});

  Future<domain.HistoricalMediaImportJob?> claimNextAvailable({
    required DateTime now,
  });

  Future<bool> deleteClaimed(domain.HistoricalMediaImportJob job);

  Future<bool> scheduleRetry({
    required domain.HistoricalMediaImportJob job,
    required DateTime availableAt,
    required DateTime updatedAt,
    required domain.HistoricalMediaImportErrorCode errorCode,
  });

  Future<bool> markFailed({
    required domain.HistoricalMediaImportJob job,
    required DateTime updatedAt,
    required domain.HistoricalMediaImportErrorCode errorCode,
  });

  Future<int> recoverExpired({
    required DateTime expiredBefore,
    required DateTime now,
  });

  Future<candidate_domain.ExistingScreenshotCandidate?> loadCandidate(
    String sourceKey,
  );

  Future<bool> hasAvailable(DateTime now);

  Future<bool> hasUnqueuedCandidates();

  Future<bool> hasActiveJobs();

  Future<bool> hasJobs();

  Future<DateTime?> nextRetryAt();

  Future<domain.HistoricalPreparationProgress> loadProgress({
    required domain.HistoricalPreparationState state,
  });
}

class DriftHistoricalMediaImportJobStore
    implements HistoricalMediaImportJobStore {
  DriftHistoricalMediaImportJobStore(this._database);

  final ContextoDatabase _database;

  @override
  Future<int> enqueueAvailableBatch({
    required DateTime now,
    int limit = historicalMediaEnqueueBatchSize,
  }) {
    final effectiveLimit = limit.clamp(1, historicalMediaEnqueueBatchSize);
    return _database.transaction(() async {
      return _database.customUpdate(
        '''
        INSERT OR IGNORE INTO historical_media_import_jobs (
          source_key, state, attempts, available_at, created_at, updated_at
        )
        SELECT candidate.source_key, 'pending', 0, ?, ?, ?
        FROM existing_screenshot_candidates AS candidate
        LEFT JOIN media_items AS media
          ON media.source_key = candidate.source_key
          AND media.storage_kind = 'mediaStoreReference'
        LEFT JOIN historical_media_import_jobs AS job
          ON job.source_key = candidate.source_key
        WHERE candidate.availability_state = 'available'
          AND media.id IS NULL
          AND job.source_key IS NULL
        ORDER BY candidate.source_key ASC
        LIMIT ?
        ''',
        variables: [
          Variable<DateTime>(now),
          Variable<DateTime>(now),
          Variable<DateTime>(now),
          Variable<int>(effectiveLimit),
        ],
        updates: {_database.historicalMediaImportJobs},
      );
    });
  }

  @override
  Future<domain.HistoricalMediaImportJob?> claimNextAvailable({
    required DateTime now,
  }) {
    return _database.transaction(() async {
      final row =
          await (_database.select(_database.historicalMediaImportJobs)
                ..where(
                  (job) =>
                      job.availableAt.isSmallerOrEqualValue(now) &
                      (job.state.equals(
                            domain.HistoricalMediaImportJobState.pending.name,
                          ) |
                          job.state.equals(
                            domain
                                .HistoricalMediaImportJobState
                                .retryScheduled
                                .name,
                          )),
                )
                ..orderBy([
                  (job) => OrderingTerm.asc(job.availableAt),
                  (job) => OrderingTerm.asc(job.createdAt),
                  (job) => OrderingTerm.asc(job.sourceKey),
                ])
                ..limit(1))
              .getSingleOrNull();
      if (row == null) return null;
      final changed =
          await (_database.update(_database.historicalMediaImportJobs)..where(
                (job) =>
                    job.sourceKey.equals(row.sourceKey) &
                    job.state.equals(row.state) &
                    job.updatedAt.equals(row.updatedAt),
              ))
              .write(
                HistoricalMediaImportJobsCompanion(
                  state: Value(
                    domain.HistoricalMediaImportJobState.processing.name,
                  ),
                  attempts: Value(row.attempts + 1),
                  updatedAt: Value(now),
                  processingStartedAt: Value(now),
                  lastErrorCode: const Value(null),
                ),
              );
      if (changed != 1) return null;
      return domain.HistoricalMediaImportJob(
        sourceKey: row.sourceKey,
        state: domain.HistoricalMediaImportJobState.processing,
        attempts: row.attempts + 1,
        availableAt: row.availableAt,
        createdAt: row.createdAt,
        updatedAt: now,
        processingStartedAt: now,
      );
    });
  }

  @override
  Future<bool> deleteClaimed(domain.HistoricalMediaImportJob job) async {
    final startedAt = job.processingStartedAt;
    if (startedAt == null) return false;
    return await (_database.delete(_database.historicalMediaImportJobs)..where(
              (row) =>
                  row.sourceKey.equals(job.sourceKey) &
                  row.state.equals(
                    domain.HistoricalMediaImportJobState.processing.name,
                  ) &
                  row.processingStartedAt.equals(startedAt),
            ))
            .go() ==
        1;
  }

  @override
  Future<bool> scheduleRetry({
    required domain.HistoricalMediaImportJob job,
    required DateTime availableAt,
    required DateTime updatedAt,
    required domain.HistoricalMediaImportErrorCode errorCode,
  }) => _writeClaimed(
    job,
    HistoricalMediaImportJobsCompanion(
      state: Value(domain.HistoricalMediaImportJobState.retryScheduled.name),
      availableAt: Value(availableAt),
      updatedAt: Value(updatedAt),
      processingStartedAt: const Value(null),
      lastErrorCode: Value(errorCode.name),
    ),
  );

  @override
  Future<bool> markFailed({
    required domain.HistoricalMediaImportJob job,
    required DateTime updatedAt,
    required domain.HistoricalMediaImportErrorCode errorCode,
  }) => _writeClaimed(
    job,
    HistoricalMediaImportJobsCompanion(
      state: Value(domain.HistoricalMediaImportJobState.failed.name),
      updatedAt: Value(updatedAt),
      processingStartedAt: const Value(null),
      lastErrorCode: Value(errorCode.name),
    ),
  );

  Future<bool> _writeClaimed(
    domain.HistoricalMediaImportJob job,
    HistoricalMediaImportJobsCompanion values,
  ) async {
    final startedAt = job.processingStartedAt;
    if (startedAt == null) return false;
    return await (_database.update(_database.historicalMediaImportJobs)..where(
              (row) =>
                  row.sourceKey.equals(job.sourceKey) &
                  row.state.equals(
                    domain.HistoricalMediaImportJobState.processing.name,
                  ) &
                  row.processingStartedAt.equals(startedAt),
            ))
            .write(values) ==
        1;
  }

  @override
  Future<int> recoverExpired({
    required DateTime expiredBefore,
    required DateTime now,
  }) {
    return (_database.update(_database.historicalMediaImportJobs)..where(
          (job) =>
              job.state.equals(
                domain.HistoricalMediaImportJobState.processing.name,
              ) &
              (job.processingStartedAt.isNull() |
                  job.processingStartedAt.isSmallerOrEqualValue(expiredBefore)),
        ))
        .write(
          HistoricalMediaImportJobsCompanion(
            state: Value(domain.HistoricalMediaImportJobState.pending.name),
            availableAt: Value(now),
            updatedAt: Value(now),
            processingStartedAt: const Value(null),
            lastErrorCode: const Value(null),
          ),
        );
  }

  @override
  Future<candidate_domain.ExistingScreenshotCandidate?> loadCandidate(
    String sourceKey,
  ) async {
    final row =
        await (_database.select(_database.existingScreenshotCandidates)
              ..where((candidate) => candidate.sourceKey.equals(sourceKey)))
            .getSingleOrNull();
    if (row == null) return null;
    return candidate_domain.ExistingScreenshotCandidate(
      sourceKey: row.sourceKey,
      mediaStoreId: row.mediaStoreId,
      volumeName: row.volumeName,
      contentUri: row.contentUri,
      mimeType: row.mimeType,
      capturedAt: row.capturedAt,
      dateModified: row.dateModified,
      sizeBytes: row.sizeBytes,
      width: row.width,
      height: row.height,
      discoveredAt: row.discoveredAt,
      lastSeenAt: row.lastSeenAt,
      availability: candidate_domain.ExistingScreenshotAvailability.values
          .byName(row.availabilityState),
    );
  }

  @override
  Future<bool> hasAvailable(DateTime now) => _exists(
    '''state IN ('pending', 'retryScheduled') AND available_at <= ?''',
    [Variable<DateTime>(now)],
  );

  @override
  Future<bool> hasUnqueuedCandidates() async {
    final row = await _database
        .customSelect(
          '''
      SELECT 1
      FROM existing_screenshot_candidates AS candidate
      LEFT JOIN media_items AS media
        ON media.source_key = candidate.source_key
        AND media.storage_kind = 'mediaStoreReference'
      LEFT JOIN historical_media_import_jobs AS job
        ON job.source_key = candidate.source_key
      WHERE candidate.availability_state = 'available'
        AND media.id IS NULL
        AND job.source_key IS NULL
      LIMIT 1
      ''',
          readsFrom: {
            _database.existingScreenshotCandidates,
            _database.mediaItems,
            _database.historicalMediaImportJobs,
          },
        )
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<bool> hasActiveJobs() =>
      _exists("state IN ('pending', 'processing', 'retryScheduled')", const []);

  @override
  Future<bool> hasJobs() => _exists('1 = 1', const []);

  @override
  Future<DateTime?> nextRetryAt() async {
    final minimum = _database.historicalMediaImportJobs.availableAt.min();
    final query = _database.selectOnly(_database.historicalMediaImportJobs)
      ..addColumns([minimum])
      ..where(
        _database.historicalMediaImportJobs.state.equals(
          domain.HistoricalMediaImportJobState.retryScheduled.name,
        ),
      );
    return (await query.getSingle()).read(minimum);
  }

  Future<bool> _exists(
    String condition,
    List<Variable<Object>> variables,
  ) async {
    final row = await _database
        .customSelect(
          'SELECT 1 FROM historical_media_import_jobs WHERE $condition LIMIT 1',
          variables: variables,
          readsFrom: {_database.historicalMediaImportJobs},
        )
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<domain.HistoricalPreparationProgress> loadProgress({
    required domain.HistoricalPreparationState state,
  }) async {
    final row = await _database
        .customSelect(
          '''
      SELECT
        (SELECT COUNT(*) FROM existing_screenshot_candidates
          WHERE availability_state = 'available') AS available_count,
        (SELECT COUNT(*) FROM existing_screenshot_candidates
          WHERE availability_state = 'unavailable') AS unavailable_count,
        (SELECT COUNT(*)
          FROM existing_screenshot_candidates AS candidate
          INNER JOIN media_items AS media
            ON media.source_key = candidate.source_key
            AND media.storage_kind = 'mediaStoreReference'
          WHERE candidate.availability_state = 'available') AS prepared_count,
        SUM(CASE WHEN state = 'pending' THEN 1 ELSE 0 END) AS pending_count,
        SUM(CASE WHEN state = 'processing' THEN 1 ELSE 0 END) AS processing_count,
        SUM(CASE WHEN state = 'retryScheduled' THEN 1 ELSE 0 END)
          AS retry_count,
        SUM(CASE WHEN state = 'failed' THEN 1 ELSE 0 END) AS failed_count
      FROM historical_media_import_jobs
      ''',
          readsFrom: {
            _database.existingScreenshotCandidates,
            _database.mediaItems,
            _database.historicalMediaImportJobs,
          },
        )
        .getSingle();
    int value(String name) => row.readNullable<int>(name) ?? 0;
    return domain.HistoricalPreparationProgress(
      availableCount: value('available_count'),
      preparedCount: value('prepared_count'),
      pendingCount: value('pending_count'),
      processingCount: value('processing_count'),
      retryScheduledCount: value('retry_count'),
      failedCount: value('failed_count'),
      unavailableCount: value('unavailable_count'),
      state: state,
    );
  }
}

import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../domain/classification_job.dart' as domain;
import '../domain/stored_classification_suggestion.dart';

abstract interface class ClassificationJobStore {
  Future<bool> enqueueIfNeeded({
    required int mediaItemId,
    required int engineVersion,
    required DateTime now,
  });

  Future<domain.ClassificationJob?> findByMediaItemId(int mediaItemId);

  Future<domain.ClassificationJob?> claimNextAvailable({
    required DateTime now,
    required int engineVersion,
  });

  Future<bool> deleteClaimed(domain.ClassificationJob job);

  Future<void> deleteForMediaItem(int mediaItemId);

  Future<bool> scheduleRetry({
    required domain.ClassificationJob job,
    required DateTime availableAt,
    required DateTime updatedAt,
    required domain.ClassificationJobErrorCode errorCode,
  });

  Future<bool> markFailed({
    required domain.ClassificationJob job,
    required DateTime updatedAt,
    required domain.ClassificationJobErrorCode errorCode,
  });

  Future<int> recoverExpired({
    required DateTime expiredBefore,
    required DateTime now,
  });

  Future<int> enqueueBackfillBatch({
    required int engineVersion,
    required DateTime now,
    required int limit,
  });

  Future<bool> hasAvailable({
    required int engineVersion,
    required DateTime now,
  });
}

class DriftClassificationJobStore implements ClassificationJobStore {
  DriftClassificationJobStore(this._database);

  final ContextoDatabase _database;

  @override
  Future<bool> enqueueIfNeeded({
    required int mediaItemId,
    required int engineVersion,
    required DateTime now,
  }) {
    return _database.transaction(() async {
      final ocr = await (_database.select(
        _database.ocrResults,
      )..where((row) => row.mediaItemId.equals(mediaItemId))).getSingleOrNull();
      if (ocr == null) return false;

      final suggestion = await (_database.select(
        _database.classificationSuggestions,
      )..where((row) => row.mediaItemId.equals(mediaItemId))).getSingleOrNull();
      if (_isProtectedOrCurrent(suggestion, ocr.processedAt, engineVersion)) {
        await deleteForMediaItem(mediaItemId);
        return false;
      }

      final existing = await (_database.select(
        _database.classificationJobs,
      )..where((row) => row.mediaItemId.equals(mediaItemId))).getSingleOrNull();
      if (existing != null && existing.engineVersion == engineVersion) {
        if (existing.state != domain.ClassificationJobState.failed.name) {
          return false;
        }
        await (_database.update(
          _database.classificationJobs,
        )..where((row) => row.mediaItemId.equals(mediaItemId))).write(
          ClassificationJobsCompanion(
            state: Value(domain.ClassificationJobState.pending.name),
            attempts: const Value(0),
            availableAt: Value(now),
            updatedAt: Value(now),
            processingStartedAt: const Value(null),
            lastErrorCode: const Value(null),
          ),
        );
        return true;
      }
      if (existing != null) {
        await (_database.update(
          _database.classificationJobs,
        )..where((row) => row.mediaItemId.equals(mediaItemId))).write(
          ClassificationJobsCompanion(
            state: Value(domain.ClassificationJobState.pending.name),
            attempts: const Value(0),
            availableAt: Value(now),
            engineVersion: Value(engineVersion),
            updatedAt: Value(now),
            processingStartedAt: const Value(null),
            lastErrorCode: const Value(null),
          ),
        );
        return true;
      }

      final inserted = await _database
          .into(_database.classificationJobs)
          .insert(
            ClassificationJobsCompanion.insert(
              mediaItemId: Value(mediaItemId),
              state: domain.ClassificationJobState.pending.name,
              availableAt: now,
              engineVersion: engineVersion,
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      return inserted != 0;
    });
  }

  bool _isProtectedOrCurrent(
    ClassificationSuggestion? suggestion,
    DateTime ocrProcessedAt,
    int engineVersion,
  ) {
    if (suggestion == null) return false;
    if (suggestion.status !=
        ClassificationSuggestionStatus.pendingReview.name) {
      return true;
    }
    return suggestion.engineVersion == engineVersion &&
        !ocrProcessedAt.isAfter(suggestion.updatedAt);
  }

  @override
  Future<domain.ClassificationJob?> findByMediaItemId(int mediaItemId) async {
    final row = await (_database.select(
      _database.classificationJobs,
    )..where((job) => job.mediaItemId.equals(mediaItemId))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<domain.ClassificationJob?> claimNextAvailable({
    required DateTime now,
    required int engineVersion,
  }) {
    return _database.transaction(() async {
      final row =
          await (_database.select(_database.classificationJobs)
                ..where(
                  (job) =>
                      job.engineVersion.equals(engineVersion) &
                      job.availableAt.isSmallerOrEqualValue(now) &
                      (job.state.equals(
                            domain.ClassificationJobState.pending.name,
                          ) |
                          job.state.equals(
                            domain.ClassificationJobState.retryScheduled.name,
                          )),
                )
                ..orderBy([
                  (job) => OrderingTerm.asc(job.availableAt),
                  (job) => OrderingTerm.asc(job.createdAt),
                  (job) => OrderingTerm.asc(job.mediaItemId),
                ])
                ..limit(1))
              .getSingleOrNull();
      if (row == null) return null;

      final processingStartedAt = now;
      final changed =
          await (_database.update(_database.classificationJobs)..where(
                (job) =>
                    job.mediaItemId.equals(row.mediaItemId) &
                    job.state.equals(row.state) &
                    job.updatedAt.equals(row.updatedAt),
              ))
              .write(
                ClassificationJobsCompanion(
                  state: Value(domain.ClassificationJobState.processing.name),
                  attempts: Value(row.attempts + 1),
                  updatedAt: Value(now),
                  processingStartedAt: Value(processingStartedAt),
                  lastErrorCode: const Value(null),
                ),
              );
      if (changed != 1) return null;
      return domain.ClassificationJob(
        mediaItemId: row.mediaItemId,
        state: domain.ClassificationJobState.processing,
        attempts: row.attempts + 1,
        availableAt: row.availableAt,
        engineVersion: row.engineVersion,
        createdAt: row.createdAt,
        updatedAt: now,
        processingStartedAt: processingStartedAt,
      );
    });
  }

  @override
  Future<bool> deleteClaimed(domain.ClassificationJob job) async {
    final startedAt = job.processingStartedAt;
    if (startedAt == null) return false;
    final deleted =
        await (_database.delete(_database.classificationJobs)..where(
              (row) =>
                  row.mediaItemId.equals(job.mediaItemId) &
                  row.state.equals(
                    domain.ClassificationJobState.processing.name,
                  ) &
                  row.processingStartedAt.equals(startedAt),
            ))
            .go();
    return deleted == 1;
  }

  @override
  Future<void> deleteForMediaItem(int mediaItemId) async {
    await (_database.delete(
      _database.classificationJobs,
    )..where((job) => job.mediaItemId.equals(mediaItemId))).go();
  }

  @override
  Future<bool> scheduleRetry({
    required domain.ClassificationJob job,
    required DateTime availableAt,
    required DateTime updatedAt,
    required domain.ClassificationJobErrorCode errorCode,
  }) {
    return _writeClaimed(
      job,
      ClassificationJobsCompanion(
        state: Value(domain.ClassificationJobState.retryScheduled.name),
        availableAt: Value(availableAt),
        updatedAt: Value(updatedAt),
        processingStartedAt: const Value(null),
        lastErrorCode: Value(errorCode.name),
      ),
    );
  }

  @override
  Future<bool> markFailed({
    required domain.ClassificationJob job,
    required DateTime updatedAt,
    required domain.ClassificationJobErrorCode errorCode,
  }) {
    return _writeClaimed(
      job,
      ClassificationJobsCompanion(
        state: Value(domain.ClassificationJobState.failed.name),
        updatedAt: Value(updatedAt),
        processingStartedAt: const Value(null),
        lastErrorCode: Value(errorCode.name),
      ),
    );
  }

  Future<bool> _writeClaimed(
    domain.ClassificationJob job,
    ClassificationJobsCompanion values,
  ) async {
    final startedAt = job.processingStartedAt;
    if (startedAt == null) return false;
    final changed =
        await (_database.update(_database.classificationJobs)..where(
              (row) =>
                  row.mediaItemId.equals(job.mediaItemId) &
                  row.state.equals(
                    domain.ClassificationJobState.processing.name,
                  ) &
                  row.processingStartedAt.equals(startedAt),
            ))
            .write(values);
    return changed == 1;
  }

  @override
  Future<int> recoverExpired({
    required DateTime expiredBefore,
    required DateTime now,
  }) {
    return (_database.update(_database.classificationJobs)..where(
          (job) =>
              job.state.equals(domain.ClassificationJobState.processing.name) &
              job.processingStartedAt.isSmallerThanValue(expiredBefore),
        ))
        .write(
          ClassificationJobsCompanion(
            state: Value(domain.ClassificationJobState.pending.name),
            availableAt: Value(now),
            updatedAt: Value(now),
            processingStartedAt: const Value(null),
            lastErrorCode: const Value(null),
          ),
        );
  }

  @override
  Future<int> enqueueBackfillBatch({
    required int engineVersion,
    required DateTime now,
    required int limit,
  }) {
    return _database.transaction(() async {
      final candidates = await _database
          .customSelect(
            '''
        SELECT media_items.id AS media_item_id
        FROM media_items
        INNER JOIN ocr_results
          ON ocr_results.media_item_id = media_items.id
        LEFT JOIN classification_suggestions
          ON classification_suggestions.media_item_id = media_items.id
        LEFT JOIN classification_jobs
          ON classification_jobs.media_item_id = media_items.id
        WHERE (
            classification_jobs.media_item_id IS NULL
            OR classification_jobs.engine_version <> ?
          )
          AND (
            classification_suggestions.media_item_id IS NULL
            OR (
              classification_suggestions.status = 'pendingReview'
              AND (
                classification_suggestions.engine_version <> ?
                OR classification_suggestions.updated_at < ocr_results.processed_at
              )
            )
          )
        ORDER BY media_items.id
        LIMIT ?
        ''',
            variables: [
              Variable<int>(engineVersion),
              Variable<int>(engineVersion),
              Variable<int>(limit),
            ],
            readsFrom: {
              _database.mediaItems,
              _database.ocrResults,
              _database.classificationSuggestions,
              _database.classificationJobs,
            },
          )
          .get();
      var inserted = 0;
      for (final candidate in candidates) {
        final mediaItemId = candidate.read<int>('media_item_id');
        final existing =
            await (_database.select(_database.classificationJobs)
                  ..where((job) => job.mediaItemId.equals(mediaItemId)))
                .getSingleOrNull();
        if (existing != null) {
          if (existing.engineVersion == engineVersion) continue;
          final changed =
              await (_database.update(_database.classificationJobs)..where(
                    (job) =>
                        job.mediaItemId.equals(mediaItemId) &
                        job.engineVersion.equals(existing.engineVersion),
                  ))
                  .write(
                    ClassificationJobsCompanion(
                      state: Value(domain.ClassificationJobState.pending.name),
                      attempts: const Value(0),
                      availableAt: Value(now),
                      engineVersion: Value(engineVersion),
                      createdAt: Value(now),
                      updatedAt: Value(now),
                      processingStartedAt: const Value(null),
                      lastErrorCode: const Value(null),
                    ),
                  );
          if (changed == 1) inserted++;
          continue;
        }
        final result = await _database
            .into(_database.classificationJobs)
            .insert(
              ClassificationJobsCompanion.insert(
                mediaItemId: Value(mediaItemId),
                state: domain.ClassificationJobState.pending.name,
                availableAt: now,
                engineVersion: engineVersion,
                createdAt: now,
                updatedAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        if (result != 0) inserted++;
      }
      return inserted;
    });
  }

  @override
  Future<bool> hasAvailable({
    required int engineVersion,
    required DateTime now,
  }) async {
    final row =
        await (_database.selectOnly(_database.classificationJobs)
              ..addColumns([_database.classificationJobs.mediaItemId])
              ..where(
                _database.classificationJobs.engineVersion.equals(
                      engineVersion,
                    ) &
                    _database.classificationJobs.availableAt
                        .isSmallerOrEqualValue(now) &
                    (_database.classificationJobs.state.equals(
                          domain.ClassificationJobState.pending.name,
                        ) |
                        _database.classificationJobs.state.equals(
                          domain.ClassificationJobState.retryScheduled.name,
                        )),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  domain.ClassificationJob _toDomain(ClassificationJob row) {
    return domain.ClassificationJob(
      mediaItemId: row.mediaItemId,
      state: domain.ClassificationJobState.values.byName(row.state),
      attempts: row.attempts,
      availableAt: row.availableAt,
      engineVersion: row.engineVersion,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      processingStartedAt: row.processingStartedAt,
      lastErrorCode: row.lastErrorCode == null
          ? null
          : domain.ClassificationJobErrorCode.values.byName(row.lastErrorCode!),
    );
  }
}

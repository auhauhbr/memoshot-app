import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../../library/domain/media_item.dart' as domain_media;
import '../domain/processing_job.dart' as domain;

abstract interface class ProcessingJobStore {
  Future<bool> createOcrJobIfNeeded(int mediaItemId);

  Future<domain.ProcessingJob?> findOcrJob(int mediaItemId);

  Future<domain.ProcessingJob?> claimNextPendingOcr();

  Future<void> markCompleted(int jobId);

  Future<void> markFailed(int jobId, String errorCode);

  Future<void> resetForRetry(int mediaItemId);

  Future<List<int>> recoverInterruptedOcrJobs();

  Future<domain_media.MediaItem?> findMediaItem(int mediaItemId);

  Future<bool> mediaItemExists(int mediaItemId);

  Future<bool?> ocrResultHasText(int mediaItemId);
}

class DriftProcessingJobStore implements ProcessingJobStore {
  DriftProcessingJobStore(this._database);

  final ContextoDatabase _database;

  @override
  Future<bool> createOcrJobIfNeeded(int mediaItemId) {
    return _database.transaction(() async {
      final result = await (_database.select(
        _database.ocrResults,
      )..where((row) => row.mediaItemId.equals(mediaItemId))).getSingleOrNull();
      if (result != null) {
        return false;
      }

      final existing =
          await (_database.select(_database.processingJobs)..where(
                (job) =>
                    job.mediaItemId.equals(mediaItemId) &
                    job.jobType.equals('ocr'),
              ))
              .getSingleOrNull();
      if (existing != null) {
        return false;
      }

      await _database
          .into(_database.processingJobs)
          .insert(
            ProcessingJobsCompanion.insert(
              mediaItemId: mediaItemId,
              jobType: 'ocr',
              status: _statusValue(domain.ProcessingJobStatus.pending),
              createdAt: DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      return true;
    });
  }

  @override
  Future<domain.ProcessingJob?> findOcrJob(int mediaItemId) async {
    final row =
        await (_database.select(_database.processingJobs)..where(
              (job) =>
                  job.mediaItemId.equals(mediaItemId) &
                  job.jobType.equals('ocr'),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<domain.ProcessingJob?> claimNextPendingOcr() {
    return _database.transaction(() async {
      final row =
          await (_database.select(_database.processingJobs)
                ..where(
                  (job) =>
                      job.jobType.equals('ocr') &
                      job.status.equals(
                        _statusValue(domain.ProcessingJobStatus.pending),
                      ),
                )
                ..orderBy([(job) => OrderingTerm.asc(job.createdAt)])
                ..limit(1))
              .getSingleOrNull();
      if (row == null) {
        return null;
      }

      final startedAt = DateTime.now();
      final changed =
          await (_database.update(_database.processingJobs)..where(
                (job) =>
                    job.id.equals(row.id) &
                    job.status.equals(
                      _statusValue(domain.ProcessingJobStatus.pending),
                    ),
              ))
              .write(
                ProcessingJobsCompanion(
                  status: Value(
                    _statusValue(domain.ProcessingJobStatus.processing),
                  ),
                  attempts: Value(row.attempts + 1),
                  startedAt: Value(startedAt),
                  finishedAt: const Value(null),
                ),
              );
      if (changed != 1) {
        return null;
      }
      return domain.ProcessingJob(
        id: row.id,
        mediaItemId: row.mediaItemId,
        status: domain.ProcessingJobStatus.processing,
        attempts: row.attempts + 1,
        errorCode: row.errorCode,
        createdAt: row.createdAt,
        startedAt: startedAt,
      );
    });
  }

  @override
  Future<void> markCompleted(int jobId) async {
    await (_database.update(_database.processingJobs)..where(
          (job) =>
              job.id.equals(jobId) &
              job.status.equals(
                _statusValue(domain.ProcessingJobStatus.processing),
              ),
        ))
        .write(
          ProcessingJobsCompanion(
            status: Value(_statusValue(domain.ProcessingJobStatus.completed)),
            errorCode: const Value(null),
            finishedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> markFailed(int jobId, String errorCode) async {
    await (_database.update(
      _database.processingJobs,
    )..where((job) => job.id.equals(jobId))).write(
      ProcessingJobsCompanion(
        status: Value(_statusValue(domain.ProcessingJobStatus.failed)),
        errorCode: Value(errorCode),
        finishedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> resetForRetry(int mediaItemId) {
    return _database.transaction(() async {
      final existing = await findOcrJob(mediaItemId);
      if (existing?.status == domain.ProcessingJobStatus.processing ||
          existing?.status == domain.ProcessingJobStatus.pending) {
        return;
      }
      if (existing == null) {
        await _database
            .into(_database.processingJobs)
            .insert(
              ProcessingJobsCompanion.insert(
                mediaItemId: mediaItemId,
                jobType: 'ocr',
                status: _statusValue(domain.ProcessingJobStatus.pending),
                errorCode: const Value('manual_retry'),
                createdAt: DateTime.now(),
              ),
            );
        return;
      }
      await (_database.update(
        _database.processingJobs,
      )..where((job) => job.id.equals(existing.id))).write(
        ProcessingJobsCompanion(
          status: Value(_statusValue(domain.ProcessingJobStatus.pending)),
          errorCode: const Value('manual_retry'),
          startedAt: const Value(null),
          finishedAt: const Value(null),
        ),
      );
    });
  }

  @override
  Future<List<int>> recoverInterruptedOcrJobs() async {
    final interrupted =
        await (_database.select(_database.processingJobs)..where(
              (job) =>
                  job.jobType.equals('ocr') &
                  job.status.equals(
                    _statusValue(domain.ProcessingJobStatus.processing),
                  ),
            ))
            .get();
    if (interrupted.isEmpty) {
      return const [];
    }
    await (_database.update(_database.processingJobs)..where(
          (job) =>
              job.jobType.equals('ocr') &
              job.status.equals(
                _statusValue(domain.ProcessingJobStatus.processing),
              ),
        ))
        .write(
          ProcessingJobsCompanion(
            status: Value(_statusValue(domain.ProcessingJobStatus.pending)),
            startedAt: const Value(null),
            finishedAt: const Value(null),
          ),
        );
    return interrupted.map((job) => job.mediaItemId).toList(growable: false);
  }

  @override
  Future<domain_media.MediaItem?> findMediaItem(int mediaItemId) async {
    final row = await (_database.select(
      _database.mediaItems,
    )..where((item) => item.id.equals(mediaItemId))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return domain_media.MediaItem(
      id: row.id,
      privatePath: row.privatePath,
      internalName: row.internalName,
      mimeType: row.mimeType,
      mediaHash: row.mediaHash,
      importedAt: row.importedAt,
      capturedAt: row.capturedAt,
      sourceMode: row.sourceMode,
      status: row.status,
      importOrigin: domain_media.ImportOrigin.fromDatabase(row.importOrigin),
    );
  }

  @override
  Future<bool> mediaItemExists(int mediaItemId) async {
    final row =
        await (_database.selectOnly(_database.mediaItems)
              ..addColumns([_database.mediaItems.id])
              ..where(_database.mediaItems.id.equals(mediaItemId)))
            .getSingleOrNull();
    return row != null;
  }

  @override
  Future<bool?> ocrResultHasText(int mediaItemId) async {
    final row =
        await (_database.select(_database.ocrResults)
              ..where((result) => result.mediaItemId.equals(mediaItemId)))
            .getSingleOrNull();
    return row?.fullText.isNotEmpty;
  }

  domain.ProcessingJob _toDomain(ProcessingJob row) {
    return domain.ProcessingJob(
      id: row.id,
      mediaItemId: row.mediaItemId,
      status: domain.ProcessingJobStatus.values.byName(row.status),
      attempts: row.attempts,
      errorCode: row.errorCode,
      createdAt: row.createdAt,
      startedAt: row.startedAt,
      finishedAt: row.finishedAt,
    );
  }

  static String _statusValue(domain.ProcessingJobStatus status) => status.name;
}

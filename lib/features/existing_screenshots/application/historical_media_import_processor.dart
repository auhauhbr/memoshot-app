import 'dart:async';

import '../../library/data/media_item_repository.dart';
import '../../library/domain/media_item.dart';
import '../data/historical_media_import_job_store.dart';
import '../data/historical_preparation_settings_repository.dart';
import '../domain/existing_screenshot_candidate.dart';
import '../domain/historical_media_import_job.dart';

const historicalMediaProcessingExpiration = Duration(minutes: 10);
const historicalMediaMaximumBatchSize = 25;

class HistoricalMediaImportRetryPolicy {
  const HistoricalMediaImportRetryPolicy({
    this.delays = const [
      Duration(seconds: 15),
      Duration(minutes: 1),
      Duration(minutes: 5),
      Duration(minutes: 30),
    ],
    this.maximumAttempts = 5,
  });

  final List<Duration> delays;
  final int maximumAttempts;

  Duration? delayAfterFailure(int attempts) {
    if (attempts >= maximumAttempts) return null;
    final index = attempts - 1;
    return index >= 0 && index < delays.length ? delays[index] : null;
  }
}

class HistoricalMediaImportRunSummary {
  const HistoricalMediaImportRunSummary({
    required this.processedCount,
    required this.preparedCount,
    required this.hasImmediateWork,
    this.nextAvailableAt,
  });

  final int processedCount;
  final int preparedCount;
  final bool hasImmediateWork;
  final DateTime? nextAvailableAt;
}

abstract interface class HeadlessHistoricalMediaImportQueue {
  Future<int> recoverInterrupted();

  Future<HistoricalMediaImportRunSummary> processAvailable({
    required int maximumItems,
  });
}

abstract interface class HistoricalMediaImportQueue
    implements HeadlessHistoricalMediaImportQueue {
  Stream<void> get changes;

  void signal();

  Future<void> close();
}

class LocalHistoricalMediaImportProcessor
    implements HistoricalMediaImportQueue {
  LocalHistoricalMediaImportProcessor({
    required HistoricalMediaImportJobStore jobStore,
    required MediaStoreReferenceMediaItemRepository mediaRepository,
    required HistoricalPreparationSettingsRepository settingsRepository,
    DateTime Function() now = DateTime.now,
    HistoricalMediaImportRetryPolicy retryPolicy =
        const HistoricalMediaImportRetryPolicy(),
    Duration processingExpiration = historicalMediaProcessingExpiration,
    int maximumBatchSize = historicalMediaMaximumBatchSize,
  }) : this._(
         jobStore,
         mediaRepository,
         settingsRepository,
         now,
         retryPolicy,
         processingExpiration,
         maximumBatchSize,
       );

  LocalHistoricalMediaImportProcessor._(
    this._jobStore,
    this._mediaRepository,
    this._settingsRepository,
    this._now,
    this.retryPolicy,
    this.processingExpiration,
    this.maximumBatchSize,
  );

  final HistoricalMediaImportJobStore _jobStore;
  final MediaStoreReferenceMediaItemRepository _mediaRepository;
  final HistoricalPreparationSettingsRepository _settingsRepository;
  final DateTime Function() _now;
  final HistoricalMediaImportRetryPolicy retryPolicy;
  final Duration processingExpiration;
  final int maximumBatchSize;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Future<void>? _draining;
  bool _signalRequested = false;
  bool _closed = false;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<int> recoverInterrupted() {
    final now = _now();
    return _jobStore.recoverExpired(
      expiredBefore: now.subtract(processingExpiration),
      now: now,
    );
  }

  @override
  void signal() {
    if (_closed) return;
    if (_draining != null) {
      _signalRequested = true;
      return;
    }
    final drain = _runDrain();
    _draining = drain;
    unawaited(
      drain.whenComplete(() {
        _draining = null;
        if (_signalRequested) {
          _signalRequested = false;
          signal();
        }
      }),
    );
  }

  Future<void> _runDrain() async {
    try {
      await recoverInterrupted();
      final summary = await processAvailable(maximumItems: maximumBatchSize);
      if (!_closed && summary.hasImmediateWork) {
        _signalRequested = true;
      }
    } catch (_) {
      // A fila permanece durável para a próxima retomada.
    }
  }

  @override
  Future<HistoricalMediaImportRunSummary> processAvailable({
    required int maximumItems,
  }) async {
    if (_closed || maximumItems <= 0) {
      return const HistoricalMediaImportRunSummary(
        processedCount: 0,
        preparedCount: 0,
        hasImmediateWork: false,
      );
    }
    if (await _settingsRepository.load() != HistoricalPreparationState.active) {
      return const HistoricalMediaImportRunSummary(
        processedCount: 0,
        preparedCount: 0,
        hasImmediateWork: false,
      );
    }

    await _jobStore.enqueueAvailableBatch(now: _now());
    var processed = 0;
    var prepared = 0;
    while (!_closed && processed < maximumItems) {
      if (await _settingsRepository.load() !=
          HistoricalPreparationState.active) {
        break;
      }
      final job = await _jobStore.claimNextAvailable(now: _now());
      if (job == null) break;
      processed++;
      if (await _process(job)) prepared++;
    }
    final hasImmediateWork =
        await _jobStore.hasAvailable(_now()) ||
        await _jobStore.hasUnqueuedCandidates();
    final nextAvailableAt = await _jobStore.nextRetryAt();
    if (!hasImmediateWork && nextAvailableAt == null) {
      final progress = await _jobStore.loadProgress(
        state: HistoricalPreparationState.active,
      );
      if (progress.preparedCount >= progress.availableCount &&
          progress.failedCount == 0) {
        await _settingsRepository.complete();
      }
    }
    if (!_closed && processed > 0) _changes.add(null);
    return HistoricalMediaImportRunSummary(
      processedCount: processed,
      preparedCount: prepared,
      hasImmediateWork: hasImmediateWork,
      nextAvailableAt: nextAvailableAt,
    );
  }

  Future<bool> _process(HistoricalMediaImportJob job) async {
    try {
      final candidate = await _jobStore.loadCandidate(job.sourceKey);
      if (candidate == null) {
        await _terminal(job, HistoricalMediaImportErrorCode.candidateMissing);
        return false;
      }
      if (candidate.availability != ExistingScreenshotAvailability.available) {
        await _terminal(
          job,
          HistoricalMediaImportErrorCode.candidateUnavailable,
        );
        return false;
      }

      final existing = await _mediaRepository.loadBySourceKey(job.sourceKey);
      if (existing == null) {
        final location = MediaStoreReferenceLocation(
          sourceKey: candidate.sourceKey,
          mediaStoreId: candidate.mediaStoreId,
          volumeName: candidate.volumeName,
          contentUri: candidate.contentUri,
          dateModified: candidate.dateModified,
        );
        await _mediaRepository.createMediaStoreReference(
          location: location,
          mimeType: candidate.mimeType,
          capturedAt: candidate.capturedAt,
        );
      }
      return await _jobStore.deleteClaimed(job);
    } on ArgumentError {
      await _terminal(job, HistoricalMediaImportErrorCode.invalidReference);
      return false;
    } catch (_) {
      await _retry(job, HistoricalMediaImportErrorCode.mediaPersistenceFailure);
      return false;
    }
  }

  Future<void> _terminal(
    HistoricalMediaImportJob job,
    HistoricalMediaImportErrorCode errorCode,
  ) async {
    await _jobStore.markFailed(
      job: job,
      updatedAt: _now(),
      errorCode: errorCode,
    );
  }

  Future<void> _retry(
    HistoricalMediaImportJob job,
    HistoricalMediaImportErrorCode errorCode,
  ) async {
    final now = _now();
    final delay = retryPolicy.delayAfterFailure(job.attempts);
    if (delay == null) {
      await _jobStore.markFailed(
        job: job,
        updatedAt: now,
        errorCode: errorCode,
      );
    } else {
      await _jobStore.scheduleRetry(
        job: job,
        availableAt: now.add(delay),
        updatedAt: now,
        errorCode: errorCode,
      );
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _draining;
    await _changes.close();
  }
}

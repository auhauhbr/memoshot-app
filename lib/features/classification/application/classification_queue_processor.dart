import 'dart:async';

import '../../library/data/media_item_repository.dart';
import '../../library/domain/media_item.dart';
import '../../ocr/data/ocr_repository.dart';
import '../data/classification_job_store.dart';
import '../data/classification_suggestion_repository.dart';
import '../domain/classification_job.dart';
import '../domain/stored_classification_suggestion.dart';
import 'classification_processor.dart';

const classificationProcessingExpiration = Duration(minutes: 10);
const classificationBackfillBatchSize = 25;
const classificationQueueMaximumBatchSize = 10;

class ClassificationRetryPolicy {
  const ClassificationRetryPolicy({
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
    if (index < 0 || index >= delays.length) return null;
    return delays[index];
  }
}

abstract interface class ClassificationJobScheduler {
  Future<bool> schedule(int mediaItemId);
}

class LocalClassificationJobScheduler implements ClassificationJobScheduler {
  const LocalClassificationJobScheduler({
    required ClassificationJobStore store,
    required int engineVersion,
    required DateTime Function() now,
  }) : this._(store, engineVersion, now);

  const LocalClassificationJobScheduler._(
    this._store,
    this._engineVersion,
    this._now,
  );

  final ClassificationJobStore _store;
  final int _engineVersion;
  final DateTime Function() _now;

  @override
  Future<bool> schedule(int mediaItemId) {
    return _store.enqueueIfNeeded(
      mediaItemId: mediaItemId,
      engineVersion: _engineVersion,
      now: _now(),
    );
  }
}

abstract interface class ClassificationQueue {
  Stream<int> get changes;

  Future<void> recoverAndStart();

  void signal();

  Future<void> close();
}

class ClassificationQueueRunSummary {
  const ClassificationQueueRunSummary({
    required this.processedCount,
    required this.backfillCount,
    required this.hasImmediateWork,
  });

  final int processedCount;
  final int backfillCount;
  final bool hasImmediateWork;
}

abstract interface class HeadlessClassificationQueue {
  Future<int> recoverInterrupted();

  Future<ClassificationQueueRunSummary> processAvailable({
    required int maximumItems,
    required bool enqueueBackfill,
  });
}

class LocalClassificationQueueProcessor
    implements
        ClassificationQueue,
        HeadlessClassificationQueue,
        IndividualClassificationReprocessor {
  LocalClassificationQueueProcessor({
    required ClassificationJobStore jobStore,
    required ClassificationProcessor classificationProcessor,
    required ClassificationSuggestionRepository suggestionRepository,
    required MediaItemRepository mediaRepository,
    required OcrRepository ocrRepository,
    required DateTime Function() now,
    int engineVersion = currentClassificationEngineVersion,
    ClassificationRetryPolicy retryPolicy = const ClassificationRetryPolicy(),
    int maximumBatchSize = classificationQueueMaximumBatchSize,
    int backfillBatchSize = classificationBackfillBatchSize,
    Duration processingExpiration = classificationProcessingExpiration,
  }) : this._(
         jobStore,
         classificationProcessor,
         suggestionRepository,
         mediaRepository,
         ocrRepository,
         now,
         engineVersion,
         retryPolicy,
         maximumBatchSize,
         backfillBatchSize,
         processingExpiration,
       );

  LocalClassificationQueueProcessor._(
    this._jobStore,
    this._classificationProcessor,
    this._suggestionRepository,
    this._mediaRepository,
    this._ocrRepository,
    this._now,
    this.engineVersion,
    this.retryPolicy,
    this.maximumBatchSize,
    this.backfillBatchSize,
    this.processingExpiration,
  );

  final ClassificationJobStore _jobStore;
  final ClassificationProcessor _classificationProcessor;
  final ClassificationSuggestionRepository _suggestionRepository;
  final MediaItemRepository _mediaRepository;
  final OcrRepository _ocrRepository;
  final DateTime Function() _now;
  final int engineVersion;
  final ClassificationRetryPolicy retryPolicy;
  final int maximumBatchSize;
  final int backfillBatchSize;
  final Duration processingExpiration;
  final StreamController<int> _changes = StreamController<int>.broadcast();
  Future<void>? _draining;
  bool _signalRequested = false;
  bool _closed = false;

  @override
  Stream<int> get changes => _changes.stream;

  @override
  Future<void> recoverAndStart() async {
    try {
      await recoverInterrupted();
    } catch (_) {
      // A fila de classificação não pode impedir a abertura do aplicativo.
    } finally {
      signal();
    }
  }

  @override
  Future<IndividualReprocessResult> reprocess(MediaItem mediaItem) {
    final processor = _classificationProcessor;
    if (processor is! IndividualClassificationReprocessor) {
      throw StateError('Reprocessamento individual indisponível.');
    }
    return (processor as IndividualClassificationReprocessor).reprocess(
      mediaItem,
    );
  }

  @override
  Future<int> recoverInterrupted() async {
    final now = _now();
    return _jobStore.recoverExpired(
      expiredBefore: now.subtract(processingExpiration),
      now: now,
    );
  }

  Future<int> _enqueueBackfill(int limit) {
    return _jobStore.enqueueBackfillBatch(
      engineVersion: engineVersion,
      now: _now(),
      limit: limit,
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
      await _drain();
    } catch (_) {
      // Uma falha da coordenação não encerra o aplicativo.
    }
  }

  Future<void> _drain() async {
    await recoverInterrupted();
    await _processAvailable(maximumBatchSize);
  }

  Future<int> _processAvailable(int maximumItems) async {
    var processed = 0;
    while (!_closed && processed < maximumItems) {
      final job = await _jobStore.claimNextAvailable(
        now: _now(),
        engineVersion: engineVersion,
      );
      if (job == null) return processed;
      processed++;
      await _process(job);
    }
    return processed;
  }

  @override
  Future<ClassificationQueueRunSummary> processAvailable({
    required int maximumItems,
    required bool enqueueBackfill,
  }) async {
    if (_closed || maximumItems <= 0) {
      return const ClassificationQueueRunSummary(
        processedCount: 0,
        backfillCount: 0,
        hasImmediateWork: false,
      );
    }
    final backfillCount = enqueueBackfill
        ? await _enqueueBackfill(maximumItems)
        : 0;
    final processedCount = await _processAvailable(maximumItems);
    final availableJob = await _jobStore.hasAvailable(
      engineVersion: engineVersion,
      now: _now(),
    );
    return ClassificationQueueRunSummary(
      processedCount: processedCount,
      backfillCount: backfillCount,
      hasImmediateWork:
          availableJob || (enqueueBackfill && backfillCount >= maximumItems),
    );
  }

  Future<void> _process(ClassificationJob job) async {
    try {
      final mediaItem = await _mediaRepository.loadById(job.mediaItemId);
      if (mediaItem == null) {
        await _jobStore.deleteClaimed(job);
        return;
      }
      final ocrResult = await _ocrRepository.loadFor(job.mediaItemId);
      if (ocrResult == null) {
        await _jobStore.deleteClaimed(job);
        return;
      }
      final existing = await _suggestionRepository.loadByMediaItemId(
        job.mediaItemId,
      );
      if (_isProtectedOrCurrent(existing, ocrResult.processedAt)) {
        await _jobStore.deleteClaimed(job);
        return;
      }

      await _classificationProcessor.process(
        mediaItem: mediaItem,
        ocrResult: ocrResult,
      );
      if (await _jobStore.deleteClaimed(job)) {
        _notify(job.mediaItemId);
      }
    } catch (_) {
      await _handleFailure(job, ClassificationJobErrorCode.processorFailure);
    }
  }

  bool _isProtectedOrCurrent(
    StoredClassificationSuggestion? suggestion,
    DateTime ocrProcessedAt,
  ) {
    if (suggestion == null) return false;
    if (suggestion.status != ClassificationSuggestionStatus.pendingReview) {
      return true;
    }
    return suggestion.engineVersion == engineVersion &&
        !ocrProcessedAt.isAfter(suggestion.updatedAt);
  }

  Future<void> _handleFailure(
    ClassificationJob job,
    ClassificationJobErrorCode errorCode,
  ) async {
    try {
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
    } catch (_) {
      // O job continua durável para recuperação em uma execução posterior.
    }
  }

  void _notify(int mediaItemId) {
    if (!_closed) _changes.add(mediaItemId);
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _draining;
    final processor = _classificationProcessor;
    if (processor is ClosableClassificationProcessor) {
      await (processor as ClosableClassificationProcessor).close();
    }
    await _changes.close();
  }
}

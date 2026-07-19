import 'dart:async';
import 'dart:io';

import '../../../core/ocr/text_recognition_service.dart';
import '../../classification/application/classification_queue_processor.dart';
import '../../library/domain/media_item.dart';
import '../../ocr/data/ocr_result_store.dart';
import '../../ocr/domain/ocr_result.dart';
import '../domain/processing_job.dart';
import 'processing_job_store.dart';

const ocrProcessingExpiration = Duration(minutes: 10);

abstract interface class OcrQueue {
  Stream<int> get changes;

  Future<OcrItemState> loadState(int mediaItemId);

  Future<void> recoverAndStart();

  void signal();

  Future<void> retry(MediaItem mediaItem);

  Future<void> close();
}

class OcrQueueRunSummary {
  const OcrQueueRunSummary({
    required this.processedCount,
    required this.hasImmediateWork,
  });

  final int processedCount;
  final bool hasImmediateWork;
}

abstract interface class HeadlessOcrQueue {
  Future<int> recoverInterrupted();

  Future<OcrQueueRunSummary> processAvailable({required int maximumItems});
}

class LocalOcrQueueProcessor implements OcrQueue, HeadlessOcrQueue {
  LocalOcrQueueProcessor({
    required ProcessingJobStore jobStore,
    required OcrResultStore resultStore,
    required TextRecognitionService recognitionService,
    ClassificationJobScheduler? classificationJobScheduler,
    ClassificationQueue? classificationQueue,
    DateTime Function() now = DateTime.now,
    Duration processingExpiration = ocrProcessingExpiration,
  }) : this._(
         jobStore,
         resultStore,
         recognitionService,
         classificationJobScheduler,
         classificationQueue,
         now,
         processingExpiration,
       );

  LocalOcrQueueProcessor._(
    this._jobStore,
    this._resultStore,
    this._recognitionService,
    this._classificationJobScheduler,
    this._classificationQueue,
    this._now,
    this._processingExpiration,
  );

  final ProcessingJobStore _jobStore;
  final OcrResultStore _resultStore;
  final TextRecognitionService _recognitionService;
  final ClassificationJobScheduler? _classificationJobScheduler;
  final ClassificationQueue? _classificationQueue;
  final DateTime Function() _now;
  final Duration _processingExpiration;
  final StreamController<int> _changes = StreamController<int>.broadcast();
  Future<void>? _draining;
  bool _signalRequested = false;
  bool _closed = false;

  @override
  Stream<int> get changes => _changes.stream;

  @override
  Future<OcrItemState> loadState(int mediaItemId) async {
    final job = await _jobStore.findOcrJob(mediaItemId);
    final hasText = await _jobStore.ocrResultHasText(mediaItemId);
    if (job == null) {
      if (hasText == null) {
        return OcrItemState.notScheduled;
      }
      return hasText
          ? OcrItemState.completedWithText
          : OcrItemState.completedWithoutText;
    }
    return switch (job.status) {
      ProcessingJobStatus.pending => OcrItemState.pending,
      ProcessingJobStatus.processing => OcrItemState.processing,
      ProcessingJobStatus.failed => OcrItemState.failed,
      ProcessingJobStatus.completed =>
        hasText == true
            ? OcrItemState.completedWithText
            : OcrItemState.completedWithoutText,
    };
  }

  @override
  Future<void> recoverAndStart() async {
    try {
      await recoverInterrupted();
      signal();
    } catch (_) {
      // A recuperação da fila não pode impedir a abertura do aplicativo.
    }
  }

  @override
  Future<int> recoverInterrupted() async {
    final recovered = await _jobStore.recoverInterruptedOcrJobs(
      startedBefore: _now().subtract(_processingExpiration),
    );
    for (final mediaItemId in recovered) {
      _notify(mediaItemId);
    }
    return recovered.length;
  }

  @override
  void signal() {
    if (_closed) {
      return;
    }
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
      // Uma falha pontual da fila não pode encerrar o aplicativo.
    }
  }

  Future<int> _drain({int? maximumItems}) async {
    var processed = 0;
    while (!_closed && (maximumItems == null || processed < maximumItems)) {
      final job = await _jobStore.claimNextPendingOcr();
      if (job == null) {
        return processed;
      }
      processed++;
      _notify(job.mediaItemId);
      await _process(job);
    }
    return processed;
  }

  @override
  Future<OcrQueueRunSummary> processAvailable({
    required int maximumItems,
  }) async {
    if (_closed || maximumItems <= 0) {
      return const OcrQueueRunSummary(
        processedCount: 0,
        hasImmediateWork: false,
      );
    }
    final processed = await _drain(maximumItems: maximumItems);
    return OcrQueueRunSummary(
      processedCount: processed,
      hasImmediateWork: await _jobStore.hasPendingOcrJobs(),
    );
  }

  Future<void> _process(ProcessingJob job) async {
    try {
      final existing = await _resultStore.findByMediaItemId(job.mediaItemId);
      if (existing != null && job.errorCode != 'manual_retry') {
        if (!await _ensureClassificationJob(job.mediaItemId)) return;
        if (!await _jobStore.mediaItemExists(job.mediaItemId)) return;
        await _jobStore.markCompleted(job.id);
        _notify(job.mediaItemId);
        return;
      }

      final mediaItem = await _jobStore.findMediaItem(job.mediaItemId);
      if (mediaItem == null) {
        return;
      }
      if (!await File(mediaItem.privatePath).exists()) {
        await _jobStore.markFailed(job.id, 'file_unavailable');
        _notify(job.mediaItemId);
        return;
      }

      final output = await _recognitionService.recognize(mediaItem.privatePath);
      if (!await _jobStore.mediaItemExists(job.mediaItemId)) {
        return;
      }
      final ocrResult = OcrResult(
        mediaItemId: job.mediaItemId,
        fullText: output.fullText,
        engine: output.engine,
        engineVersion: output.engineVersion,
        processedAt: DateTime.now(),
      );
      await _resultStore.save(ocrResult);
      if (!await _jobStore.mediaItemExists(job.mediaItemId)) {
        return;
      }
      if (!await _ensureClassificationJob(job.mediaItemId)) return;
      if (!await _jobStore.mediaItemExists(job.mediaItemId)) {
        return;
      }
      await _jobStore.markCompleted(job.id);
      _notify(job.mediaItemId);
    } catch (_) {
      try {
        await _jobStore.markFailed(job.id, 'ocr_failed');
        _notify(job.mediaItemId);
      } catch (_) {
        // O item pode ter sido removido durante o processamento.
      }
    }
  }

  Future<bool> _ensureClassificationJob(int mediaItemId) async {
    try {
      await _classificationJobScheduler?.schedule(mediaItemId);
      _classificationQueue?.signal();
      return true;
    } catch (_) {
      // Mantém o job OCR recuperável. Na retomada, o resultado persistido é
      // reutilizado e o reconhecedor não é executado novamente.
      return false;
    }
  }

  @override
  Future<void> retry(MediaItem mediaItem) async {
    if (_closed || !await _jobStore.mediaItemExists(mediaItem.id)) {
      return;
    }
    await _jobStore.resetForRetry(mediaItem.id);
    _notify(mediaItem.id);
    signal();
  }

  void _notify(int mediaItemId) {
    if (!_closed) {
      _changes.add(mediaItemId);
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _draining;
    await _changes.close();
  }
}

import 'dart:async';
import 'dart:io';

import '../../../core/ocr/text_recognition_service.dart';
import '../../classification/application/classification_processor.dart';
import '../../library/domain/media_item.dart';
import '../../ocr/data/ocr_result_store.dart';
import '../../ocr/domain/ocr_result.dart';
import '../domain/processing_job.dart';
import 'processing_job_store.dart';

abstract interface class OcrQueue {
  Stream<int> get changes;

  Future<OcrItemState> loadState(int mediaItemId);

  Future<void> recoverAndStart();

  void signal();

  Future<void> retry(MediaItem mediaItem);

  Future<void> close();
}

class LocalOcrQueueProcessor implements OcrQueue {
  LocalOcrQueueProcessor({
    required ProcessingJobStore jobStore,
    required OcrResultStore resultStore,
    required TextRecognitionService recognitionService,
    ClassificationProcessor? classificationProcessor,
  }) : this._(
         jobStore,
         resultStore,
         recognitionService,
         classificationProcessor,
       );

  LocalOcrQueueProcessor._(
    this._jobStore,
    this._resultStore,
    this._recognitionService,
    this._classificationProcessor,
  );

  final ProcessingJobStore _jobStore;
  final OcrResultStore _resultStore;
  final TextRecognitionService _recognitionService;
  final ClassificationProcessor? _classificationProcessor;
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
      final recovered = await _jobStore.recoverInterruptedOcrJobs();
      for (final mediaItemId in recovered) {
        _notify(mediaItemId);
      }
      signal();
    } catch (_) {
      // A recuperação da fila não pode impedir a abertura do aplicativo.
    }
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

  Future<void> _drain() async {
    while (!_closed) {
      final job = await _jobStore.claimNextPendingOcr();
      if (job == null) {
        return;
      }
      _notify(job.mediaItemId);
      await _process(job);
    }
  }

  Future<void> _process(ProcessingJob job) async {
    try {
      final existing = await _resultStore.findByMediaItemId(job.mediaItemId);
      if (existing != null && job.errorCode != 'manual_retry') {
        final mediaItem = await _jobStore.findMediaItem(job.mediaItemId);
        if (mediaItem == null) return;
        await _classifySafely(mediaItem, existing);
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
      await _classifySafely(mediaItem, ocrResult);
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

  Future<void> _classifySafely(MediaItem mediaItem, OcrResult ocrResult) async {
    try {
      await _classificationProcessor?.process(
        mediaItem: mediaItem,
        ocrResult: ocrResult,
      );
    } catch (_) {
      // A classificação é isolada: OCR concluído e fila seguem preservados.
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

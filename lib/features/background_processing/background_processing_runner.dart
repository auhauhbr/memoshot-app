import 'dart:io';

import '../../core/automatic_import/automatic_screenshot_source.dart';
import '../automatic_import/data/automatic_import_settings_repository.dart';
import '../classification/application/classification_queue_processor.dart';
import '../library/data/media_item_repository.dart';
import '../library/domain/media_item.dart';
import '../library/domain/selected_screenshot.dart';
import '../processing/data/ocr_queue_processor.dart';

const backgroundMaximumCycles = 5;
const backgroundMaximumItemsPerCycle = 10;
const backgroundMaximumRunDuration = Duration(minutes: 8);

enum BackgroundProcessingResultCode {
  completed,
  disabled,
  cancelled,
  timeLimitReached,
  cycleLimitReached,
}

class BackgroundProcessingSummary {
  const BackgroundProcessingSummary({
    required this.importedCount,
    required this.ocrProcessedCount,
    required this.classificationProcessedCount,
    required this.pendingImmediateWork,
    required this.resultCode,
  });

  final int importedCount;
  final int ocrProcessedCount;
  final int classificationProcessedCount;
  final bool pendingImmediateWork;
  final BackgroundProcessingResultCode resultCode;

  Map<String, Object> toChannelPayload() => <String, Object>{
    'importedCount': importedCount,
    'ocrProcessedCount': ocrProcessedCount,
    'classificationProcessedCount': classificationProcessedCount,
    'pendingImmediateWork': pendingImmediateWork ? 1 : 0,
    'resultCode': resultCode.name,
  };
}

class BackgroundProcessingRunner {
  BackgroundProcessingRunner({
    required AutomaticImportSettingsRepository settingsRepository,
    required AutomaticScreenshotSource inboxSource,
    required MediaItemRepository mediaRepository,
    required HeadlessOcrQueue ocrQueue,
    required HeadlessClassificationQueue classificationQueue,
    DateTime Function() now = DateTime.now,
    bool Function() isCancelled = _neverCancelled,
    int maximumCycles = backgroundMaximumCycles,
    int maximumItemsPerCycle = backgroundMaximumItemsPerCycle,
    Duration maximumDuration = backgroundMaximumRunDuration,
  }) : this._(
         settingsRepository,
         inboxSource,
         mediaRepository,
         ocrQueue,
         classificationQueue,
         now,
         isCancelled,
         maximumCycles,
         maximumItemsPerCycle,
         maximumDuration,
       );

  BackgroundProcessingRunner._(
    this._settingsRepository,
    this._inboxSource,
    this._mediaRepository,
    this._ocrQueue,
    this._classificationQueue,
    this._now,
    this._isCancelled,
    this.maximumCycles,
    this.maximumItemsPerCycle,
    this.maximumDuration,
  );

  final AutomaticImportSettingsRepository _settingsRepository;
  final AutomaticScreenshotSource _inboxSource;
  final MediaItemRepository _mediaRepository;
  final HeadlessOcrQueue _ocrQueue;
  final HeadlessClassificationQueue _classificationQueue;
  final DateTime Function() _now;
  final bool Function() _isCancelled;
  final int maximumCycles;
  final int maximumItemsPerCycle;
  final Duration maximumDuration;

  Future<BackgroundProcessingSummary> run() async {
    final startedAt = _now();
    var importedCount = 0;
    var ocrProcessedCount = 0;
    var classificationProcessedCount = 0;

    if (!await _isAutomationEnabled()) {
      return _summary(
        importedCount,
        ocrProcessedCount,
        classificationProcessedCount,
        false,
        BackgroundProcessingResultCode.disabled,
      );
    }

    await _ocrQueue.recoverInterrupted();
    await _classificationQueue.recoverInterrupted();

    for (var cycle = 0; cycle < maximumCycles; cycle++) {
      final stopCode = await _stopCode(startedAt);
      if (stopCode != null) {
        return _summary(
          importedCount,
          ocrProcessedCount,
          classificationProcessedCount,
          true,
          stopCode,
        );
      }

      importedCount += await _consumeInbox(maximumItemsPerCycle);

      final ocr = await _ocrQueue.processAvailable(
        maximumItems: maximumItemsPerCycle,
      );
      ocrProcessedCount += ocr.processedCount;

      final classification = await _classificationQueue.processAvailable(
        maximumItems: maximumItemsPerCycle,
        enqueueBackfill: true,
      );
      classificationProcessedCount += classification.processedCount;

      final inboxPending = await _inboxSource.backgroundInboxPendingCount() > 0;
      final immediateWork =
          inboxPending ||
          ocr.hasImmediateWork ||
          classification.hasImmediateWork;
      if (!immediateWork) {
        return _summary(
          importedCount,
          ocrProcessedCount,
          classificationProcessedCount,
          false,
          BackgroundProcessingResultCode.completed,
        );
      }
    }

    return _summary(
      importedCount,
      ocrProcessedCount,
      classificationProcessedCount,
      true,
      BackgroundProcessingResultCode.cycleLimitReached,
    );
  }

  Future<int> _consumeInbox(int limit) async {
    final entries = await _inboxSource.loadBackgroundInbox();
    var imported = 0;
    for (final entry in entries.take(limit)) {
      if (_isCancelled() || !await _isAutomationEnabled()) break;
      if (!await File(entry.privatePath).exists()) {
        try {
          await _inboxSource.rejectBackgroundEntry(entry.entryId);
        } catch (_) {
          // A entrada continua isolada e recuperável.
        }
        continue;
      }
      try {
        final result = await _mediaRepository.importScreenshots([
          SelectedScreenshot(
            path: entry.privatePath,
            mimeType: entry.mimeType,
            capturedAt: entry.capturedAt,
          ),
        ], origin: ImportOrigin.automatic);
        imported += result.importedItems.length;
        if (result.importedItems.isNotEmpty || result.duplicateCount > 0) {
          await _inboxSource.acknowledgeBackgroundEntry(entry.entryId);
        }
      } catch (_) {
        // Uma entrada com falha não bloqueia as demais e permanece durável.
      }
    }
    return imported;
  }

  Future<BackgroundProcessingResultCode?> _stopCode(DateTime startedAt) async {
    if (_isCancelled()) return BackgroundProcessingResultCode.cancelled;
    if (_now().difference(startedAt) >= maximumDuration) {
      return BackgroundProcessingResultCode.timeLimitReached;
    }
    if (!await _isAutomationEnabled()) {
      return BackgroundProcessingResultCode.disabled;
    }
    return null;
  }

  Future<bool> _isAutomationEnabled() async =>
      (await _settingsRepository.load()).enabled;

  BackgroundProcessingSummary _summary(
    int imported,
    int ocr,
    int classification,
    bool pending,
    BackgroundProcessingResultCode code,
  ) {
    return BackgroundProcessingSummary(
      importedCount: imported,
      ocrProcessedCount: ocr,
      classificationProcessedCount: classification,
      pendingImmediateWork: pending,
      resultCode: code,
    );
  }
}

bool _neverCancelled() => false;

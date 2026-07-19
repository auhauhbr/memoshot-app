import 'dart:io';

import '../../core/automatic_import/automatic_screenshot_source.dart';
import '../automatic_import/data/automatic_import_settings_repository.dart';
import '../classification/application/classification_queue_processor.dart';
import '../existing_screenshots/application/historical_media_import_processor.dart';
import '../existing_screenshots/data/historical_preparation_settings_repository.dart';
import '../existing_screenshots/domain/historical_media_import_job.dart';
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
    this.historicalPreparedCount = 0,
    this.nextHistoricalRunAt,
    required this.pendingImmediateWork,
    required this.resultCode,
  });

  final int importedCount;
  final int ocrProcessedCount;
  final int classificationProcessedCount;
  final int historicalPreparedCount;
  final DateTime? nextHistoricalRunAt;
  final bool pendingImmediateWork;
  final BackgroundProcessingResultCode resultCode;

  Map<String, Object> toChannelPayload() => <String, Object>{
    'importedCount': importedCount,
    'ocrProcessedCount': ocrProcessedCount,
    'classificationProcessedCount': classificationProcessedCount,
    'historicalPreparedCount': historicalPreparedCount,
    if (nextHistoricalRunAt != null)
      'nextHistoricalRunAtMillis': nextHistoricalRunAt!.millisecondsSinceEpoch,
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
    HeadlessHistoricalMediaImportQueue? historicalQueue,
    HistoricalPreparationSettingsRepository? historicalSettingsRepository,
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
         historicalQueue,
         historicalSettingsRepository,
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
    this._historicalQueue,
    this._historicalSettingsRepository,
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
  final HeadlessHistoricalMediaImportQueue? _historicalQueue;
  final HistoricalPreparationSettingsRepository? _historicalSettingsRepository;
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
    var historicalPreparedCount = 0;
    DateTime? nextHistoricalRunAt;

    final automationEnabled = await _isAutomationEnabled();
    final historicalActive = await _isHistoricalPreparationActive();
    if (!automationEnabled && !historicalActive) {
      return _summary(
        importedCount,
        ocrProcessedCount,
        classificationProcessedCount,
        historicalPreparedCount,
        nextHistoricalRunAt,
        false,
        BackgroundProcessingResultCode.disabled,
      );
    }

    if (automationEnabled) {
      await _ocrQueue.recoverInterrupted();
      await _classificationQueue.recoverInterrupted();
    }
    if (historicalActive) await _historicalQueue?.recoverInterrupted();

    for (var cycle = 0; cycle < maximumCycles; cycle++) {
      final stopCode = await _stopCode(startedAt);
      if (stopCode != null) {
        return _summary(
          importedCount,
          ocrProcessedCount,
          classificationProcessedCount,
          historicalPreparedCount,
          nextHistoricalRunAt,
          true,
          stopCode,
        );
      }

      final runAutomatic = await _isAutomationEnabled();
      final runHistorical = await _isHistoricalPreparationActive();
      if (!runAutomatic && !runHistorical) {
        return _summary(
          importedCount,
          ocrProcessedCount,
          classificationProcessedCount,
          historicalPreparedCount,
          nextHistoricalRunAt,
          false,
          BackgroundProcessingResultCode.disabled,
        );
      }

      var inboxPending = false;
      var ocrImmediate = false;
      var classificationImmediate = false;
      if (runAutomatic) {
        importedCount += await _consumeInbox(maximumItemsPerCycle);

        final ocr = await _ocrQueue.processAvailable(
          maximumItems: maximumItemsPerCycle,
        );
        ocrProcessedCount += ocr.processedCount;
        ocrImmediate = ocr.hasImmediateWork;

        final classification = await _classificationQueue.processAvailable(
          maximumItems: maximumItemsPerCycle,
          enqueueBackfill: false,
        );
        classificationProcessedCount += classification.processedCount;
        classificationImmediate = classification.hasImmediateWork;
        inboxPending = await _inboxSource.backgroundInboxPendingCount() > 0;
      }

      var historicalImmediate = false;
      if (runHistorical && _historicalQueue != null) {
        final historical = await _historicalQueue.processAvailable(
          maximumItems: historicalMediaMaximumBatchSize,
        );
        historicalPreparedCount += historical.preparedCount;
        historicalImmediate = historical.hasImmediateWork;
        nextHistoricalRunAt = historical.nextAvailableAt;
      }
      final immediateWork =
          inboxPending ||
          ocrImmediate ||
          classificationImmediate ||
          historicalImmediate;
      if (!immediateWork) {
        return _summary(
          importedCount,
          ocrProcessedCount,
          classificationProcessedCount,
          historicalPreparedCount,
          nextHistoricalRunAt,
          false,
          BackgroundProcessingResultCode.completed,
        );
      }
    }

    return _summary(
      importedCount,
      ocrProcessedCount,
      classificationProcessedCount,
      historicalPreparedCount,
      nextHistoricalRunAt,
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
    return null;
  }

  Future<bool> _isAutomationEnabled() async =>
      (await _settingsRepository.load()).enabled;

  Future<bool> _isHistoricalPreparationActive() async {
    final settings = _historicalSettingsRepository;
    if (_historicalQueue == null || settings == null) return false;
    return await settings.load() == HistoricalPreparationState.active;
  }

  BackgroundProcessingSummary _summary(
    int imported,
    int ocr,
    int classification,
    int historical,
    DateTime? nextHistoricalRunAt,
    bool pending,
    BackgroundProcessingResultCode code,
  ) {
    return BackgroundProcessingSummary(
      importedCount: imported,
      ocrProcessedCount: ocr,
      classificationProcessedCount: classification,
      historicalPreparedCount: historical,
      nextHistoricalRunAt: nextHistoricalRunAt,
      pendingImmediateWork: pending,
      resultCode: code,
    );
  }
}

bool _neverCancelled() => false;

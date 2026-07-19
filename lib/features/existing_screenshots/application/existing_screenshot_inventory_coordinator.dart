import 'dart:async';

import '../../../core/automatic_import/automatic_screenshot_source.dart';
import '../../../core/media_store/existing_screenshot_scanner.dart';
import '../data/existing_screenshot_candidate_repository.dart';
import '../domain/existing_screenshot_candidate.dart';
import '../domain/existing_screenshot_scan.dart';

typedef ExistingScreenshotProgressCallback =
    void Function(ExistingScreenshotScanProgress progress);

class ExistingScreenshotInventoryCoordinator {
  ExistingScreenshotInventoryCoordinator({
    required AutomaticScreenshotSource permissionSource,
    required ExistingScreenshotScanner scanner,
    required ExistingScreenshotCandidateRepository repository,
    DateTime Function()? clock,
  }) : this._(permissionSource, scanner, repository, clock ?? DateTime.now);

  ExistingScreenshotInventoryCoordinator._(
    this._permissionSource,
    this._scanner,
    this._repository,
    this._clock,
  );

  final AutomaticScreenshotSource _permissionSource;
  final ExistingScreenshotScanner _scanner;
  final ExistingScreenshotCandidateRepository _repository;
  final DateTime Function() _clock;
  bool _running = false;
  bool _cancelRequested = false;
  Completer<void>? _activeCompletion;

  bool get isRunning => _running;

  Future<MediaPermissionStatus> permissionStatus() =>
      _permissionSource.permissionStatus();

  Future<MediaPermissionStatus> requestPermission() =>
      _permissionSource.requestPermission();

  Future<void> openAppSettings() => _permissionSource.openAppSettings();

  Future<ExistingScreenshotInventorySummary> loadSummary() =>
      _repository.loadSummary();

  Future<void> clearInventory() => _repository.clearInventory();

  Future<ExistingScreenshotScanResult> scan({
    required ExistingScreenshotProgressCallback onProgress,
  }) async {
    if (_running) await cancel();
    final permission = await permissionStatus();
    final partial = permission == MediaPermissionStatus.limitedAccess;
    if (permission != MediaPermissionStatus.fullAccess && !partial) {
      return ExistingScreenshotScanResult(
        outcome: ExistingScreenshotScanOutcome.accessUnavailable,
        examinedCount: 0,
        recognizedCount: 0,
        partialAccess: false,
      );
    }

    final startedAt = _clock();
    var examined = 0;
    var recognized = 0;
    ExistingScreenshotScanCursor? cursor;
    _running = true;
    _cancelRequested = false;
    final completion = Completer<void>();
    _activeCompletion = completion;
    try {
      final sessionId = await _scanner.beginScan();
      while (!_cancelRequested) {
        final page = await _scanner.scanPage(
          sessionId: sessionId,
          cursor: cursor,
        );
        await _repository.upsertBatch(
          page.items
              .map((item) => item.seenAt(_clock()))
              .toList(growable: false),
        );
        examined += page.examinedCount;
        recognized += page.recognizedCount;
        onProgress(
          ExistingScreenshotScanProgress(
            examinedCount: examined,
            recognizedCount: recognized,
          ),
        );
        if (_cancelRequested) break;
        if (!page.hasNext) {
          await _repository.completeScan(
            scanStartedAt: startedAt,
            completedAt: _clock(),
            partialAccess: partial,
          );
          return ExistingScreenshotScanResult(
            outcome: ExistingScreenshotScanOutcome.completed,
            examinedCount: examined,
            recognizedCount: recognized,
            partialAccess: partial,
          );
        }
        final next = page.nextCursor;
        if (next == null ||
            (cursor?.volumeName == next.volumeName &&
                cursor?.mediaStoreId == next.mediaStoreId)) {
          throw StateError('invalid_scan_cursor');
        }
        cursor = next;
      }
      return ExistingScreenshotScanResult(
        outcome: ExistingScreenshotScanOutcome.cancelled,
        examinedCount: examined,
        recognizedCount: recognized,
        partialAccess: partial,
      );
    } finally {
      _running = false;
      if (!completion.isCompleted) completion.complete();
      if (identical(_activeCompletion, completion)) _activeCompletion = null;
    }
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    try {
      await _scanner.cancelScan();
    } catch (_) {
      // O cancelamento local já impede persistência e reconciliação posteriores.
    }
    await _activeCompletion?.future;
  }
}

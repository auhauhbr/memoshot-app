import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/automatic_import/automatic_screenshot_source.dart';
import 'package:memoshot/core/media_store/existing_screenshot_scanner.dart';
import 'package:memoshot/features/existing_screenshots/application/existing_screenshot_inventory_coordinator.dart';
import 'package:memoshot/features/existing_screenshots/data/existing_screenshot_candidate_repository.dart';
import 'package:memoshot/features/existing_screenshots/domain/existing_screenshot_candidate.dart';
import 'package:memoshot/features/existing_screenshots/domain/existing_screenshot_scan.dart';

void main() {
  test('acesso completo pagina, persiste por página e reconcilia', () async {
    final repository = _Repository();
    final scanner = _Scanner([
      page(0, 200, hasNext: true),
      page(200, 25, hasNext: false),
    ]);
    final progress = <ExistingScreenshotScanProgress>[];
    final coordinator = _coordinatorFor(
      permission: MediaPermissionStatus.fullAccess,
      scanner: scanner,
      repository: repository,
    );

    final result = await coordinator.scan(onProgress: progress.add);

    expect(result.outcome, ExistingScreenshotScanOutcome.completed);
    expect(result.examinedCount, 225);
    expect(result.recognizedCount, 225);
    expect(repository.batchSizes, [200, 25]);
    expect(repository.reconcileCount, 1);
    expect(repository.completeCount, 1);
    expect(progress.last.examinedCount, 225);
  });

  test('acesso parcial conclui sem reconciliar ausentes', () async {
    final repository = _Repository();
    final coordinator = _coordinatorFor(
      permission: MediaPermissionStatus.limitedAccess,
      scanner: _Scanner([page(0, 3, hasNext: false)]),
      repository: repository,
    );

    final result = await coordinator.scan(onProgress: (_) {});

    expect(result.partialAccess, isTrue);
    expect(repository.reconcileCount, 0);
    expect(repository.completedPartial, isTrue);
  });

  test('acesso negado não inicia scanner nem persiste', () async {
    final scanner = _Scanner([]);
    final repository = _Repository();
    final result = await _coordinatorFor(
      permission: MediaPermissionStatus.denied,
      scanner: scanner,
      repository: repository,
    ).scan(onProgress: (_) {});

    expect(result.outcome, ExistingScreenshotScanOutcome.accessUnavailable);
    expect(scanner.beginCount, 0);
    expect(repository.batchSizes, isEmpty);
  });

  test('cancelamento preserva páginas salvas e não reconcilia', () async {
    final repository = _Repository();
    final scanner = _Scanner([
      page(0, 200, hasNext: true),
      page(200, 200, hasNext: true),
    ]);
    late ExistingScreenshotInventoryCoordinator coordinator;
    coordinator = _coordinatorFor(
      permission: MediaPermissionStatus.fullAccess,
      scanner: scanner,
      repository: repository,
    );

    final result = await coordinator.scan(
      onProgress: (progress) {
        if (progress.examinedCount == 200) unawaited(coordinator.cancel());
      },
    );

    expect(result.outcome, ExistingScreenshotScanOutcome.cancelled);
    expect(repository.batchSizes, [200]);
    expect(repository.reconcileCount, 0);
    expect(repository.completeCount, 0);
  });

  test('erro intermediário mantém páginas e não reconcilia', () async {
    final repository = _Repository();
    final scanner = _Scanner([page(0, 200, hasNext: true)], failAfter: 1);
    final coordinator = _coordinatorFor(
      permission: MediaPermissionStatus.fullAccess,
      scanner: scanner,
      repository: repository,
    );

    await expectLater(
      coordinator.scan(onProgress: (_) {}),
      throwsA(isA<StateError>()),
    );
    expect(repository.batchSizes, [200]);
    expect(repository.reconcileCount, 0);
    expect(repository.completeCount, 0);
  });

  test(
    'nova execução espera a antiga e persiste o resultado novo por último',
    () async {
      final repository = _Repository();
      final scanner = _SupersedingScanner();
      final coordinator = ExistingScreenshotInventoryCoordinator(
        permissionSource: _PermissionSource(MediaPermissionStatus.fullAccess),
        scanner: scanner,
        repository: repository,
      );

      final oldScan = coordinator.scan(onProgress: (_) {});
      await scanner.firstPageRequested.future;
      final newScan = coordinator.scan(onProgress: (_) {});

      expect((await oldScan).outcome, ExistingScreenshotScanOutcome.cancelled);
      expect((await newScan).outcome, ExistingScreenshotScanOutcome.completed);
      expect(repository.sourceKeys, ['external:1', 'external:2']);
    },
  );

  for (final total in [5700, 10000]) {
    test('$total candidatos usam lotes limitados sem acumular tudo', () async {
      final pages = <ExistingScreenshotScanPage>[];
      for (var offset = 0; offset < total; offset += 200) {
        final count = (total - offset).clamp(0, 200);
        pages.add(page(offset, count, hasNext: offset + count < total));
      }
      final repository = _Repository();
      final result = await _coordinatorFor(
        permission: MediaPermissionStatus.fullAccess,
        scanner: _Scanner(pages),
        repository: repository,
      ).scan(onProgress: (_) {});

      expect(result.recognizedCount, total);
      expect(repository.persistedCount, total);
      expect(repository.maxBatchSize, lessThanOrEqualTo(200));
      expect(repository.reconcileCount, 1);
    });
  }
}

ExistingScreenshotInventoryCoordinator _coordinatorFor({
  required MediaPermissionStatus permission,
  required _Scanner scanner,
  required _Repository repository,
}) {
  var tick = 0;
  return ExistingScreenshotInventoryCoordinator(
    permissionSource: _PermissionSource(permission),
    scanner: scanner,
    repository: repository,
    clock: () => DateTime.utc(2026, 7, 19).add(Duration(seconds: tick++)),
  );
}

ExistingScreenshotScanPage page(int start, int count, {required bool hasNext}) {
  return ExistingScreenshotScanPage(
    examinedCount: count,
    recognizedCount: count,
    hasNext: hasNext,
    nextCursor: ExistingScreenshotScanCursor(
      volumeName: 'external',
      mediaStoreId: start + count,
    ),
    items: [
      for (var index = start; index < start + count; index++)
        ExistingScreenshotCandidate(
          sourceKey: 'external:$index',
          mediaStoreId: index,
          volumeName: 'external',
          contentUri: 'content://media/external/images/media/$index',
          mimeType: 'image/png',
          capturedAt: null,
          dateModified: null,
          sizeBytes: 100,
          width: null,
          height: null,
          discoveredAt: DateTime.utc(2026),
          lastSeenAt: DateTime.utc(2026),
          availability: ExistingScreenshotAvailability.available,
        ),
    ],
  );
}

class _Scanner implements ExistingScreenshotScanner {
  _Scanner(this.pages, {this.failAfter});

  final List<ExistingScreenshotScanPage> pages;
  final int? failAfter;
  int beginCount = 0;
  int pageCount = 0;

  @override
  Future<String> beginScan() async {
    beginCount++;
    return 'session-$beginCount';
  }

  @override
  Future<void> cancelScan() async {}

  @override
  Future<ExistingScreenshotScanPage> scanPage({
    required String sessionId,
    ExistingScreenshotScanCursor? cursor,
  }) async {
    if (failAfter == pageCount) throw StateError('controlled_failure');
    return pages[pageCount++];
  }
}

class _SupersedingScanner implements ExistingScreenshotScanner {
  final Completer<void> firstPageRequested = Completer<void>();
  final Completer<ExistingScreenshotScanPage> _oldPage =
      Completer<ExistingScreenshotScanPage>();
  int _sessions = 0;
  int _pages = 0;

  @override
  Future<String> beginScan() async => 'session-${++_sessions}';

  @override
  Future<void> cancelScan() async {
    if (!_oldPage.isCompleted) {
      _oldPage.complete(page(1, 1, hasNext: true));
    }
  }

  @override
  Future<ExistingScreenshotScanPage> scanPage({
    required String sessionId,
    ExistingScreenshotScanCursor? cursor,
  }) {
    if (_pages++ == 0) {
      firstPageRequested.complete();
      return _oldPage.future;
    }
    return Future.value(page(2, 1, hasNext: false));
  }
}

class _Repository implements ExistingScreenshotCandidateRepository {
  final List<int> batchSizes = [];
  final List<String> sourceKeys = [];
  int persistedCount = 0;
  int maxBatchSize = 0;
  int reconcileCount = 0;
  int completeCount = 0;
  bool completedPartial = false;

  @override
  Future<void> completeScan({
    required DateTime scanStartedAt,
    required DateTime completedAt,
    required bool partialAccess,
  }) async {
    if (!partialAccess) reconcileCount++;
    await recordCompletedScan(
      completedAt: completedAt,
      partialAccess: partialAccess,
    );
  }

  @override
  Future<void> upsertBatch(List<ExistingScreenshotCandidate> candidates) async {
    batchSizes.add(candidates.length);
    sourceKeys.addAll(candidates.map((item) => item.sourceKey));
    persistedCount += candidates.length;
    if (candidates.length > maxBatchSize) maxBatchSize = candidates.length;
  }

  @override
  Future<void> markUnavailableNotSeenInCompletedScan(
    DateTime scanStartedAt,
  ) async {
    reconcileCount++;
  }

  @override
  Future<void> recordCompletedScan({
    required DateTime completedAt,
    required bool partialAccess,
  }) async {
    completeCount++;
    completedPartial = partialAccess;
  }

  @override
  Future<ExistingScreenshotInventorySummary> loadSummary() async =>
      const ExistingScreenshotInventorySummary.empty();

  @override
  Future<void> clearInventory() async {}

  @override
  Future<int> countAvailable() async => 0;

  @override
  Future<int> countUnavailable() async => 0;

  @override
  Future<ExistingScreenshotCandidate?> findBySourceKey(
    String sourceKey,
  ) async => null;

  @override
  Future<List<ExistingScreenshotCandidate>> loadCandidatesPage({
    int limit = 200,
    String? afterSourceKey,
  }) async => const [];
}

class _PermissionSource implements AutomaticScreenshotSource {
  _PermissionSource(this.permission);

  MediaPermissionStatus permission;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<MediaPermissionStatus> permissionStatus() async => permission;

  @override
  Future<MediaPermissionStatus> requestPermission() async => permission;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<int> currentMaxMediaId() async => 0;

  @override
  Future<AutomaticScreenshotBatch> scanAfter(int lastMediaId) =>
      throw UnsupportedError('fora do teste');

  @override
  Future<void> startObserving() async {}

  @override
  Future<void> stopObserving() async {}

  @override
  Future<void> deleteTemporary(String path) async {}

  @override
  Future<BackgroundMonitorStatus> configureBackgroundMonitoring({
    required bool enabled,
    required int lastMediaId,
    bool resetBaseline = false,
  }) => throw UnsupportedError('fora do teste');

  @override
  Future<List<BackgroundScreenshotEntry>> loadBackgroundInbox() async =>
      const [];

  @override
  Future<int> backgroundInboxPendingCount() async => 0;

  @override
  Future<void> acknowledgeBackgroundEntry(String entryId) async {}

  @override
  Future<void> rejectBackgroundEntry(String entryId) async {}
}

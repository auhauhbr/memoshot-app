import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/automatic_import/automatic_screenshot_source.dart';
import 'package:memoshot/core/media_store/existing_screenshot_scanner.dart';
import 'package:memoshot/features/existing_screenshots/application/existing_screenshot_inventory_coordinator.dart';
import 'package:memoshot/features/existing_screenshots/data/existing_screenshot_candidate_repository.dart';
import 'package:memoshot/features/existing_screenshots/domain/existing_screenshot_candidate.dart';
import 'package:memoshot/features/existing_screenshots/domain/existing_screenshot_scan.dart';
import 'package:memoshot/features/existing_screenshots/presentation/existing_screenshot_inventory_page.dart';

void main() {
  testWidgets('nunca mapeado não inicia automaticamente', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(
      find.text('Organize os prints que já estão no celular'),
      findsOneWidget,
    );
    expect(find.text('Mapear meus screenshots'), findsOneWidget);
    expect(find.textContaining('Nenhuma imagem será copiada'), findsOneWidget);
    expect(harness.scanner.beginCount, 0);
    expect(find.text('Organizar agora'), findsNothing);
  });

  testWidgets('mapeia explicitamente e mostra progresso e conclusão', (
    tester,
  ) async {
    final blocker = Completer<ExistingScreenshotScanPage>();
    final harness = _Harness(blocker: blocker);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-inventory-scan')));
    await tester.pump();
    expect(find.text('Mapeando seus screenshots…'), findsOneWidget);
    blocker.complete(makeScanPage(2));
    await tester.pumpAndSettle();

    expect(find.text('Encontramos 2 screenshots'), findsOneWidget);
    expect(find.text('2 disponíveis'), findsOneWidget);
    expect(find.text('Nenhuma imagem foi copiada ou movida.'), findsOneWidget);
    expect(find.text('Atualizar inventário'), findsOneWidget);
  });

  testWidgets('conclusão trata singular', (tester) async {
    final harness = _Harness(pages: [makeScanPage(1)]);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mapear meus screenshots'));
    await tester.pumpAndSettle();
    expect(find.text('Encontramos 1 screenshot'), findsOneWidget);
  });

  testWidgets('acesso parcial informa limite e permite mapear sem reconciliar', (
    tester,
  ) async {
    final harness = _Harness(
      permission: MediaPermissionStatus.limitedAccess,
      pages: [makeScanPage(1)],
    );
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'O acesso é parcial. O inventário incluirá apenas as imagens permitidas.',
      ),
      findsOneWidget,
    );
    expect(find.text('Revisar acesso'), findsOneWidget);
    await tester.tap(find.text('Mapear meus screenshots'));
    await tester.pumpAndSettle();
    expect(harness.repository.reconcileCount, 0);
  });

  testWidgets('acesso negado e bloqueado oferecem ações sem iniciar scan', (
    tester,
  ) async {
    for (final entry in <(MediaPermissionStatus, String)>[
      (MediaPermissionStatus.denied, 'Conceder acesso'),
      (
        MediaPermissionStatus.permanentlyDenied,
        'Abrir configurações do Android',
      ),
    ]) {
      final harness = _Harness(permission: entry.$1);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('start-inventory-scan')))
            .onPressed,
        isNull,
      );
      expect(harness.scanner.beginCount, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });

  testWidgets('indisponível mostra tentar novamente', (tester) async {
    final harness = _Harness(permission: MediaPermissionStatus.unsupported);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(harness.source.requestCount, 0);
  });

  testWidgets('cancelamento encerra UI e preserva inventário anterior', (
    tester,
  ) async {
    final blocker = Completer<ExistingScreenshotScanPage>();
    final harness = _Harness(blocker: blocker)
      ..repository.summary = ExistingScreenshotInventorySummary(
        availableCount: 3,
        unavailableCount: 0,
        lastCompletedScanAt: DateTime.utc(2026),
        lastScanWasPartial: false,
      );
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atualizar inventário'));
    await tester.pump();
    await tester.tap(find.text('Cancelar mapeamento'));
    await tester.pumpAndSettle();

    expect(find.text('Encontramos 3 screenshots'), findsOneWidget);
    expect(harness.scanner.cancelCount, greaterThan(0));
    expect(harness.repository.reconcileCount, 0);
  });

  testWidgets('erro oferece retry e nova tentativa conclui', (tester) async {
    final harness = _Harness(failOnce: true, pages: [makeScanPage(1)]);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mapear meus screenshots'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível mapear seus screenshots.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Encontramos 1 screenshot'), findsOneWidget);
  });

  testWidgets('limpar inventário confirma que nenhuma imagem será excluída', (
    tester,
  ) async {
    final harness = _Harness()
      ..repository.summary = ExistingScreenshotInventorySummary(
        availableCount: 4,
        unavailableCount: 1,
        lastCompletedScanAt: DateTime.utc(2026),
        lastScanWasPartial: false,
      );
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inventory-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar inventário'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhuma imagem será excluída'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-clear-inventory')));
    await tester.pumpAndSettle();
    expect(harness.repository.clearCount, 1);
    expect(find.text('Mapear meus screenshots'), findsOneWidget);
  });
}

class _Harness {
  _Harness({
    MediaPermissionStatus permission = MediaPermissionStatus.fullAccess,
    List<ExistingScreenshotScanPage> pages = const [],
    Completer<ExistingScreenshotScanPage>? blocker,
    bool failOnce = false,
  }) : source = _Source(permission),
       scanner = _Scanner(pages, blocker: blocker, failOnce: failOnce);

  final _Source source;
  final _Scanner scanner;
  final _Repository repository = _Repository();

  Widget app() {
    return MaterialApp(
      home: ExistingScreenshotInventoryPage(
        coordinator: ExistingScreenshotInventoryCoordinator(
          permissionSource: source,
          scanner: scanner,
          repository: repository,
        ),
      ),
    );
  }
}

ExistingScreenshotScanPage makeScanPage(int count) =>
    ExistingScreenshotScanPage(
      examinedCount: count + 5,
      recognizedCount: count,
      hasNext: false,
      nextCursor: ExistingScreenshotScanCursor(
        volumeName: 'external',
        mediaStoreId: count,
      ),
      items: [
        for (var index = 0; index < count; index++)
          ExistingScreenshotCandidate(
            sourceKey: 'external:$index',
            mediaStoreId: index,
            volumeName: 'external',
            contentUri: 'content://media/external/images/media/$index',
            mimeType: 'image/png',
            capturedAt: null,
            dateModified: null,
            sizeBytes: null,
            width: null,
            height: null,
            discoveredAt: DateTime.utc(2026),
            lastSeenAt: DateTime.utc(2026),
            availability: ExistingScreenshotAvailability.available,
          ),
      ],
    );

class _Scanner implements ExistingScreenshotScanner {
  _Scanner(this.pages, {this.blocker, this.failOnce = false});

  final List<ExistingScreenshotScanPage> pages;
  final Completer<ExistingScreenshotScanPage>? blocker;
  bool failOnce;
  int beginCount = 0;
  int cancelCount = 0;

  @override
  Future<String> beginScan() async {
    beginCount++;
    return 'session';
  }

  @override
  Future<void> cancelScan() async {
    cancelCount++;
    if (blocker != null && !blocker!.isCompleted) {
      blocker!.complete(makeScanPage(1));
    }
  }

  @override
  Future<ExistingScreenshotScanPage> scanPage({
    required String sessionId,
    ExistingScreenshotScanCursor? cursor,
  }) async {
    if (failOnce) {
      failOnce = false;
      throw StateError('controlled');
    }
    if (blocker != null) return blocker!.future;
    return pages.removeAt(0);
  }
}

class _Repository implements ExistingScreenshotCandidateRepository {
  ExistingScreenshotInventorySummary summary =
      const ExistingScreenshotInventorySummary.empty();
  int reconcileCount = 0;
  int clearCount = 0;
  int candidateCount = 0;

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
    candidateCount += candidates.length;
  }

  @override
  Future<void> recordCompletedScan({
    required DateTime completedAt,
    required bool partialAccess,
  }) async {
    summary = ExistingScreenshotInventorySummary(
      availableCount: candidateCount,
      unavailableCount: 0,
      lastCompletedScanAt: completedAt,
      lastScanWasPartial: partialAccess,
    );
  }

  @override
  Future<void> markUnavailableNotSeenInCompletedScan(
    DateTime scanStartedAt,
  ) async {
    reconcileCount++;
  }

  @override
  Future<ExistingScreenshotInventorySummary> loadSummary() async => summary;

  @override
  Future<void> clearInventory() async {
    clearCount++;
    candidateCount = 0;
    summary = const ExistingScreenshotInventorySummary.empty();
  }

  @override
  Future<int> countAvailable() async => summary.availableCount;

  @override
  Future<int> countUnavailable() async => summary.unavailableCount;

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

class _Source implements AutomaticScreenshotSource {
  _Source(this.permission);

  MediaPermissionStatus permission;
  int requestCount = 0;

  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<MediaPermissionStatus> permissionStatus() async => permission;
  @override
  Future<MediaPermissionStatus> requestPermission() async {
    requestCount++;
    return permission;
  }

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

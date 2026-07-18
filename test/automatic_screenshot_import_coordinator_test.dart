import 'dart:async';
import 'dart:io';

import 'package:memoshot/core/automatic_import/automatic_screenshot_source.dart';
import 'package:memoshot/features/automatic_import/automatic_screenshot_import_coordinator.dart';
import 'package:memoshot/features/automatic_import/data/automatic_import_settings_repository.dart';
import 'package:memoshot/features/automatic_import/domain/automatic_import_settings.dart';
import 'package:memoshot/features/library/data/media_item_repository.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/library/domain/selected_screenshot.dart';
import 'package:memoshot/features/library/domain/screenshot_search_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desativada não consulta nem solicita permissão', () async {
    final source = _FakeSource();
    final coordinator = _coordinator(source: source);

    await coordinator.initialize();

    expect(source.statusCalls, 0);
    expect(source.requestCalls, 0);
    expect(source.startCalls, 0);
    await coordinator.dispose();
  });

  test('sem preferência e com acesso ativa automação por padrão', () async {
    final source = _FakeSource(maxMediaId: 17);
    final settings = _FakeSettings(hasStoredPreference: false);
    final coordinator = _coordinator(source: source, settings: settings);

    await coordinator.initialize();

    expect(source.requestCalls, 0);
    expect(source.statusCalls, 1);
    expect(settings.enabled, isTrue);
    expect(settings.hasStoredPreference, isTrue);
    expect(settings.marker, 17);
    expect(source.backgroundConfigurationCalls, 1);
    expect(source.startCalls, 1);
    await coordinator.dispose();
  });

  test('sem preferência e sem acesso não ativa automação', () async {
    final source = _FakeSource(permission: MediaPermissionStatus.denied);
    final settings = _FakeSettings(hasStoredPreference: false);
    final states = <AutomaticImportUiState>[];
    final coordinator = _coordinator(
      source: source,
      settings: settings,
      states: states,
    );

    await coordinator.initialize();

    expect(settings.enabled, isFalse);
    expect(settings.hasStoredPreference, isFalse);
    expect(source.requestCalls, 0);
    expect(source.startCalls, 0);
    expect(states.last, AutomaticImportUiState.accessRequired);
    await coordinator.dispose();
  });

  test('preferência explicitamente desativada nunca é sobrescrita', () async {
    final source = _FakeSource();
    final settings = _FakeSettings(enabled: false, hasStoredPreference: true);
    final coordinator = _coordinator(source: source, settings: settings);

    await coordinator.initialize();

    expect(settings.enabled, isFalse);
    expect(source.statusCalls, 0);
    expect(source.startCalls, 0);
    await coordinator.dispose();
  });

  test('acesso completo salva linha de base antes de observar', () async {
    final source = _FakeSource(maxMediaId: 81);
    final settings = _FakeSettings();
    final coordinator = _coordinator(source: source, settings: settings);

    expect(await coordinator.enable(), MediaPermissionStatus.fullAccess);

    expect(settings.enabled, isTrue);
    expect(settings.marker, 81);
    expect(source.startCalls, 1);
    expect(source.backgroundConfigurationCalls, 1);
    expect(source.operations, ['request', 'max', 'start']);
    await coordinator.dispose();
  });

  test('acesso limitado e negado não ativam automação', () async {
    for (final permission in [
      MediaPermissionStatus.limitedAccess,
      MediaPermissionStatus.denied,
    ]) {
      final source = _FakeSource(permission: permission);
      final settings = _FakeSettings();
      final states = <AutomaticImportUiState>[];
      final coordinator = _coordinator(
        source: source,
        settings: settings,
        states: states,
      );

      await coordinator.enable();

      expect(settings.enabled, isFalse);
      expect(source.startCalls, 0);
      expect(source.backgroundConfigurationCalls, 0);
      expect(
        states.last,
        permission == MediaPermissionStatus.limitedAccess
            ? AutomaticImportUiState.limitedAccess
            : AutomaticImportUiState.accessRequired,
      );
      await coordinator.dispose();
    }
  });

  test('retomada encontra itens posteriores e usa origem automatic', () async {
    final capturedAt = DateTime(2026, 1, 2, 10, 30);
    final source = _FakeSource(
      batches: [
        AutomaticScreenshotBatch(
          lastExaminedMediaId: 14,
          items: [
            AutomaticScreenshotCandidate(
              mediaId: 14,
              temporaryPath: '/cache/ficticio.png',
              mimeType: 'image/png',
              capturedAt: capturedAt,
            ),
          ],
        ),
      ],
    );
    final settings = _FakeSettings(enabled: true, marker: 9);
    final media = _FakeMediaRepository();
    final coordinator = _coordinator(
      source: source,
      settings: settings,
      media: media,
    );

    await coordinator.initialize();

    expect(source.scanMarkers, [9]);
    expect(media.origins, [ImportOrigin.automatic]);
    expect(media.receivedScreenshots.single.capturedAt, capturedAt);
    expect(settings.marker, 14);
    expect(source.deletedPaths, ['/cache/ficticio.png']);
    await coordinator.dispose();
  });

  test('desativar cancela observação imediatamente', () async {
    final source = _FakeSource();
    final settings = _FakeSettings();
    final coordinator = _coordinator(source: source, settings: settings);
    await coordinator.enable();

    await coordinator.disable();

    expect(settings.enabled, isFalse);
    expect(source.stopCalls, 1);
    expect(source.backgroundConfigurationCalls, 2);
    await coordinator.dispose();
  });

  test('eventos durante varredura não executam scans concorrentes', () async {
    final blocker = Completer<void>();
    final source = _FakeSource();
    final settings = _FakeSettings(enabled: true, marker: 2);
    final coordinator = _coordinator(source: source, settings: settings);
    await coordinator.initialize();
    source.scanBlocker = blocker;
    source.emit();
    await Future<void>.delayed(Duration.zero);

    source.emit();
    source.emit();
    expect(source.maxConcurrentScans, 1);
    blocker.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(source.maxConcurrentScans, 1);
    await coordinator.dispose();
  });

  test('falha controlada ainda limpa temporário e avança marcador', () async {
    final source = _FakeSource(
      batches: [
        const AutomaticScreenshotBatch(
          lastExaminedMediaId: 23,
          items: [
            AutomaticScreenshotCandidate(
              mediaId: 23,
              temporaryPath: '/cache/falha.png',
            ),
          ],
        ),
      ],
    );
    final settings = _FakeSettings(enabled: true, marker: 20);
    final media = _FakeMediaRepository(rejectedCount: 1);
    final coordinator = _coordinator(
      source: source,
      settings: settings,
      media: media,
    );

    await coordinator.initialize();

    expect(settings.marker, 23);
    expect(source.deletedPaths, ['/cache/falha.png']);
    await coordinator.dispose();
  });

  test(
    'permissão removida suspende monitoramento sem solicitar novamente',
    () async {
      final source = _FakeSource(permission: MediaPermissionStatus.denied);
      final settings = _FakeSettings(enabled: true, marker: 4);
      final states = <AutomaticImportUiState>[];
      final coordinator = _coordinator(
        source: source,
        settings: settings,
        states: states,
      );

      await coordinator.initialize();

      expect(source.requestCalls, 0);
      expect(source.startCalls, 0);
      expect(states.last, AutomaticImportUiState.accessRequired);
      await coordinator.dispose();
    },
  );

  test('entrada durável usa pipeline automático e é confirmada', () async {
    final directory = Directory.systemTemp.createTempSync('memoshot_inbox_');
    final image = File('${directory.path}/entrada.png')..writeAsBytesSync([1]);
    final capturedAt = DateTime(2025, 12, 20, 8);
    final source = _FakeSource()
      ..inbox.add(
        BackgroundScreenshotEntry(
          entryId: 'entrada-1',
          mediaId: 31,
          privatePath: image.path,
          mimeType: 'image/png',
          capturedAt: capturedAt,
        ),
      );
    final media = _FakeMediaRepository(importItems: true);
    final coordinator = _coordinator(source: source, media: media);

    await coordinator.initialize();

    expect(media.origins, [ImportOrigin.automatic]);
    expect(media.receivedScreenshots.single.capturedAt, capturedAt);
    expect(source.acknowledgedEntries, ['entrada-1']);
    expect(source.inbox, isEmpty);
    expect(await source.backgroundInboxPendingCount(), 0);
    await coordinator.dispose();
    directory.deleteSync(recursive: true);
  });

  test(
    'duplicata confirma entrada e falha transitória mantém entrada',
    () async {
      final directory = Directory.systemTemp.createTempSync('memoshot_inbox_');
      final image = File('${directory.path}/entrada.png')
        ..writeAsBytesSync([1]);
      final duplicateSource = _FakeSource()
        ..inbox.add(
          BackgroundScreenshotEntry(
            entryId: 'duplicada',
            mediaId: 32,
            privatePath: image.path,
          ),
        );
      final duplicateCoordinator = _coordinator(
        source: duplicateSource,
        media: _FakeMediaRepository(duplicateCount: 1),
      );
      await duplicateCoordinator.initialize();
      expect(duplicateSource.acknowledgedEntries, ['duplicada']);
      await duplicateCoordinator.dispose();

      final failedSource = _FakeSource()
        ..inbox.add(
          BackgroundScreenshotEntry(
            entryId: 'transitoria',
            mediaId: 33,
            privatePath: image.path,
          ),
        );
      final failedCoordinator = _coordinator(
        source: failedSource,
        media: _FakeMediaRepository(rejectedCount: 1),
      );
      await failedCoordinator.initialize();
      expect(failedSource.acknowledgedEntries, isEmpty);
      expect(failedSource.inbox, hasLength(1));
      await failedCoordinator.dispose();
      directory.deleteSync(recursive: true);
    },
  );

  test('entrada inválida é rejeitada sem crash', () async {
    final source = _FakeSource()
      ..inbox.add(
        const BackgroundScreenshotEntry(
          entryId: 'invalida',
          mediaId: 34,
          privatePath: '/arquivo/ficticio/inexistente.png',
        ),
      );
    final coordinator = _coordinator(source: source);

    await coordinator.initialize();

    expect(source.rejectedEntries, ['invalida']);
    await coordinator.dispose();
  });

  test('marcador nativo maior é reconciliado antes da varredura', () async {
    final source = _FakeSource()..backgroundMarker = 88;
    final settings = _FakeSettings(enabled: true, marker: 20);
    final coordinator = _coordinator(source: source, settings: settings);

    await coordinator.initialize();

    expect(source.scanMarkers, [88]);
    expect(settings.marker, 88);
    await coordinator.dispose();
  });

  test('duas drenagens não executam simultaneamente', () async {
    final blocker = Completer<List<BackgroundScreenshotEntry>>();
    final source = _FakeSource()..inboxLoadCompleter = blocker;
    final coordinator = _coordinator(source: source);

    final first = coordinator.initialize();
    final second = coordinator.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(source.maxConcurrentInboxLoads, 1);
    blocker.complete(const []);
    await Future.wait([first, second]);

    expect(source.maxConcurrentInboxLoads, 1);
    await coordinator.dispose();
  });
}

AutomaticScreenshotImportCoordinator _coordinator({
  required _FakeSource source,
  _FakeSettings? settings,
  _FakeMediaRepository? media,
  List<AutomaticImportUiState>? states,
}) {
  return AutomaticScreenshotImportCoordinator(
    source: source,
    settingsRepository: settings ?? _FakeSettings(),
    mediaRepository: media ?? _FakeMediaRepository(),
    onStateChanged: (state) => states?.add(state),
    onImported: (_) async {},
    onError: () {},
  );
}

class _FakeSource implements AutomaticScreenshotSource {
  _FakeSource({
    this.permission = MediaPermissionStatus.fullAccess,
    this.maxMediaId = 0,
    List<AutomaticScreenshotBatch> batches = const [],
  }) : batches = [...batches];

  MediaPermissionStatus permission;
  final int maxMediaId;
  final List<AutomaticScreenshotBatch> batches;
  Completer<void>? scanBlocker;
  final StreamController<void> controller = StreamController<void>.broadcast();
  final List<String> operations = [];
  final List<int> scanMarkers = [];
  final List<String> deletedPaths = [];
  int statusCalls = 0;
  int requestCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int concurrentScans = 0;
  int maxConcurrentScans = 0;
  final List<BackgroundScreenshotEntry> inbox = [];
  final List<String> acknowledgedEntries = [];
  final List<String> rejectedEntries = [];
  int backgroundMarker = 0;
  int backgroundConfigurationCalls = 0;
  Completer<List<BackgroundScreenshotEntry>>? inboxLoadCompleter;
  int concurrentInboxLoads = 0;
  int maxConcurrentInboxLoads = 0;

  @override
  Future<void> acknowledgeBackgroundEntry(String entryId) async {
    acknowledgedEntries.add(entryId);
    inbox.removeWhere((entry) => entry.entryId == entryId);
  }

  @override
  Future<BackgroundMonitorStatus> configureBackgroundMonitoring({
    required bool enabled,
    required int lastMediaId,
    bool resetBaseline = false,
  }) async {
    backgroundConfigurationCalls++;
    backgroundMarker = resetBaseline || lastMediaId > backgroundMarker
        ? lastMediaId
        : backgroundMarker;
    return BackgroundMonitorStatus(
      available: true,
      enabled: enabled,
      lastMediaId: backgroundMarker,
    );
  }

  @override
  Stream<void> get changes => controller.stream;

  @override
  Future<int> backgroundInboxPendingCount() async => inbox.length;

  @override
  Future<int> currentMaxMediaId() async {
    operations.add('max');
    return maxMediaId;
  }

  @override
  Future<void> deleteTemporary(String path) async => deletedPaths.add(path);

  void emit() => controller.add(null);

  @override
  Future<List<BackgroundScreenshotEntry>> loadBackgroundInbox() async {
    concurrentInboxLoads++;
    if (concurrentInboxLoads > maxConcurrentInboxLoads) {
      maxConcurrentInboxLoads = concurrentInboxLoads;
    }
    final blocked = inboxLoadCompleter;
    final result = blocked == null ? [...inbox] : await blocked.future;
    inboxLoadCompleter = null;
    concurrentInboxLoads--;
    return result;
  }

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<MediaPermissionStatus> permissionStatus() async {
    statusCalls++;
    return permission;
  }

  @override
  Future<MediaPermissionStatus> requestPermission() async {
    requestCalls++;
    operations.add('request');
    return permission;
  }

  @override
  Future<void> rejectBackgroundEntry(String entryId) async {
    rejectedEntries.add(entryId);
    inbox.removeWhere((entry) => entry.entryId == entryId);
  }

  @override
  Future<AutomaticScreenshotBatch> scanAfter(int lastMediaId) async {
    scanMarkers.add(lastMediaId);
    concurrentScans++;
    if (concurrentScans > maxConcurrentScans) {
      maxConcurrentScans = concurrentScans;
    }
    await scanBlocker?.future;
    concurrentScans--;
    return batches.isEmpty
        ? AutomaticScreenshotBatch(
            lastExaminedMediaId: lastMediaId,
            items: const [],
          )
        : batches.removeAt(0);
  }

  @override
  Future<void> startObserving() async {
    startCalls++;
    operations.add('start');
  }

  @override
  Future<void> stopObserving() async {
    stopCalls++;
  }
}

class _FakeSettings implements AutomaticImportSettingsRepository {
  _FakeSettings({
    this.enabled = false,
    this.marker,
    this.hasStoredPreference = true,
  });

  bool enabled;
  int? marker;
  bool hasStoredPreference;

  @override
  Future<void> disable() async {
    enabled = false;
    hasStoredPreference = true;
  }

  @override
  Future<void> enable({required int baselineMediaId}) async {
    enabled = true;
    hasStoredPreference = true;
    marker = baselineMediaId;
  }

  @override
  Future<AutomaticImportSettings> load() async => AutomaticImportSettings(
    enabled: enabled,
    hasStoredPreference: hasStoredPreference,
    lastMediaId: marker,
    updatedAt: DateTime(2026),
  );

  @override
  Future<void> updateMarker(int lastMediaId) async => marker = lastMediaId;
}

class _FakeMediaRepository implements MediaItemRepository {
  _FakeMediaRepository({
    this.rejectedCount = 0,
    this.duplicateCount = 0,
    this.importItems = false,
  });

  final int rejectedCount;
  final int duplicateCount;
  final bool importItems;
  final List<ImportOrigin> origins = [];
  final List<SelectedScreenshot> receivedScreenshots = [];

  @override
  Future<ImportResult> importScreenshots(
    List<SelectedScreenshot> screenshots, {
    ImportOrigin origin = ImportOrigin.picker,
  }) async {
    origins.add(origin);
    receivedScreenshots.addAll(screenshots);
    final importedItems = importItems && screenshots.isNotEmpty
        ? [
            MediaItem(
              id: origins.length,
              privatePath: screenshots.first.path,
              internalName: 'interno.png',
              importedAt: DateTime(2026),
              sourceMode: 'photoPicker',
              status: 'ready',
              importOrigin: origin,
            ),
          ]
        : const <MediaItem>[];
    return ImportResult(
      importedItems: importedItems,
      duplicateCount: duplicateCount,
      rejectedCount: rejectedCount,
    );
  }

  @override
  Future<void> close() async {}

  @override
  Future<List<MediaItem>> loadAvailableItems({int? tagId}) async => const [];

  @override
  Future<void> removeItem(MediaItem item) async {}

  @override
  Future<List<ScreenshotSearchResult>> searchRecognizedText(
    String query, {
    int? tagId,
    int limit = 100,
  }) async => const [];
}

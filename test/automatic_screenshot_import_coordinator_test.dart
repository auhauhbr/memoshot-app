import 'dart:async';

import 'package:contexto/core/automatic_import/automatic_screenshot_source.dart';
import 'package:contexto/features/automatic_import/automatic_screenshot_import_coordinator.dart';
import 'package:contexto/features/automatic_import/data/automatic_import_settings_repository.dart';
import 'package:contexto/features/automatic_import/domain/automatic_import_settings.dart';
import 'package:contexto/features/library/data/media_item_repository.dart';
import 'package:contexto/features/library/domain/media_item.dart';
import 'package:contexto/features/library/domain/selected_screenshot.dart';
import 'package:contexto/features/library/domain/screenshot_search_result.dart';
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

  test('acesso completo salva linha de base antes de observar', () async {
    final source = _FakeSource(maxMediaId: 81);
    final settings = _FakeSettings();
    final coordinator = _coordinator(source: source, settings: settings);

    expect(await coordinator.enable(), MediaPermissionStatus.fullAccess);

    expect(settings.enabled, isTrue);
    expect(settings.marker, 81);
    expect(source.startCalls, 1);
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
    final source = _FakeSource(
      batches: [
        const AutomaticScreenshotBatch(
          lastExaminedMediaId: 14,
          items: [
            AutomaticScreenshotCandidate(
              mediaId: 14,
              temporaryPath: '/cache/ficticio.png',
              mimeType: 'image/png',
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

  @override
  Stream<void> get changes => controller.stream;

  @override
  Future<int> currentMaxMediaId() async {
    operations.add('max');
    return maxMediaId;
  }

  @override
  Future<void> deleteTemporary(String path) async => deletedPaths.add(path);

  void emit() => controller.add(null);

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
  _FakeSettings({this.enabled = false, this.marker});

  bool enabled;
  int? marker;

  @override
  Future<void> disable() async => enabled = false;

  @override
  Future<void> enable({required int baselineMediaId}) async {
    enabled = true;
    marker = baselineMediaId;
  }

  @override
  Future<AutomaticImportSettings> load() async => AutomaticImportSettings(
    enabled: enabled,
    lastMediaId: marker,
    updatedAt: DateTime(2026),
  );

  @override
  Future<void> updateMarker(int lastMediaId) async => marker = lastMediaId;
}

class _FakeMediaRepository implements MediaItemRepository {
  _FakeMediaRepository({this.rejectedCount = 0});

  final int rejectedCount;
  final List<ImportOrigin> origins = [];

  @override
  Future<ImportResult> importScreenshots(
    List<SelectedScreenshot> screenshots, {
    ImportOrigin origin = ImportOrigin.picker,
  }) async {
    origins.add(origin);
    return ImportResult(
      importedItems: const [],
      duplicateCount: 0,
      rejectedCount: rejectedCount,
    );
  }

  @override
  Future<void> close() async {}

  @override
  Future<List<MediaItem>> loadAvailableItems() async => const [];

  @override
  Future<void> removeItem(MediaItem item) async {}

  @override
  Future<List<ScreenshotSearchResult>> searchRecognizedText(
    String query, {
    int limit = 100,
  }) async => const [];
}

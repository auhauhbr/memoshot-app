import 'dart:async';
import 'dart:io';

import '../../core/automatic_import/automatic_screenshot_source.dart';
import '../library/data/media_item_repository.dart';
import '../library/domain/media_item.dart';
import '../library/domain/selected_screenshot.dart';
import 'data/automatic_import_settings_repository.dart';

enum AutomaticImportUiState {
  disabled,
  active,
  accessRequired,
  limitedAccess,
  unavailable,
}

class AutomaticScreenshotImportCoordinator {
  AutomaticScreenshotImportCoordinator({
    required AutomaticScreenshotSource source,
    required AutomaticImportSettingsRepository settingsRepository,
    required MediaItemRepository mediaRepository,
    required void Function(AutomaticImportUiState state) onStateChanged,
    required Future<void> Function(ImportResult result) onImported,
    required void Function() onError,
  }) : this._(
         source,
         settingsRepository,
         mediaRepository,
         onStateChanged,
         onImported,
         onError,
       );

  AutomaticScreenshotImportCoordinator._(
    this._source,
    this._settingsRepository,
    this._mediaRepository,
    this._onStateChanged,
    this._onImported,
    this._onError,
  );

  final AutomaticScreenshotSource _source;
  final AutomaticImportSettingsRepository _settingsRepository;
  final MediaItemRepository _mediaRepository;
  final void Function(AutomaticImportUiState state) _onStateChanged;
  final Future<void> Function(ImportResult result) _onImported;
  final void Function() _onError;

  StreamSubscription<void>? _changeSubscription;
  bool _disposed = false;
  bool _scanning = false;
  bool _scanAgain = false;
  bool _observing = false;
  Future<void>? _drainFuture;
  bool _drainAgain = false;
  Future<void>? _resumeFuture;

  Future<void> initialize() async {
    try {
      final settings = await _settingsRepository.load();
      if (!settings.hasStoredPreference) {
        final permission = await _source.permissionStatus();
        if (permission == MediaPermissionStatus.fullAccess) {
          await _activateFromCurrentBaseline();
          return;
        }
        await _source.configureBackgroundMonitoring(
          enabled: false,
          lastMediaId: settings.lastMediaId ?? 0,
        );
        await _drainInbox();
        _onStateChanged(_stateForPermission(permission));
        return;
      }
      if (!settings.enabled) {
        await _source.configureBackgroundMonitoring(
          enabled: false,
          lastMediaId: settings.lastMediaId ?? 0,
        );
        await _drainInbox();
        _onStateChanged(AutomaticImportUiState.disabled);
        return;
      }
      await _resumeEnabled(settings.lastMediaId ?? 0);
    } catch (_) {
      _onStateChanged(AutomaticImportUiState.unavailable);
    }
  }

  Future<MediaPermissionStatus> enable() async {
    try {
      final permission = await _source.requestPermission();
      if (permission != MediaPermissionStatus.fullAccess) {
        _onStateChanged(_stateForPermission(permission));
        return permission;
      }
      await _activateFromCurrentBaseline();
      return permission;
    } catch (_) {
      _onStateChanged(AutomaticImportUiState.unavailable);
      _onError();
      rethrow;
    }
  }

  Future<MediaPermissionStatus> requestPermissionAndApplyDefault() async {
    try {
      final settings = await _settingsRepository.load();
      final permission = await _source.requestPermission();
      if (permission != MediaPermissionStatus.fullAccess) {
        _onStateChanged(_stateForPermission(permission));
        return permission;
      }
      if (!settings.hasStoredPreference) {
        await _activateFromCurrentBaseline();
      } else if (settings.enabled) {
        await resume();
      } else {
        _onStateChanged(AutomaticImportUiState.disabled);
      }
      return permission;
    } catch (_) {
      _onStateChanged(AutomaticImportUiState.unavailable);
      _onError();
      rethrow;
    }
  }

  Future<void> _activateFromCurrentBaseline() async {
    final baseline = await _source.currentMaxMediaId();
    await _settingsRepository.enable(baselineMediaId: baseline);
    try {
      await _source.configureBackgroundMonitoring(
        enabled: true,
        lastMediaId: baseline,
        resetBaseline: true,
      );
    } catch (_) {
      await _settingsRepository.disable();
      rethrow;
    }
    _onStateChanged(AutomaticImportUiState.active);
    await _drainInbox();
    await _beginObserving();
  }

  Future<bool> disable() async {
    await _stopObserving();
    try {
      final settings = await _settingsRepository.load();
      var nativeDisabled = true;
      try {
        await _source.configureBackgroundMonitoring(
          enabled: false,
          lastMediaId: settings.lastMediaId ?? 0,
        );
      } catch (_) {
        nativeDisabled = false;
      }
      await _settingsRepository.disable();
      _onStateChanged(
        nativeDisabled
            ? AutomaticImportUiState.disabled
            : AutomaticImportUiState.unavailable,
      );
      if (!nativeDisabled) _onError();
      return nativeDisabled;
    } catch (_) {
      _onError();
      await resume();
      rethrow;
    }
  }

  Future<void> resume() {
    final running = _resumeFuture;
    if (running != null) return running;
    final future = _performResume();
    _resumeFuture = future;
    return future.whenComplete(() => _resumeFuture = null);
  }

  Future<void> _performResume() async {
    if (_disposed) return;
    try {
      final settings = await _settingsRepository.load();
      if (!settings.enabled) return;
      await _resumeEnabled(settings.lastMediaId ?? 0);
    } catch (_) {
      _onStateChanged(AutomaticImportUiState.unavailable);
    }
  }

  Future<void> openAppSettings() => _source.openAppSettings();

  Future<MediaPermissionStatus> permissionStatus() =>
      _source.permissionStatus();

  Future<void> _resumeEnabled(int lastMediaId) async {
    final permission = await _source.permissionStatus();
    if (permission != MediaPermissionStatus.fullAccess) {
      await _stopObserving();
      await _source.configureBackgroundMonitoring(
        enabled: false,
        lastMediaId: lastMediaId,
      );
      _onStateChanged(_stateForPermission(permission));
      return;
    }
    final backgroundStatus = await _source.configureBackgroundMonitoring(
      enabled: true,
      lastMediaId: lastMediaId,
    );
    final reconciledMarker = backgroundStatus.lastMediaId > lastMediaId
        ? backgroundStatus.lastMediaId
        : lastMediaId;
    if (reconciledMarker > lastMediaId) {
      await _settingsRepository.updateMarker(reconciledMarker);
    }
    _onStateChanged(AutomaticImportUiState.active);
    await _drainInbox();
    await _scan(lastMediaId: reconciledMarker);
    await _beginObserving();
  }

  Future<void> _drainInbox() {
    final running = _drainFuture;
    if (running != null) {
      _drainAgain = true;
      return running;
    }
    final future = _performInboxDrain();
    _drainFuture = future;
    return future.whenComplete(() {
      _drainFuture = null;
    });
  }

  Future<void> _performInboxDrain() async {
    do {
      _drainAgain = false;
      final entries = await _source.loadBackgroundInbox();
      final importedItems = <MediaItem>[];
      var duplicateCount = 0;
      var rejectedCount = 0;
      for (final entry in entries) {
        if (_disposed) return;
        if (!await File(entry.privatePath).exists()) {
          try {
            await _source.rejectBackgroundEntry(entry.entryId);
          } catch (_) {
            // A entrada inválida permanece isolada para uma limpeza futura.
          }
          rejectedCount++;
          continue;
        }
        try {
          final result = await _mediaRepository.importScreenshots([
            SelectedScreenshot(
              path: entry.privatePath,
              mimeType: entry.mimeType,
              capturedAt: entry.capturedAt,
              captureAppContext: entry.captureAppContext,
            ),
          ], origin: ImportOrigin.automatic);
          importedItems.addAll(result.importedItems);
          duplicateCount += result.duplicateCount;
          rejectedCount += result.rejectedCount;
          if (result.importedItems.isNotEmpty || result.duplicateCount > 0) {
            await _source.acknowledgeBackgroundEntry(entry.entryId);
          }
        } catch (_) {
          rejectedCount++;
          // Mantém a entrada durável para uma tentativa futura.
        }
      }
      if (importedItems.isNotEmpty || duplicateCount > 0 || rejectedCount > 0) {
        await _onImported(
          ImportResult(
            importedItems: importedItems,
            duplicateCount: duplicateCount,
            rejectedCount: rejectedCount,
          ),
        );
      }
    } while (_drainAgain && !_disposed);
  }

  AutomaticImportUiState _stateForPermission(MediaPermissionStatus status) {
    return switch (status) {
      MediaPermissionStatus.limitedAccess =>
        AutomaticImportUiState.limitedAccess,
      MediaPermissionStatus.unsupported => AutomaticImportUiState.unavailable,
      _ => AutomaticImportUiState.accessRequired,
    };
  }

  Future<void> _beginObserving() async {
    if (_disposed || _observing) return;
    _observing = true;
    _changeSubscription ??= _source.changes.listen(
      (_) => unawaited(_scan()),
      onError: (_) => _onStateChanged(AutomaticImportUiState.unavailable),
    );
    try {
      await _source.startObserving();
    } catch (_) {
      _observing = false;
      await _changeSubscription?.cancel();
      _changeSubscription = null;
      rethrow;
    }
  }

  Future<void> _stopObserving() async {
    _observing = false;
    await _changeSubscription?.cancel();
    _changeSubscription = null;
    try {
      await _source.stopObserving();
    } catch (_) {
      // A preferência local ainda pode ser desativada com segurança.
    }
  }

  Future<void> _scan({int? lastMediaId}) async {
    if (_disposed) return;
    if (_scanning) {
      _scanAgain = true;
      return;
    }
    _scanning = true;
    try {
      do {
        _scanAgain = false;
        final marker =
            lastMediaId ?? (await _settingsRepository.load()).lastMediaId ?? 0;
        lastMediaId = null;
        final batch = await _source.scanAfter(marker);
        late final ImportResult result;
        try {
          final imported = await _mediaRepository.importScreenshots(
            batch.items
                .map(
                  (item) => SelectedScreenshot(
                    path: item.temporaryPath,
                    mimeType: item.mimeType,
                    capturedAt: item.capturedAt,
                    captureAppContext: item.captureAppContext,
                  ),
                )
                .toList(growable: false),
            origin: ImportOrigin.automatic,
          );
          result = ImportResult(
            importedItems: imported.importedItems,
            duplicateCount: imported.duplicateCount,
            rejectedCount: imported.rejectedCount + batch.rejectedCount,
          );
          await _settingsRepository.updateMarker(batch.lastExaminedMediaId);
          await _source.configureBackgroundMonitoring(
            enabled: true,
            lastMediaId: batch.lastExaminedMediaId,
          );
        } finally {
          for (final item in batch.items) {
            try {
              await _source.deleteTemporary(item.temporaryPath);
            } catch (_) {
              // O temporário fica restrito ao cache privado e poderá ser limpo
              // pelo sistema operacional.
            }
          }
        }
        if (result.importedItems.isNotEmpty ||
            result.duplicateCount > 0 ||
            result.rejectedCount > 0) {
          await _onImported(result);
        }
      } while (_scanAgain && !_disposed);
    } catch (_) {
      _onError();
    } finally {
      _scanning = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _stopObserving();
  }
}

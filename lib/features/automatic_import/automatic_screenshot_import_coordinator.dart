import 'dart:async';

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

  Future<void> initialize() async {
    try {
      final settings = await _settingsRepository.load();
      if (!settings.enabled) {
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
      final baseline = await _source.currentMaxMediaId();
      await _settingsRepository.enable(baselineMediaId: baseline);
      _onStateChanged(AutomaticImportUiState.active);
      await _beginObserving();
      return permission;
    } catch (_) {
      _onStateChanged(AutomaticImportUiState.unavailable);
      _onError();
      return MediaPermissionStatus.unsupported;
    }
  }

  Future<void> disable() async {
    await _stopObserving();
    try {
      await _settingsRepository.disable();
      _onStateChanged(AutomaticImportUiState.disabled);
    } catch (_) {
      _onError();
    }
  }

  Future<void> resume() async {
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

  Future<void> _resumeEnabled(int lastMediaId) async {
    final permission = await _source.permissionStatus();
    if (permission != MediaPermissionStatus.fullAccess) {
      await _stopObserving();
      _onStateChanged(_stateForPermission(permission));
      return;
    }
    _onStateChanged(AutomaticImportUiState.active);
    await _scan(lastMediaId: lastMediaId);
    await _beginObserving();
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

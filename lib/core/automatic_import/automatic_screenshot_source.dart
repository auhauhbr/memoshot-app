import '../../features/library/domain/capture_app_context.dart';

enum MediaPermissionStatus {
  notRequested,
  fullAccess,
  limitedAccess,
  denied,
  permanentlyDenied,
  unsupported,
}

class AutomaticScreenshotCandidate {
  const AutomaticScreenshotCandidate({
    required this.mediaId,
    required this.temporaryPath,
    this.mimeType,
    this.capturedAt,
    this.captureAppContext,
  });

  final int mediaId;
  final String temporaryPath;
  final String? mimeType;
  final DateTime? capturedAt;
  final CaptureAppContext? captureAppContext;
}

class AutomaticScreenshotBatch {
  const AutomaticScreenshotBatch({
    required this.lastExaminedMediaId,
    required this.items,
    this.rejectedCount = 0,
  });

  final int lastExaminedMediaId;
  final List<AutomaticScreenshotCandidate> items;
  final int rejectedCount;
}

class BackgroundScreenshotEntry {
  const BackgroundScreenshotEntry({
    required this.entryId,
    required this.mediaId,
    required this.privatePath,
    this.mimeType,
    this.capturedAt,
    this.captureAppContext,
  });

  final String entryId;
  final int mediaId;
  final String privatePath;
  final String? mimeType;
  final DateTime? capturedAt;
  final CaptureAppContext? captureAppContext;
}

class BackgroundMonitorStatus {
  const BackgroundMonitorStatus({
    required this.available,
    required this.enabled,
    required this.lastMediaId,
  });

  final bool available;
  final bool enabled;
  final int lastMediaId;
}

abstract interface class AutomaticScreenshotSource {
  Stream<void> get changes;

  Future<MediaPermissionStatus> permissionStatus();

  Future<MediaPermissionStatus> requestPermission();

  Future<void> openAppSettings();

  Future<int> currentMaxMediaId();

  Future<AutomaticScreenshotBatch> scanAfter(int lastMediaId);

  Future<void> startObserving();

  Future<void> stopObserving();

  Future<void> deleteTemporary(String path);

  Future<BackgroundMonitorStatus> configureBackgroundMonitoring({
    required bool enabled,
    required int lastMediaId,
    bool resetBaseline = false,
  });

  Future<List<BackgroundScreenshotEntry>> loadBackgroundInbox();

  Future<int> backgroundInboxPendingCount();

  Future<void> acknowledgeBackgroundEntry(String entryId);

  Future<void> rejectBackgroundEntry(String entryId);
}

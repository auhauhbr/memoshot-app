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
  });

  final int mediaId;
  final String temporaryPath;
  final String? mimeType;
  final DateTime? capturedAt;
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
}

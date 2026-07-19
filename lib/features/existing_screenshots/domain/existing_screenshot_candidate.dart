enum ExistingScreenshotAvailability { available, unavailable }

class ExistingScreenshotCandidate {
  const ExistingScreenshotCandidate({
    required this.sourceKey,
    required this.mediaStoreId,
    required this.volumeName,
    required this.contentUri,
    required this.mimeType,
    required this.capturedAt,
    required this.dateModified,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.discoveredAt,
    required this.lastSeenAt,
    required this.availability,
  });

  final String sourceKey;
  final int mediaStoreId;
  final String volumeName;
  final String contentUri;
  final String? mimeType;
  final DateTime? capturedAt;
  final DateTime? dateModified;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final DateTime discoveredAt;
  final DateTime lastSeenAt;
  final ExistingScreenshotAvailability availability;

  ExistingScreenshotCandidate seenAt(DateTime value) {
    return ExistingScreenshotCandidate(
      sourceKey: sourceKey,
      mediaStoreId: mediaStoreId,
      volumeName: volumeName,
      contentUri: contentUri,
      mimeType: mimeType,
      capturedAt: capturedAt,
      dateModified: dateModified,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
      discoveredAt: discoveredAt,
      lastSeenAt: value,
      availability: ExistingScreenshotAvailability.available,
    );
  }
}

class ExistingScreenshotInventorySummary {
  const ExistingScreenshotInventorySummary({
    required this.availableCount,
    required this.unavailableCount,
    required this.lastCompletedScanAt,
    required this.lastScanWasPartial,
  });

  const ExistingScreenshotInventorySummary.empty()
    : availableCount = 0,
      unavailableCount = 0,
      lastCompletedScanAt = null,
      lastScanWasPartial = false;

  final int availableCount;
  final int unavailableCount;
  final DateTime? lastCompletedScanAt;
  final bool lastScanWasPartial;

  bool get hasCompletedScan => lastCompletedScanAt != null;
}

import 'existing_screenshot_candidate.dart';

class ExistingScreenshotScanCursor {
  const ExistingScreenshotScanCursor({
    required this.volumeName,
    required this.mediaStoreId,
  });

  final String volumeName;
  final int mediaStoreId;
}

class ExistingScreenshotScanPage {
  const ExistingScreenshotScanPage({
    required this.examinedCount,
    required this.recognizedCount,
    required this.hasNext,
    required this.nextCursor,
    required this.items,
  });

  final int examinedCount;
  final int recognizedCount;
  final bool hasNext;
  final ExistingScreenshotScanCursor? nextCursor;
  final List<ExistingScreenshotCandidate> items;
}

class ExistingScreenshotScanProgress {
  const ExistingScreenshotScanProgress({
    required this.examinedCount,
    required this.recognizedCount,
  });

  final int examinedCount;
  final int recognizedCount;
}

enum ExistingScreenshotScanOutcome { completed, cancelled, accessUnavailable }

class ExistingScreenshotScanResult {
  const ExistingScreenshotScanResult({
    required this.outcome,
    required this.examinedCount,
    required this.recognizedCount,
    required this.partialAccess,
  });

  final ExistingScreenshotScanOutcome outcome;
  final int examinedCount;
  final int recognizedCount;
  final bool partialAccess;
}

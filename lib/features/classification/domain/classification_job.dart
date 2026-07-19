enum ClassificationJobState { pending, processing, retryScheduled, failed }

enum ClassificationJobErrorCode {
  processorFailure,
  suggestionPersistenceFailure,
  missingOcr,
  unknownFailure,
}

class ClassificationJob {
  const ClassificationJob({
    required this.mediaItemId,
    required this.state,
    required this.attempts,
    required this.availableAt,
    required this.engineVersion,
    required this.createdAt,
    required this.updatedAt,
    this.processingStartedAt,
    this.lastErrorCode,
  });

  final int mediaItemId;
  final ClassificationJobState state;
  final int attempts;
  final DateTime availableAt;
  final int engineVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? processingStartedAt;
  final ClassificationJobErrorCode? lastErrorCode;
}

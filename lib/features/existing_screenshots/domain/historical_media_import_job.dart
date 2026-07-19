enum HistoricalMediaImportJobState {
  pending,
  processing,
  retryScheduled,
  failed,
}

enum HistoricalMediaImportErrorCode {
  candidateUnavailable,
  candidateMissing,
  invalidReference,
  mediaPersistenceFailure,
  temporaryDatabaseFailure,
  unknownFailure,
}

class HistoricalMediaImportJob {
  const HistoricalMediaImportJob({
    required this.sourceKey,
    required this.state,
    required this.attempts,
    required this.availableAt,
    required this.createdAt,
    required this.updatedAt,
    this.processingStartedAt,
    this.lastErrorCode,
  });

  final String sourceKey;
  final HistoricalMediaImportJobState state;
  final int attempts;
  final DateTime availableAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? processingStartedAt;
  final HistoricalMediaImportErrorCode? lastErrorCode;
}

enum HistoricalPreparationState { notStarted, active, paused, completed }

class HistoricalPreparationProgress {
  const HistoricalPreparationProgress({
    required this.availableCount,
    required this.preparedCount,
    required this.pendingCount,
    required this.processingCount,
    required this.retryScheduledCount,
    required this.failedCount,
    required this.unavailableCount,
    required this.state,
  });

  final int availableCount;
  final int preparedCount;
  final int pendingCount;
  final int processingCount;
  final int retryScheduledCount;
  final int failedCount;
  final int unavailableCount;
  final HistoricalPreparationState state;

  int get remainingCount =>
      (availableCount - preparedCount).clamp(0, availableCount);

  int get waitingCount => pendingCount + retryScheduledCount;

  bool get hasActiveJobs =>
      pendingCount > 0 || processingCount > 0 || retryScheduledCount > 0;
}

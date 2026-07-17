enum ProcessingJobStatus { pending, processing, completed, failed }

class ProcessingJob {
  const ProcessingJob({
    required this.id,
    required this.mediaItemId,
    required this.status,
    required this.attempts,
    required this.createdAt,
    this.errorCode,
    this.startedAt,
    this.finishedAt,
  });

  final int id;
  final int mediaItemId;
  final ProcessingJobStatus status;
  final int attempts;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
}

enum OcrItemState {
  notScheduled,
  pending,
  processing,
  completedWithText,
  completedWithoutText,
  failed,
}

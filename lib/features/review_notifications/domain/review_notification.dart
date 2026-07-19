enum ReviewNotificationPermission { granted, denied, blocked, unsupported }

class ReviewNotificationSnapshot {
  const ReviewNotificationSnapshot({
    required this.pendingCount,
    required this.latestPendingCreatedAt,
    required this.latestPendingMediaItemId,
  });

  const ReviewNotificationSnapshot.empty()
    : pendingCount = 0,
      latestPendingCreatedAt = null,
      latestPendingMediaItemId = null;

  final int pendingCount;
  final DateTime? latestPendingCreatedAt;
  final int? latestPendingMediaItemId;

  String? get marker {
    final createdAt = latestPendingCreatedAt;
    final mediaItemId = latestPendingMediaItemId;
    if (pendingCount <= 0 || createdAt == null || mediaItemId == null) {
      return null;
    }
    return '${createdAt.microsecondsSinceEpoch}:$mediaItemId';
  }
}

class ReviewNotificationState {
  const ReviewNotificationState({
    required this.enabled,
    required this.promptHandled,
    required this.permission,
  });

  const ReviewNotificationState.disabled()
    : enabled = false,
      promptHandled = false,
      permission = ReviewNotificationPermission.denied;

  final bool enabled;
  final bool promptHandled;
  final ReviewNotificationPermission permission;

  bool get canPublish =>
      enabled && permission == ReviewNotificationPermission.granted;
}

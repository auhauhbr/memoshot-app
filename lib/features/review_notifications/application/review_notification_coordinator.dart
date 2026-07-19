import '../domain/review_notification.dart';

abstract interface class ReviewNotificationGateway {
  Future<ReviewNotificationState> loadState();

  Future<ReviewNotificationState> requestPermissionAndEnable();

  Future<void> disable();

  Future<void> dismissPrompt();

  Future<void> openAndroidSettings();

  Future<void> synchronize(ReviewNotificationSnapshot snapshot);

  Future<void> cancel();
}

abstract interface class ReviewNotificationSnapshotRepository {
  Future<ReviewNotificationSnapshot> loadReviewNotificationSnapshot();
}

class ReviewNotificationCoordinator {
  const ReviewNotificationCoordinator({
    required ReviewNotificationSnapshotRepository snapshotRepository,
    required ReviewNotificationGateway gateway,
  }) : this._(snapshotRepository, gateway);

  const ReviewNotificationCoordinator._(
    this._snapshotRepository,
    this._gateway,
  );

  final ReviewNotificationSnapshotRepository _snapshotRepository;
  final ReviewNotificationGateway _gateway;

  Future<ReviewNotificationState> loadState() => _gateway.loadState();

  Future<ReviewNotificationState> enable() async {
    final state = await _gateway.requestPermissionAndEnable();
    if (state.canPublish) await synchronize();
    return state;
  }

  Future<void> disable() => _gateway.disable();

  Future<void> dismissPrompt() => _gateway.dismissPrompt();

  Future<void> openAndroidSettings() => _gateway.openAndroidSettings();

  Future<void> synchronize() async {
    try {
      final state = await _gateway.loadState();
      if (!state.enabled) {
        await _gateway.cancel();
        return;
      }
      if (!state.canPublish) return;
      final snapshot = await _snapshotRepository
          .loadReviewNotificationSnapshot();
      if (snapshot.pendingCount == 0) {
        await _gateway.cancel();
        return;
      }
      await _gateway.synchronize(snapshot);
    } catch (_) {
      // Notificações nunca invalidam OCR, classificação ou decisões de revisão.
    }
  }
}

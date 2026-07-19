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
  }) : this._(gateway);

  const ReviewNotificationCoordinator._(this._gateway);

  final ReviewNotificationGateway _gateway;

  Future<ReviewNotificationState> loadState() => _gateway.loadState();

  Future<ReviewNotificationState> enable() async {
    await _gateway.disable();
    await _gateway.cancel();
    return _gateway.loadState();
  }

  Future<void> disable() => _gateway.disable();

  Future<void> dismissPrompt() => _gateway.dismissPrompt();

  Future<void> openAndroidSettings() => _gateway.openAndroidSettings();

  Future<void> synchronize() async {
    try {
      await _gateway.cancel();
    } catch (_) {
      // Notificações nunca invalidam OCR, classificação ou decisões de revisão.
    }
  }
}

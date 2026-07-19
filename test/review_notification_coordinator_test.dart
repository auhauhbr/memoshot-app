import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/features/review_notifications/application/review_notification_coordinator.dart';
import 'package:memoshot/features/review_notifications/domain/review_notification.dart';

void main() {
  test('sincronização sempre cancela e nunca consulta ou publica', () async {
    final repository = _SnapshotRepository();
    final gateway = _Gateway();
    final coordinator = ReviewNotificationCoordinator(
      snapshotRepository: repository,
      gateway: gateway,
    );

    await coordinator.synchronize();

    expect(gateway.cancelCount, 1);
    expect(gateway.publishCount, 0);
    expect(repository.loadCount, 0);
  });

  test(
    'ativação antiga não solicita permissão e permanece desativada',
    () async {
      final gateway = _Gateway();
      final coordinator = ReviewNotificationCoordinator(
        snapshotRepository: _SnapshotRepository(),
        gateway: gateway,
      );

      final state = await coordinator.enable();

      expect(state.enabled, isFalse);
      expect(gateway.requestCount, 0);
      expect(gateway.disableCount, 1);
      expect(gateway.cancelCount, 1);
    },
  );

  test('falha ao cancelar é isolada do processamento headless', () async {
    final gateway = _Gateway()..cancelError = StateError('indisponível');
    final coordinator = ReviewNotificationCoordinator(
      snapshotRepository: _SnapshotRepository(),
      gateway: gateway,
    );

    await expectLater(coordinator.synchronize(), completes);
  });
}

class _SnapshotRepository implements ReviewNotificationSnapshotRepository {
  int loadCount = 0;

  @override
  Future<ReviewNotificationSnapshot> loadReviewNotificationSnapshot() async {
    loadCount++;
    return const ReviewNotificationSnapshot.empty();
  }
}

class _Gateway implements ReviewNotificationGateway {
  int requestCount = 0;
  int disableCount = 0;
  int cancelCount = 0;
  int publishCount = 0;
  Object? cancelError;

  @override
  Future<ReviewNotificationState> loadState() async =>
      const ReviewNotificationState.disabled();

  @override
  Future<ReviewNotificationState> requestPermissionAndEnable() async {
    requestCount++;
    return const ReviewNotificationState.disabled();
  }

  @override
  Future<void> disable() async => disableCount++;

  @override
  Future<void> dismissPrompt() async {}

  @override
  Future<void> openAndroidSettings() async {}

  @override
  Future<void> synchronize(ReviewNotificationSnapshot snapshot) async {
    publishCount++;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    if (cancelError case final error?) throw error;
  }
}

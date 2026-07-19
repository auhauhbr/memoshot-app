import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/features/review_notifications/application/review_notification_coordinator.dart';
import 'package:memoshot/features/review_notifications/domain/review_notification.dart';

void main() {
  const empty = ReviewNotificationSnapshot.empty();
  final one = ReviewNotificationSnapshot(
    pendingCount: 1,
    latestPendingCreatedAt: DateTime.utc(2026, 7, 19),
    latestPendingMediaItemId: 7,
  );

  test('função desativada cancela sem consultar snapshot', () async {
    final repository = _SnapshotRepository(one);
    final gateway = _Gateway(const ReviewNotificationState.disabled());
    final coordinator = ReviewNotificationCoordinator(
      snapshotRepository: repository,
      gateway: gateway,
    );

    await coordinator.synchronize();

    expect(gateway.cancelCount, 1);
    expect(repository.loadCount, 0);
    expect(gateway.snapshots, isEmpty);
  });

  test('permissão ausente não publica', () async {
    final repository = _SnapshotRepository(one);
    final gateway = _Gateway(
      const ReviewNotificationState(
        enabled: true,
        promptHandled: true,
        permission: ReviewNotificationPermission.denied,
      ),
    );
    final coordinator = ReviewNotificationCoordinator(
      snapshotRepository: repository,
      gateway: gateway,
    );

    await coordinator.synchronize();

    expect(repository.loadCount, 0);
    expect(gateway.snapshots, isEmpty);
  });

  test('uma ou várias pendências enviam somente snapshot técnico', () async {
    final repository = _SnapshotRepository(one);
    final gateway = _Gateway(_enabledState);
    final coordinator = ReviewNotificationCoordinator(
      snapshotRepository: repository,
      gateway: gateway,
    );

    await coordinator.synchronize();
    repository.snapshot = ReviewNotificationSnapshot(
      pendingCount: 4,
      latestPendingCreatedAt: DateTime.utc(2026, 7, 19, 1),
      latestPendingMediaItemId: 8,
    );
    await coordinator.synchronize();

    expect(gateway.snapshots.map((item) => item.pendingCount), [1, 4]);
    expect(gateway.snapshots.last.marker, endsWith(':8'));
  });

  test('fila vazia cancela notificação', () async {
    final gateway = _Gateway(_enabledState);
    final coordinator = ReviewNotificationCoordinator(
      snapshotRepository: _SnapshotRepository(empty),
      gateway: gateway,
    );

    await coordinator.synchronize();

    expect(gateway.cancelCount, 1);
    expect(gateway.snapshots, isEmpty);
  });

  test('ativação é explícita e sincroniza somente quando concedida', () async {
    final granted = _Gateway(_enabledState);
    final coordinator = ReviewNotificationCoordinator(
      snapshotRepository: _SnapshotRepository(one),
      gateway: granted,
    );

    final state = await coordinator.enable();

    expect(state.enabled, isTrue);
    expect(granted.requestCount, 1);
    expect(granted.snapshots, [one]);

    final denied = _Gateway(
      const ReviewNotificationState(
        enabled: false,
        promptHandled: true,
        permission: ReviewNotificationPermission.denied,
      ),
    );
    await ReviewNotificationCoordinator(
      snapshotRepository: _SnapshotRepository(one),
      gateway: denied,
    ).enable();
    expect(denied.requestCount, 1);
    expect(denied.snapshots, isEmpty);
  });

  test(
    'desativação, convite e configurações delegam sem alterar fila',
    () async {
      final repository = _SnapshotRepository(one);
      final gateway = _Gateway(_enabledState);
      final coordinator = ReviewNotificationCoordinator(
        snapshotRepository: repository,
        gateway: gateway,
      );

      await coordinator.disable();
      await coordinator.dismissPrompt();
      await coordinator.openAndroidSettings();

      expect(gateway.disableCount, 1);
      expect(gateway.dismissCount, 1);
      expect(gateway.settingsCount, 1);
      expect(repository.loadCount, 0);
    },
  );

  test('falha nativa é isolada de classificação e headless', () async {
    final gateway = _Gateway(_enabledState)..synchronizeError = StateError('x');
    final coordinator = ReviewNotificationCoordinator(
      snapshotRepository: _SnapshotRepository(one),
      gateway: gateway,
    );

    await expectLater(coordinator.synchronize(), completes);
  });
}

const _enabledState = ReviewNotificationState(
  enabled: true,
  promptHandled: true,
  permission: ReviewNotificationPermission.granted,
);

class _SnapshotRepository implements ReviewNotificationSnapshotRepository {
  _SnapshotRepository(this.snapshot);

  ReviewNotificationSnapshot snapshot;
  int loadCount = 0;

  @override
  Future<ReviewNotificationSnapshot> loadReviewNotificationSnapshot() async {
    loadCount++;
    return snapshot;
  }
}

class _Gateway implements ReviewNotificationGateway {
  _Gateway(this.state);

  ReviewNotificationState state;
  Object? synchronizeError;
  int requestCount = 0;
  int disableCount = 0;
  int dismissCount = 0;
  int settingsCount = 0;
  int cancelCount = 0;
  final List<ReviewNotificationSnapshot> snapshots = [];

  @override
  Future<ReviewNotificationState> loadState() async => state;

  @override
  Future<ReviewNotificationState> requestPermissionAndEnable() async {
    requestCount++;
    return state;
  }

  @override
  Future<void> disable() async => disableCount++;

  @override
  Future<void> dismissPrompt() async => dismissCount++;

  @override
  Future<void> openAndroidSettings() async => settingsCount++;

  @override
  Future<void> synchronize(ReviewNotificationSnapshot snapshot) async {
    if (synchronizeError != null) throw synchronizeError!;
    snapshots.add(snapshot);
  }

  @override
  Future<void> cancel() async => cancelCount++;
}

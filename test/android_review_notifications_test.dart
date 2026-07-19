import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = 'android/app/src/main/kotlin/br/com/jeffersont/memoshot';
  late String activity;
  late String worker;
  late String manifest;

  setUpAll(() {
    activity = File('$root/MainActivity.kt').readAsStringSync();
    worker = File(
      '$root/MemoShotBackgroundProcessingWorker.kt',
    ).readAsStringSync();
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
  });

  test('POST_NOTIFICATIONS não é declarado', () {
    expect(manifest, isNot(contains('android.permission.POST_NOTIFICATIONS')));
    expect(manifest, isNot(contains('android.permission.FOREGROUND_SERVICE')));
    expect(manifest, isNot(contains('android.permission.INTERNET')));
  });

  test('produção não registra bridge nem publica notificações de revisão', () {
    expect(activity, isNot(contains('ReviewNotificationBridge(')));
    expect(activity, isNot(contains('publishDeferredIfNeeded')));
    expect(worker, contains('ReviewNotificationBridge'));
    expect(worker, isNot(contains('notificationManager.notify')));
  });

  test('notificação antiga é cancelada e intent antiga é consumida', () {
    expect(activity, contains('cancelLegacyReviewNotification()'));
    expect(
      activity,
      contains('manager.cancel(ReviewNotificationPolicy.NOTIFICATION_ID)'),
    );
    expect(activity, contains('setEnabled(false)'));
    expect(activity, contains('consumeLegacyReviewIntent(intent)'));
    expect(activity, contains('intent.removeExtra'));
    expect(activity, contains('intent.action = null'));
    expect(activity, contains('override fun onNewIntent'));
  });
}

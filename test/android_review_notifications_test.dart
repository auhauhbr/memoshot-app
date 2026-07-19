import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = 'android/app/src/main/kotlin/br/com/jeffersont/memoshot';
  late String bridge;
  late String policy;
  late String navigation;
  late String activity;
  late String worker;
  late String manifest;

  setUpAll(() {
    bridge = File('$root/ReviewNotificationBridge.kt').readAsStringSync();
    policy = File('$root/ReviewNotificationPolicy.kt').readAsStringSync();
    navigation = File('$root/ReviewNavigationBridge.kt').readAsStringSync();
    activity = File('$root/MainActivity.kt').readAsStringSync();
    worker = File(
      '$root/MemoShotBackgroundProcessingWorker.kt',
    ).readAsStringSync();
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
  });

  test('permissão é declarada sem serviços proibidos', () {
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, isNot(contains('android.permission.FOREGROUND_SERVICE')));
    expect(manifest, isNot(contains('android.permission.INTERNET')));
    expect(manifest, isNot(contains('<service')));
  });

  test('canal é privado, idempotente e não alarmante', () {
    expect(policy, contains('CHANNEL_ID = "memoshot_review"'));
    expect(bridge, contains('getNotificationChannel'));
    expect(bridge, contains('IMPORTANCE_DEFAULT'));
    expect(bridge, contains('VISIBILITY_PRIVATE'));
    expect(bridge, contains('CATEGORY_REMINDER'));
    expect(bridge, isNot(contains('setFullScreenIntent')));
    expect(bridge, isNot(contains('setCustomContentView')));
    expect(bridge, isNot(contains('setLargeIcon')));
  });

  test('notificação usa id fixo e PendingIntent imutável', () {
    expect(policy, contains('NOTIFICATION_ID = 9503'));
    expect(bridge, contains('PendingIntent.FLAG_IMMUTABLE'));
    expect(bridge, contains('setAutoCancel(true)'));
    expect(bridge, contains('MainActivity::class.java'));
  });

  test('permissão só é solicitada pela bridge com Activity', () {
    expect(bridge, contains('currentActivity == null'));
    expect(bridge, contains('currentActivity.requestPermissions'));
    expect(worker, contains('ReviewNotificationBridge'));
    expect(worker, isNot(contains('requestPermissions')));
  });

  test('primeiro plano suprime alerta e onPause libera pendência', () {
    expect(bridge, contains('FlutterEngineRuntimeState.isActivityVisible()'));
    expect(activity, contains('FlutterEngineRuntimeState.resumeActivity()'));
    expect(activity, contains('FlutterEngineRuntimeState.pauseActivity()'));
    expect(activity, contains('publishDeferredIfNeeded()'));
  });

  test('navegação aceita apenas reviewQueue e trata onNewIntent', () {
    expect(policy, contains('DESTINATION_REVIEW_QUEUE = "reviewQueue"'));
    expect(navigation, contains('acceptsDestination'));
    expect(navigation, contains('consumePendingDestination'));
    expect(navigation, contains('removeExtra'));
    expect(activity, contains('override fun onNewIntent'));
    expect(activity, contains('reviewNavigationBridge?.handleIntent(intent)'));
  });

  test('payload nativo não contém dados privados', () {
    for (final forbidden in [
      'ocrText',
      'privatePath',
      'suggestedCategory',
      'suggestedTags',
      'confidence',
      'evidence',
      'email',
      'phone',
    ]) {
      expect(bridge, isNot(contains(forbidden)));
    }
  });
}

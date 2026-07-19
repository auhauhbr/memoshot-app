import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = 'android/app/src/main/kotlin/br/com/jeffersont/memoshot';
  late String worker;
  late String scheduler;
  late String inboxBridge;
  late String mediaWorker;
  late String captureScheduler;
  late String manifest;
  late String runtimeState;
  late String activity;

  setUpAll(() {
    worker = File(
      '$root/MemoShotBackgroundProcessingWorker.kt',
    ).readAsStringSync();
    scheduler = File(
      '$root/BackgroundProcessingScheduler.kt',
    ).readAsStringSync();
    inboxBridge = File(
      '$root/BackgroundScreenshotInboxBridge.kt',
    ).readAsStringSync();
    mediaWorker = File('$root/ScreenshotMediaWorker.kt').readAsStringSync();
    captureScheduler = File(
      '$root/ScreenshotBackgroundScheduler.kt',
    ).readAsStringSync();
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    runtimeState = File(
      '$root/FlutterEngineRuntimeState.kt',
    ).readAsStringSync();
    activity = File('$root/MainActivity.kt').readAsStringSync();
  });

  test(
    'worker reutiliza engine headless para automação e acervo histórico',
    () {
      expect(worker, contains('CoroutineWorker'));
      expect(worker, isNot(contains('if (!state.isEnabled())')));
      expect(
        worker,
        contains('FlutterEngineRuntimeState.isUiEngineAttached()'),
      );
      expect(
        worker,
        contains('FlutterEngine(applicationContext, null, false)'),
      );
      expect(
        worker,
        contains('GeneratedPluginRegistrant.registerWith(engine)'),
      );
      expect(worker, contains('BackgroundScreenshotInboxBridge'));
      expect(worker, contains('AppPreferencesBridge'));
      expect(worker, contains('memoshotBackgroundEntrypoint'));
      expect(worker, isNot(contains('MainActivity')));
      expect(worker, isNot(contains('startActivity')));
    },
  );

  test('engine da interface impede concorrência e destruição retoma filas', () {
    expect(runtimeState, contains('AtomicBoolean'));
    expect(activity, contains('FlutterEngineRuntimeState.attachUiEngine()'));
    expect(activity, contains('FlutterEngineRuntimeState.detachUiEngine()'));
    expect(activity, contains('processingScheduler.enqueueIfEnabled()'));
    expect(activity, contains('enqueueHistoricalPreparation()'));
  });

  test('canal técnico mapeia resultados e nunca transporta conteúdo', () {
    expect(
      worker,
      contains('br.com.jeffersont.memoshot/background_processing'),
    );
    for (final method in [
      'ready',
      'completed',
      'retryableFailure',
      'terminalFailure',
      'cancelled',
    ]) {
      expect(worker, contains('"$method"'));
    }
    expect(worker, contains('Result.success'));
    expect(worker, contains('Result.retry'));
    expect(worker, contains('Result.failure'));
    for (final forbidden in [
      'fullText',
      'privatePath',
      'suggestedCategory',
      'suggestedTags',
      'evidence',
      'stackTrace',
    ]) {
      expect(worker, isNot(contains(forbidden)));
    }
  });

  test('timeouts, cancelamento e finally sempre destroem engine', () {
    expect(worker, contains('ENGINE_INITIALIZATION_TIMEOUT_MS = 30_000L'));
    expect(worker, contains('DART_RESPONSE_TIMEOUT_MS'));
    expect(worker, contains('withTimeout'));
    expect(worker, contains('CancellationException'));
    expect(worker, contains('NonCancellable + Dispatchers.Main'));
    expect(worker, contains('finally'));
    expect(worker, contains('engine.destroy()'));
    expect(worker, isNot(contains('static FlutterEngine')));
  });

  test('scheduler usa trabalho único e limita retries do WorkManager', () {
    expect(scheduler, contains('memoshot_background_processing'));
    expect(scheduler, contains('enqueueUniqueWork'));
    expect(scheduler, contains('ExistingWorkPolicy.APPEND_OR_REPLACE'));
    expect(scheduler, contains('setInitialDelay'));
    expect(scheduler, contains('cancelUniqueWork'));
    expect(worker, contains('MAX_WORK_MANAGER_ATTEMPTS = 3'));
    expect(scheduler, isNot(contains('PeriodicWorkRequest')));
    expect(scheduler, isNot(contains('AlarmManager')));
  });

  test(
    'captura agenda inbox e configuração ativa ou cancela processamento',
    () {
      expect(mediaWorker, contains('processingScheduler.enqueueIfEnabled()'));
      expect(mediaWorker, contains('inbox.pendingCount()'));
      expect(
        captureScheduler,
        contains('processingScheduler.enqueueIfEnabled()'),
      );
      expect(captureScheduler, contains('processingScheduler.cancel()'));
    },
  );

  test('bridge da inbox usa applicationContext e não exige Activity', () {
    expect(inboxBridge, contains('context.applicationContext'));
    expect(inboxBridge, contains('BackgroundScreenshotInboxHandler'));
    expect(inboxBridge, contains('listBackgroundInbox'));
    expect(inboxBridge, contains('acknowledgeBackgroundInbox'));
    expect(inboxBridge, contains('setMethodCallHandler(null)'));
    expect(inboxBridge, isNot(contains('android.app.Activity')));
    expect(inboxBridge, isNot(contains('startActivity')));
  });

  test('adiciona somente permissão de notificação sem serviço', () {
    expect(manifest, contains('POST_NOTIFICATIONS'));
    expect(manifest, isNot(contains('FOREGROUND_SERVICE')));
    expect(manifest, isNot(contains('<service')));
    expect(worker, contains('ReviewNotificationBridge'));
    expect(worker, isNot(contains('requestPermissions')));
    expect(worker, isNot(contains('Foreground')));
  });

  test('SDKs e WorkManager permanecem nas versões requeridas', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('compileSdk = 37'));
    expect(gradle, contains('targetSdk = 36'));
    expect(gradle, contains('minSdk = 24'));
    expect(gradle, contains('work-runtime-ktx:2.11.2'));
  });
}

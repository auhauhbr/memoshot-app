import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final kotlinRoot = 'android/app/src/main/kotlin/br/com/jeffersont/contexto';
  late String scheduler;
  late String worker;
  late String inbox;
  late String state;
  late String captureTime;

  setUpAll(() {
    scheduler = File(
      '$kotlinRoot/ScreenshotBackgroundScheduler.kt',
    ).readAsStringSync();
    worker = File('$kotlinRoot/ScreenshotMediaWorker.kt').readAsStringSync();
    inbox = File('$kotlinRoot/BackgroundScreenshotInbox.kt').readAsStringSync();
    state = File(
      '$kotlinRoot/NativeScreenshotMonitorState.kt',
    ).readAsStringSync();
    captureTime = File(
      '$kotlinRoot/MediaStoreCaptureTime.kt',
    ).readAsStringSync();
  });

  test('usa somente WorkManager Android 2.11.2', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('androidx.work:work-runtime-ktx:2.11.2'));
    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(contains('workmanager')),
    );
  });

  test('agenda trabalho único acionado por conteúdo sem periodicidade', () {
    expect(scheduler, contains('OneTimeWorkRequest.Builder'));
    expect(scheduler, contains('addContentUriTrigger'));
    expect(scheduler, contains('EXTERNAL_CONTENT_URI, true'));
    expect(scheduler, contains('setTriggerContentUpdateDelay'));
    expect(scheduler, contains('setTriggerContentMaxDelay'));
    expect(scheduler, contains('enqueueUniqueWork'));
    expect(scheduler, contains('ExistingWorkPolicy.APPEND_OR_REPLACE'));
    expect(scheduler, contains('cancelUniqueWork'));
    expect(scheduler, isNot(contains('PeriodicWorkRequest')));
    expect(scheduler, isNot(contains('AlarmManager')));
  });

  test('API 23 não agenda e API 24 habilita gatilho de conteúdo', () {
    expect(
      scheduler,
      contains('Build.VERSION.SDK_INT < Build.VERSION_CODES.N'),
    );
    expect(scheduler, contains('isAvailable'));
  });

  test('Worker valida preferência e permissão sem iniciar Flutter ou OCR', () {
    expect(worker, contains('!state.isEnabled()'));
    expect(worker, contains('!hasFullImageAccess()'));
    expect(worker, contains('state.disable()'));
    expect(worker, contains('Result.retry()'));
    expect(worker, contains('MAX_TRANSIENT_ATTEMPTS'));
    expect(worker, contains('scheduler.rearmFromWorker()'));
    expect(worker, isNot(contains('FlutterEngine')));
    expect(worker, isNot(contains('Drift')));
    expect(worker, isNot(contains('MlKit')));
    expect(worker, isNot(contains('TextRecognizer')));
  });

  test('Worker filtra MediaStore e avança marcador sem diminuir', () {
    expect(worker, contains('MediaStore.Images.Media.IS_PENDING'));
    expect(worker, contains('startsWith("image/")'));
    expect(worker, contains('ScreenshotNameHeuristic.isScreenshot'));
    expect(worker, contains('MediaStore.Images.Media._ID} ASC'));
    expect(worker, contains('state.advanceMarker(safeMarker)'));
    expect(state, contains('maxOf(marker(), candidate)'));
  });

  test('DATE_TAKEN tem prioridade e DATE_ADDED é convertido', () {
    expect(worker, contains('MediaStore.Images.Media.DATE_TAKEN'));
    expect(worker, contains('MediaStore.Images.Media.DATE_ADDED'));
    expect(worker, contains('MediaStoreCaptureTime.resolve'));
    expect(captureTime, contains('if (isValid(dateTakenMillis))'));
    expect(captureTime, contains('dateAddedSeconds * 1000L'));
    expect(captureTime, contains('timestampMillis > 0'));
  });

  test('inbox é durável, atômica e não armazena dados externos', () {
    expect(inbox, contains('context.filesDir'));
    expect(inbox, contains('background_screenshot_inbox'));
    expect(inbox, isNot(contains('cacheDir')));
    expect(inbox, contains('.part'));
    expect(inbox, contains('output.fd.sync()'));
    expect(inbox, contains('renameTo(imageFinal)'));
    expect(inbox, contains('renameTo(metadataFinal)'));
    expect(inbox, contains('format_version'));
    expect(inbox, contains('captured_at'));
    expect(inbox, contains('pendingCount()'));
    expect(inbox, contains('media_store_id'));
    expect(inbox, isNot(contains('content://')));
    expect(inbox, isNot(contains('DISPLAY_NAME')));
    expect(inbox, isNot(contains('RELATIVE_PATH')));
  });

  test('Worker e inbox fecham cursores e streams', () {
    expect(worker, contains(')?.use { cursor ->'));
    expect(worker, contains('openInputStream(uri)?.use'));
    expect(inbox, contains('FileOutputStream(target).use'));
  });
}

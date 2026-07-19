import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late String dartSource;

  setUpAll(() {
    final activityBridge = File(
      'android/app/src/main/kotlin/br/com/jeffersont/memoshot/'
      'ScreenshotMediaStoreBridge.kt',
    ).readAsStringSync();
    final inboxBridge = File(
      'android/app/src/main/kotlin/br/com/jeffersont/memoshot/'
      'BackgroundScreenshotInboxBridge.kt',
    ).readAsStringSync();
    final recognition = File(
      'android/app/src/main/kotlin/br/com/jeffersont/memoshot/'
      'ScreenshotRecognition.kt',
    ).readAsStringSync();
    source = '$activityBridge\n$inboxBridge\n$recognition';
    dartSource = File(
      'lib/core/automatic_import/'
      'method_channel_automatic_screenshot_source.dart',
    ).readAsStringSync();
  });

  test('canais MemoShot são idênticos nos lados Dart e Kotlin', () {
    for (final channel in [
      'br.com.jeffersont.memoshot/automatic_screenshots/methods',
      'br.com.jeffersont.memoshot/automatic_screenshots/events',
    ]) {
      expect(source, contains(channel));
      expect(dartSource, contains(channel));
    }
    expect(source, isNot(contains('br.com.jeffersont.contexto')));
    expect(dartSource, isNot(contains('br.com.jeffersont.contexto')));
  });

  test('bridge consulta somente imagens posteriores e finalizadas', () {
    expect(source, contains('MediaStore.Images.Media.EXTERNAL_CONTENT_URI'));
    expect(source, contains('MediaStore.Images.Media._ID} > ?'));
    expect(source, contains('MediaStore.Images.Media.IS_PENDING'));
    expect(source, contains('ScreenshotRecognition.isScreenshot'));
    expect(source, contains('MediaStore.Images.Media._ID} ASC'));
    expect(source, contains('MediaStore.Images.Media.DATE_TAKEN'));
    expect(source, contains('MediaStore.Images.Media.DATE_ADDED'));
    expect(source, contains('MediaStoreCaptureTime.resolve'));
  });

  test('heurística contempla nomes em inglês e português', () {
    expect(source, contains('"screenshot"'));
    expect(source, contains('"capturadetela"'));
    expect(source, contains('"capturasdetela"'));
    expect(source, contains('Normalizer.Form.NFD'));
  });

  test('bridge fecha recursos e remove observer e temporários próprios', () {
    expect(source, contains('query('));
    expect(source, contains(')?.use { cursor ->'));
    expect(source, contains('openInputStream(uri)?.use'));
    expect(source, contains('target.outputStream().use'));
    expect(source, contains('unregisterContentObserver'));
    expect(source, contains('candidate.parentFile == cacheRoot'));
  });
}

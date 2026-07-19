import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = 'android/app/src/main/kotlin/br/com/jeffersont/memoshot';
  late String bridge;
  late String activity;
  late String worker;
  late String manifest;

  setUpAll(() {
    bridge = File(
      '$root/ExistingScreenshotScannerBridge.kt',
    ).readAsStringSync();
    activity = File('$root/MainActivity.kt').readAsStringSync();
    worker = File('$root/ScreenshotMediaWorker.kt').readAsStringSync();
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
  });

  test('scanner usa applicationContext, páginas e cursor por ID', () {
    expect(bridge, contains('context.applicationContext'));
    expect(activity, contains('context = applicationContext'));
    expect(bridge, contains('PAGE_SIZE'));
    expect(bridge, contains('MediaStore.Images.Media._ID} > ?'));
    expect(bridge, isNot(contains('OFFSET')));
    expect(bridge, isNot(contains('Activity')));
  });

  test('scanner não abre imagem, calcula hash, OCR ou copia arquivo', () {
    for (final forbidden in [
      'openInputStream',
      'Bitmap',
      'File(',
      'SHA-256',
      'MessageDigest',
      'ocrText',
      'TextRecognizer',
      'WorkManager',
    ]) {
      expect(bridge, isNot(contains(forbidden)));
    }
  });

  test('payload não expõe nomes, caminhos, OCR ou localização', () {
    final payload = bridge.substring(
      bridge.indexOf('private fun candidatePayload'),
      bridge.indexOf('private fun availableVolumes'),
    );
    for (final forbidden in [
      'displayName',
      'relativePath',
      'DATA',
      'absolutePath',
      'ocr',
      'location',
      'latitude',
      'longitude',
      'exif',
    ]) {
      expect(payload.toLowerCase(), isNot(contains(forbidden.toLowerCase())));
    }
  });

  test('capturas novas e históricas compartilham reconhecimento', () {
    expect(bridge, contains('ScreenshotRecognition.isScreenshot'));
    expect(worker, contains('ScreenshotRecognition.isScreenshot'));
  });

  test('não adiciona permissão, worker ou componente exportado', () {
    expect(manifest, isNot(contains('FOREGROUND_SERVICE')));
    expect(manifest, isNot(contains('RECEIVE_BOOT_COMPLETED')));
    expect(manifest, isNot(contains('<service')));
    expect(bridge, isNot(contains('WorkRequest')));
    expect(bridge, isNot(contains('startActivity')));
  });

  test('cancelamento nativo usa CancellationSignal e sessão técnica', () {
    expect(bridge, contains('CancellationSignal'));
    expect(bridge, contains('activeSession'));
    expect(bridge, contains('cancelScan'));
  });
}

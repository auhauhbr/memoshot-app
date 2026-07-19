import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = 'android/app/src/main/kotlin/br/com/jeffersont/memoshot';
  late String bridge;
  late String policy;
  late String activity;
  late String headlessWorker;
  late String manifest;

  setUpAll(() {
    bridge = File('$root/MediaStoreContentBridge.kt').readAsStringSync();
    policy = File('$root/MediaStoreReferencePolicy.kt').readAsStringSync();
    activity = File('$root/MainActivity.kt').readAsStringSync();
    headlessWorker = File(
      '$root/MemoShotBackgroundProcessingWorker.kt',
    ).readAsStringSync();
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
  });

  test('bridge usa applicationContext na interface e engine headless', () {
    expect(bridge, contains('context.applicationContext'));
    expect(bridge, isNot(contains('Activity')));
    expect(activity, contains('MediaStoreContentBridge'));
    expect(headlessWorker, contains('MediaStoreContentBridge'));
  });

  test('reconstrói URI e rejeita referência arbitrária antes de abrir', () {
    expect(policy, contains('content://media/'));
    expect(policy, contains('canonicalUri'));
    expect(bridge, contains('MediaStoreReferencePolicy.isValid'));
    expect(bridge, contains('Uri.parse(canonical)'));
    expect(bridge, isNot(contains('Uri.parse(claimedUri)')));
  });

  test('miniatura e payload possuem limites centrais', () {
    expect(policy, contains('MAX_THUMBNAIL_DIMENSION = 512'));
    expect(policy, contains('MAX_THUMBNAIL_PAYLOAD_BYTES = 384 * 1024'));
    expect(bridge, contains('loadThumbnail'));
    expect(bridge, contains('compressLimited'));
    expect(bridge, isNot(contains('openInputStream')));
  });

  test(
    'payload não contém caminho, nome físico, OCR nem metadados privados',
    () {
      for (final forbidden in [
        'DISPLAY_NAME',
        'RELATIVE_PATH',
        'absolutePath',
        'privatePath',
        'fullText',
        'EXIF',
        'location',
        'ContentResolver.delete',
      ]) {
        expect(bridge, isNot(contains(forbidden)));
      }
      for (final status in [
        'available',
        'unavailable',
        'permissionDenied',
        'temporaryFailure',
      ]) {
        expect(bridge, contains(status));
      }
    },
  );

  test('não adiciona permissão, componente exportado ou WorkManager', () {
    expect(bridge, isNot(contains('WorkManager')));
    expect(bridge, isNot(contains('startActivity')));
    expect(manifest, isNot(contains('MANAGE_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('WRITE_EXTERNAL_STORAGE')));
  });
}

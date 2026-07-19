import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = 'android/app/src/main/kotlin/br/com/jeffersont/memoshot';
  late String bridge;
  late String policy;
  late String referencePolicy;
  late String activity;
  late String headlessWorker;
  late String manifest;

  setUpAll(() {
    bridge = File('$root/MediaStoreOcrInputBridge.kt').readAsStringSync();
    policy = File('$root/MediaStoreOcrInputPolicy.kt').readAsStringSync();
    referencePolicy = File(
      '$root/MediaStoreReferencePolicy.kt',
    ).readAsStringSync();
    activity = File('$root/MainActivity.kt').readAsStringSync();
    headlessWorker = File(
      '$root/MemoShotBackgroundProcessingWorker.kt',
    ).readAsStringSync();
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
  });

  test('bridge usa applicationContext nos engines visual e headless', () {
    expect(bridge, contains('context.applicationContext'));
    expect(bridge, isNot(contains('Activity')));
    expect(activity, contains('MediaStoreOcrInputBridge'));
    expect(headlessWorker, contains('MediaStoreOcrInputBridge'));
  });

  test('Dart fornece somente volume e ID e URI é reconstruída nativamente', () {
    expect(bridge, contains('argument<String>("volumeName")'));
    expect(bridge, contains('argument<Number>("mediaStoreId")'));
    expect(bridge, contains('MediaStoreReferencePolicy.canonicalUri'));
    expect(referencePolicy, contains('content://media/'));
    expect(bridge, isNot(contains('contentUri')));
    expect(bridge, isNot(contains('claimedUri')));
    expect(bridge, isNot(contains('file://')));
  });

  test('temporário fica no cache controlado e cópia é streaming', () {
    expect(policy, contains('DIRECTORY_NAME = "memoshot_ocr"'));
    expect(policy, contains('40L * 1024L * 1024L'));
    expect(policy, contains('ByteArray(BUFFER_SIZE)'));
    expect(bridge, contains('openInputStream(uri)'));
    expect(bridge, contains('copyToTemporary'));
    expect(bridge, isNot(contains('readBytes')));
    expect(bridge, isNot(contains('ByteArrayOutputStream')));
  });

  test('MIME é confirmado pelo ContentResolver e política é conservadora', () {
    expect(bridge, contains('resolver.getType(uri)'));
    expect(policy, contains('"image/png" -> "png"'));
    expect(policy, contains('"image/jpeg" -> "jpg"'));
    expect(policy, isNot(contains('image/webp')));
  });

  test('release aceita somente token e nunca caminho escolhido pelo Dart', () {
    expect(bridge, contains('argument<String>("token")'));
    expect(bridge, contains('registry.release(token)'));
    expect(bridge, isNot(contains('argument<String>("path")')));
    expect(bridge, isNot(contains('ContentResolver.delete')));
  });

  test('não consulta nomes e não expõe payload sensível', () {
    for (final forbidden in [
      'DISPLAY_NAME',
      'RELATIVE_PATH',
      'sourceKey',
      'originalName',
      'fullText',
      'ContentResolver.delete',
      'println',
      'Log.',
    ]) {
      expect(bridge, isNot(contains(forbidden)));
    }
  });

  test('limpeza é limitada ao diretório e preserva tokens ativos recentes', () {
    expect(policy, contains('ABANDONED_AFTER_MILLIS = 60L * 60L * 1000L'));
    expect(policy, contains('MAX_CLEANUP_FILES = 32'));
    expect(policy, contains('token in activeTokens'));
    expect(bridge, contains('cleanupIgnoringFailures'));
  });

  test('não adiciona permissão, Worker, engine ou componente exportado', () {
    expect(bridge, isNot(contains('WorkManager')));
    expect(bridge, isNot(contains('FlutterEngine')));
    expect(bridge, isNot(contains('startActivity')));
    expect(manifest, isNot(contains('MANAGE_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('WRITE_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('POST_NOTIFICATIONS')));
  });
}

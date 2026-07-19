import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = 'android/app/src/main/kotlin/br/com/jeffersont/memoshot';
  late String bridge;
  late String activity;
  late String worker;
  late String gradle;

  setUpAll(() {
    bridge = File('$root/LocalVisualAnalyzerBridge.kt').readAsStringSync();
    activity = File('$root/MainActivity.kt').readAsStringSync();
    worker = File(
      '$root/MemoShotBackgroundProcessingWorker.kt',
    ).readAsStringSync();
    gradle = File('android/app/build.gradle.kts').readAsStringSync();
  });

  test('usa modelo base local oficial sem Firebase ou modelo customizado', () {
    expect(gradle, contains('com.google.mlkit:image-labeling:17.0.9'));
    expect(gradle, isNot(contains('image-labeling-custom')));
    expect(gradle.toLowerCase(), isNot(contains('firebase')));
    expect(bridge, contains('ImageLabelerOptions.Builder()'));
    expect(bridge, isNot(contains('CustomLocalModel')));
  });

  test('funciona com applicationContext nos engines visual e headless', () {
    expect(bridge, contains('context.applicationContext'));
    expect(bridge, isNot(contains('Activity')));
    expect(activity, contains('LocalVisualAnalyzerBridge'));
    expect(worker, contains('LocalVisualAnalyzerBridge'));
  });

  test('aceita somente arquivo local controlado e não transporta imagem', () {
    expect(bridge, contains('isControlledLocalFile'));
    expect(bridge, contains('appContext.filesDir'));
    expect(bridge, contains('appContext.cacheDir'));
    expect(bridge, contains('InputImage.fromFilePath'));
    expect(bridge, isNot(contains('readBytes')));
    expect(bridge, isNot(contains('ByteArray')));
    expect(bridge, isNot(contains('http')));
  });

  test('fecha analisador e não registra conteúdo privado', () {
    expect(bridge, contains('labeler?.close()'));
    for (final forbidden in ['Log.', 'println', 'sourceKey', 'fullText']) {
      expect(bridge, isNot(contains(forbidden)));
    }
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File(
      'android/app/src/main/kotlin/br/com/jeffersont/contexto/'
      'ScreenshotMediaStoreBridge.kt',
    ).readAsStringSync();
  });

  test('bridge consulta somente imagens posteriores e finalizadas', () {
    expect(source, contains('MediaStore.Images.Media.EXTERNAL_CONTENT_URI'));
    expect(source, contains('MediaStore.Images.Media._ID} > ?'));
    expect(source, contains('MediaStore.Images.Media.IS_PENDING'));
    expect(source, contains('startsWith("image/")'));
    expect(source, contains('MediaStore.Images.Media._ID} ASC'));
    expect(source, contains('MediaStore.Images.Media.DATE_TAKEN'));
    expect(source, contains('MediaStore.Images.Media.DATE_ADDED'));
    expect(source, contains('MediaStoreCaptureTime.resolve'));
  });

  test('heurística contempla nomes em inglês e português', () {
    expect(source, contains('normalized.contains("screenshot")'));
    expect(source, contains('normalized.contains("capturadetela")'));
    expect(source, contains('normalized.contains("capturasdetela")'));
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

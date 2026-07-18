import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manifest recebe somente compartilhamentos de imagens', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.intent.action.SEND"'));
    expect(manifest, contains('android.intent.action.SEND_MULTIPLE"'));
    expect(manifest, contains('android:mimeType="image/*"'));
    expect(manifest, isNot(contains('android:mimeType="text/*"')));
    expect(manifest, isNot(contains('android:mimeType="video/*"')));
    expect(manifest, isNot(contains('android:mimeType="*/*"')));
    expect(manifest, isNot(contains('android.intent.action.VIEW')));
  });

  test('manifest não adiciona permissões amplas de armazenamento', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    for (final permission in [
      'READ_EXTERNAL_STORAGE',
      'READ_MEDIA_IMAGES',
      'WRITE_EXTERNAL_STORAGE',
      'MANAGE_EXTERNAL_STORAGE',
    ]) {
      expect(manifest, isNot(contains(permission)));
    }
    expect(manifest, contains('android:launchMode="singleTop"'));
  });
}

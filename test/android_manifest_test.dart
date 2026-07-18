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

  test('manifest adiciona somente permissões de imagens por versão', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.READ_MEDIA_IMAGES'));
    expect(
      manifest,
      contains('android.permission.READ_MEDIA_VISUAL_USER_SELECTED'),
    );
    expect(manifest, contains('android.permission.READ_EXTERNAL_STORAGE'));
    expect(manifest, contains('android:maxSdkVersion="32"'));
    for (final permission in [
      'WRITE_EXTERNAL_STORAGE',
      'MANAGE_EXTERNAL_STORAGE',
      'READ_MEDIA_VIDEO',
      'READ_MEDIA_AUDIO',
      'ACCESS_MEDIA_LOCATION',
      'POST_NOTIFICATIONS',
    ]) {
      expect(manifest, isNot(contains(permission)));
    }
    expect(manifest, contains('android:launchMode="singleTop"'));
    expect(manifest, isNot(contains('<service')));
  });
}

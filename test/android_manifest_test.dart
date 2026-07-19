import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identidade técnica e nome Android usam MemoShot', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/br/com/jeffersont/memoshot/MainActivity.kt',
    ).readAsStringSync();

    expect(pubspec, startsWith('name: memoshot\n'));
    expect(gradle, contains('namespace = "br.com.jeffersont.memoshot"'));
    expect(gradle, contains('applicationId = "br.com.jeffersont.memoshot"'));
    expect(gradle, isNot(contains('br.com.jeffersont.contexto')));
    expect(manifest, contains('android:label="@string/app_name"'));
    expect(strings, contains('<string name="app_name">MemoShot</string>'));
    expect(mainActivity, contains('package br.com.jeffersont.memoshot'));
    expect(
      Directory(
        'android/app/src/main/kotlin/br/com/jeffersont/contexto',
      ).existsSync(),
      isFalse,
    );
  });

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

  test('manifest adiciona imagens e notificação sem permissões proibidas', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.READ_MEDIA_IMAGES'));
    expect(
      manifest,
      contains('android.permission.READ_MEDIA_VISUAL_USER_SELECTED'),
    );
    expect(manifest, contains('android.permission.READ_EXTERNAL_STORAGE'));
    expect(manifest, isNot(contains('android.permission.POST_NOTIFICATIONS')));
    expect(manifest, contains('android:maxSdkVersion="32"'));
    for (final permission in [
      'WRITE_EXTERNAL_STORAGE',
      'MANAGE_EXTERNAL_STORAGE',
      'READ_MEDIA_VIDEO',
      'READ_MEDIA_AUDIO',
      'ACCESS_MEDIA_LOCATION',
      'INTERNET',
      'FOREGROUND_SERVICE',
      'RECEIVE_BOOT_COMPLETED',
    ]) {
      expect(manifest, isNot(contains(permission)));
    }
    expect(manifest, contains('android:launchMode="singleTop"'));
    expect(manifest, isNot(contains('<service')));
  });
}

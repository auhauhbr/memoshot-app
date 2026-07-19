import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = 'android/app/src/main/kotlin/br/com/jeffersont/memoshot';
  late String bridge;
  late String manifest;
  late String paths;

  setUpAll(() {
    bridge = File('$root/OriginalMediaViewerBridge.kt').readAsStringSync();
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    paths = File(
      'android/app/src/main/res/xml/original_media_paths.xml',
    ).readAsStringSync();
  });

  test('usa ACTION_VIEW com leitura, sem escrita, edição ou exclusão', () {
    expect(bridge, contains('Intent(Intent.ACTION_VIEW)'));
    expect(bridge, contains('Intent.FLAG_GRANT_READ_URI_PERMISSION'));
    expect(bridge, contains('Intent.FLAG_ACTIVITY_NEW_TASK'));
    expect(bridge, isNot(contains('FLAG_GRANT_WRITE_URI_PERMISSION')));
    expect(bridge, isNot(contains('ACTION_EDIT')));
    expect(bridge, isNot(contains('ACTION_DELETE')));
    expect(bridge, isNot(contains('ContentResolver.delete')));
  });

  test('MediaStore é reconstruído e não aceita URI fornecida pelo Dart', () {
    expect(bridge, contains('MediaStoreReferencePolicy.canonicalUri'));
    expect(bridge, contains('uri.authority != "media"'));
    expect(bridge, isNot(contains('argument<String>("contentUri")')));
    expect(bridge, isNot(contains('file://')));
  });

  test('arquivo privado usa FileProvider e raiz XML restrita', () {
    expect(bridge, contains('FileProvider.getUriForFile'));
    expect(bridge, contains('candidate.parentFile != canonicalRoot'));
    expect(bridge, contains("internalName.contains('/')"));
    expect(paths, contains('app_flutter/screenshots/'));
    expect(paths, isNot(contains('<root-path')));
    expect(paths, isNot(contains('path="."')));
    expect(manifest, contains('android:exported="false"'));
    expect(manifest, contains('android:grantUriPermissions="true"'));
  });

  test('não adiciona permissão nem devolve dados técnicos ao Dart', () {
    expect(manifest, isNot(contains('WRITE_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('POST_NOTIFICATIONS')));
    expect(bridge, contains('result.success(outcome.code)'));
    expect(bridge, isNot(contains('result.success(uri')));
    expect(bridge, isNot(contains('result.success(file')));
    expect(bridge, isNot(contains('println')));
    expect(bridge, isNot(contains('Log.')));
  });
}

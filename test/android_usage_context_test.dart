import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = 'android/app/src/main/kotlin/br/com/jeffersont/memoshot';
  late String bridge;
  late String worker;
  late String preferences;
  late String manifest;

  setUpAll(() {
    bridge = File('$root/ForegroundAppAtCaptureBridge.kt').readAsStringSync();
    worker = File('$root/ScreenshotMediaWorker.kt').readAsStringSync();
    preferences = File('$root/AppPreferencesBridge.kt').readAsStringSync();
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
  });

  test('declara acesso de uso e abre somente a tela manual do Android', () {
    expect(manifest, contains('android.permission.PACKAGE_USAGE_STATS'));
    expect(preferences, contains('Settings.ACTION_USAGE_ACCESS_SETTINGS'));
    expect(preferences, contains('currentActivity.startActivity'));
    expect(manifest, isNot(contains('AccessibilityService')));
  });

  test('consulta pontual usa eventos de foreground em janela curta', () {
    expect(bridge, contains('UsageStatsManager'));
    expect(bridge, contains('queryEvents'));
    expect(bridge, contains('ACTIVITY_RESUMED'));
    expect(bridge, contains('MOVE_TO_FOREGROUND'));
    expect(bridge, contains('BEFORE_WINDOW_MILLIS = 10_000L'));
    expect(bridge, contains('FUTURE_FALLBACK_MILLIS = 2_000L'));
    expect(worker, contains('findForegroundAppAt'));
    expect(worker, isNot(contains('openUsageAccessSettings')));
  });

  test('não registra pacote nem persiste lista de eventos', () {
    expect(bridge, isNot(contains('Log.')));
    expect(worker, isNot(contains('Log.')));
    expect(bridge, isNot(contains('SharedPreferences.Editor.putStringSet')));
  });
}

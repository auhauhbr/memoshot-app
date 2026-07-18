import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String bridge;
  late String activity;
  late String repository;

  setUpAll(() {
    const root = 'android/app/src/main/kotlin/br/com/jeffersont/memoshot';
    bridge = File('$root/AppPreferencesBridge.kt').readAsStringSync();
    activity = File('$root/MainActivity.kt').readAsStringSync();
    repository = File(
      'lib/features/onboarding/data/onboarding_repository.dart',
    ).readAsStringSync();
  });

  test('onboarding usa SharedPreferences local sem tabela ou dependência', () {
    expect(bridge, contains('getSharedPreferences'));
    expect(bridge, contains('onboarding_completed'));
    expect(bridge, contains('putBoolean'));
    expect(bridge, isNot(contains('MediaStore')));
    expect(bridge, isNot(contains('OCR')));
    expect(activity, contains('AppPreferencesBridge'));
  });

  test('canal de preferências coincide entre Dart e Android', () {
    const channel = 'br.com.jeffersont.memoshot/preferences';
    expect(bridge, contains(channel));
    expect(repository, contains(channel));
    expect(repository, contains('isOnboardingCompleted'));
    expect(repository, contains('completeOnboarding'));
  });
}

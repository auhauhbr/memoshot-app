import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String bridge;
  late String activity;
  late String repository;
  late String recentRepository;

  setUpAll(() {
    const root = 'android/app/src/main/kotlin/br/com/jeffersont/memoshot';
    bridge = File('$root/AppPreferencesBridge.kt').readAsStringSync();
    activity = File('$root/MainActivity.kt').readAsStringSync();
    repository = File(
      'lib/features/onboarding/data/onboarding_repository.dart',
    ).readAsStringSync();
    recentRepository = File(
      'lib/features/categories/data/recent_folder_repository.dart',
    ).readAsStringSync();
  });

  test('pastas recentes persistem somente IDs no mesmo SharedPreferences', () {
    expect(bridge, contains('recent_folder_ids'));
    expect(bridge, contains('MAXIMUM_RECENT_FOLDERS = 6'));
    expect(bridge, contains('putStringSet'));
    expect(recentRepository, contains('recentFolderIds'));
    expect(recentRepository, contains('setRecentFolderIds'));
    expect(recentRepository, isNot(contains('SharedPreferences')));
    expect(bridge, isNot(contains('categoryName')));
    expect(bridge, isNot(contains('privatePath')));
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

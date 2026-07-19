import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release ignora somente reconhecedores ML Kit opcionais ausentes', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final rules = File('android/app/proguard-rules.pro').readAsLinesSync();
    final activeRules = rules
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();

    expect(gradle, contains('"proguard-rules.pro"'));
    expect(gradle, isNot(contains('isMinifyEnabled = true')));
    expect(gradle, isNot(contains('isShrinkResources = true')));
    expect(activeRules, hasLength(8));
    expect(
      activeRules,
      everyElement(startsWith('-dontwarn com.google.mlkit.vision.text.')),
    );
    expect(activeRules, isNot(contains('-dontwarn **')));
    expect(activeRules, isNot(contains('-keep class **')));
  });

  test('asset Cupertino não utilizado não entra no pacote', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dartSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(dartSources, isNot(contains('CupertinoIcons')));
    expect(pubspec, isNot(contains('cupertino_icons:')));
  });
}

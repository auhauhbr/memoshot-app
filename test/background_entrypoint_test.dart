import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String mainSource;
  late String entrypoint;
  late String composition;
  late String classificationPolicy;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
    entrypoint = File(
      'lib/features/background_processing/background_entrypoint.dart',
    ).readAsStringSync();
    composition = File(
      'lib/features/background_processing/background_processing_composition.dart',
    ).readAsStringSync();
    classificationPolicy = File(
      'lib/features/classification/application/automatic_classification.dart',
    ).readAsStringSync();
  });

  test('entrypoint é preservado, inicializa plugins e não abre interface', () {
    expect(mainSource, contains("@pragma('vm:entry-point')"));
    expect(mainSource, contains('memoshotBackgroundEntrypoint'));
    expect(entrypoint, contains('WidgetsFlutterBinding.ensureInitialized()'));
    expect(entrypoint, contains('DartPluginRegistrant.ensureInitialized()'));
    expect(entrypoint, contains('BackgroundProcessingComposition.create()'));
    expect(entrypoint, contains("invokeMethod<void>('ready')"));
    expect(entrypoint, contains("terminalMethod = 'retryableFailure'"));
    expect(
      entrypoint,
      contains('composition.notificationCoordinator.synchronize()'),
    );
    expect(entrypoint, isNot(contains('runApp(')));
    expect(entrypoint, isNot(contains('MaterialApp')));
    expect(entrypoint, isNot(contains('HomePage')));
    expect(entrypoint, isNot(contains('BuildContext')));
  });

  test('composição usa pipeline atual e fecha filas e banco', () {
    expect(composition, contains('ContextoDatabase()'));
    expect(composition, contains('MlKitTextRecognitionService'));
    expect(composition, contains('createLocalClassificationQueue'));
    expect(composition, contains('createLocalClassificationJobScheduler'));
    expect(composition, contains('DriftAutomaticImportSettingsRepository'));
    expect(composition, contains('MethodChannelAutomaticScreenshotSource'));
    expect(composition, contains('MethodChannelReviewNotificationGateway'));
    expect(composition, contains('await _ocrQueue.close()'));
    expect(composition, contains('await _classificationQueue.close()'));
    expect(composition, contains('await _database.close()'));
    expect(composition, isNot(contains('HomePage')));
    expect(composition, isNot(contains('BuildContext')));
  });

  test('políticas conservadoras 0.85 e 0.90 permanecem centralizadas', () {
    expect(classificationPolicy, contains('0.85'));
    expect(classificationPolicy, contains('0.90'));
    expect(composition, isNot(contains('0.85')));
    expect(composition, isNot(contains('0.90')));
  });
}

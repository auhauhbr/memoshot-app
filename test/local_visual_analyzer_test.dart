import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/visual/local_visual_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(localVisualAnalyzerChannelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('normaliza, deduplica e ordena labels estruturados', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'analyze') {
            return <Object?>[
              {'key': 'Computer Keyboard', 'confidence': 0.80, 'index': 2},
              {'key': 'computer keyboard', 'confidence': 0.92, 'index': 2},
              {'key': 'Text', 'confidence': 0.60, 'index': 7},
            ];
          }
          return null;
        });
    final analyzer = MethodChannelLocalVisualAnalyzer(channel);

    final result = await analyzer.analyze('/private/cache/input.png');

    expect(result.labels.map((label) => label.key), [
      'computer keyboard',
      'text',
    ]);
    expect(result.labels.first.confidence, 0.92);
    expect(result.analyzerVersion, localVisualAnalyzerVersion);
    expect(calls.first.arguments, {'localPath': '/private/cache/input.png'});
    expect(calls.first.arguments.toString(), isNot(contains('bytes')));
    await analyzer.close();
    await analyzer.close();
    expect(calls.where((call) => call.method == 'close'), hasLength(1));
  });

  test('resultado posterior ao fechamento é ignorado', () async {
    final pending = Completer<List<Object?>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          if (call.method == 'analyze') return pending.future;
          return Future.value();
        });
    final analyzer = MethodChannelLocalVisualAnalyzer(channel);
    final analysis = analyzer.analyze('/private/cache/input.png');

    await analyzer.close();
    pending.complete([
      {'key': 'Book', 'confidence': 0.9},
    ]);

    await expectLater(analysis, throwsStateError);
  });

  test('falha nativa é propagada de forma controlada', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'visualTemporaryFailure');
        });
    final analyzer = MethodChannelLocalVisualAnalyzer(channel);

    await expectLater(
      analyzer.analyze('/private/cache/input.png'),
      throwsA(isA<PlatformException>()),
    );
  });
}

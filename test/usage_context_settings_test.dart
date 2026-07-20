import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/features/settings/presentation/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('br.com.jeffersont.memoshot/preferences');
  const settings = MethodChannelUsageContextSettings();

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('distingue acesso concedido e acesso necessário', () async {
    var response = 'enabled';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => response);

    expect(await settings.status(), UsageContextStatus.enabled);
    response = 'accessRequired';
    expect(await settings.status(), UsageContextStatus.accessRequired);
  });

  test(
    'ativação não presume acesso e abre configurações explicitamente',
    () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return call.method == 'setUsageContextEnabled'
                ? 'accessRequired'
                : null;
          });

      expect(
        await settings.setEnabled(true),
        UsageContextStatus.accessRequired,
      );
      await settings.openAccessSettings();
      expect(calls, ['setUsageContextEnabled', 'openUsageAccessSettings']);
    },
  );
}

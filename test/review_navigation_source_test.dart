import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/navigation/review_navigation_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(reviewNavigationChannelName);

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('destino frio antigo é consumido sem abrir revisão', () async {
    String? pending = 'reviewQueue';
    var opens = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'consumePendingDestination') return null;
          final value = pending;
          pending = null;
          return value;
        });
    final source = MethodChannelReviewNavigationSource();

    await source.start(() async => opens++);
    await source.start(() async => opens++);

    expect(opens, 0);
    await source.dispose();
  });

  test('destino antigo com app aberto é consumido sem abrir revisão', () async {
    String? pending;
    var opens = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'consumePendingDestination') {
            final value = pending;
            pending = null;
            return value;
          }
          return null;
        });
    final source = MethodChannelReviewNavigationSource();
    await source.start(() async => opens++);

    pending = 'reviewQueue';
    final data = const StandardMethodCodec().encodeMethodCall(
      const MethodCall('destinationAvailable'),
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(reviewNavigationChannelName, data, (_) {});
    await Future<void>.delayed(Duration.zero);

    expect(opens, 0);
    await source.dispose();
  });

  test('destino desconhecido é ignorado', () async {
    var opens = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 'arbitraryRoute');
    final source = MethodChannelReviewNavigationSource();

    await source.start(() async => opens++);

    expect(opens, 0);
    await source.dispose();
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/media/original_media_viewer.dart';
import 'package:memoshot/features/library/domain/media_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(originalMediaViewerChannelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('arquivo privado envia somente identificador interno e MIME', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return 'opened';
        });
    const viewer = MethodChannelOriginalMediaViewer(channel);

    final result = await viewer.open(_privateItem());

    expect(result, OriginalMediaOpenResult.opened);
    expect(received?.method, 'openOriginalMedia');
    expect(received?.arguments, {
      'storageKind': 'privateFile',
      'internalName': 'screenshot_1.png',
      'mimeType': 'image/png',
    });
    expect(received?.arguments.toString(), isNot(contains('/data/user')));
    expect(received?.arguments.toString(), isNot(contains('bytes')));
  });

  test('MediaStore envia volume, ID e MIME sem URI ou sourceKey', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return 'permissionDenied';
        });
    const viewer = MethodChannelOriginalMediaViewer(channel);

    final result = await viewer.open(_referencedItem());

    expect(result, OriginalMediaOpenResult.permissionDenied);
    expect(received?.arguments, {
      'storageKind': 'mediaStoreReference',
      'volumeName': 'external_primary',
      'mediaStoreId': 42,
      'mimeType': 'image/jpeg',
    });
    expect(received?.arguments.toString(), isNot(contains('content://')));
    expect(received?.arguments.toString(), isNot(contains('sourceKey')));
  });

  test(
    'resultado nativo desconhecido e PlatformException ficam controlados',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => 'unexpected');
      const viewer = MethodChannelOriginalMediaViewer(channel);
      expect(
        await viewer.open(_privateItem()),
        OriginalMediaOpenResult.temporaryFailure,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'noCompatibleApp');
          });
      expect(
        await viewer.open(_privateItem()),
        OriginalMediaOpenResult.noCompatibleApp,
      );
    },
  );
}

MediaItem _privateItem() => MediaItem(
  id: 1,
  location: PrivateFileLocation(
    privatePath: '/data/user/0/private/screenshot_1.png',
    internalName: 'screenshot_1.png',
  ),
  mimeType: 'image/png',
  importedAt: DateTime.utc(2026, 7, 19),
  sourceMode: 'copied',
  status: 'ready',
);

MediaItem _referencedItem() => MediaItem(
  id: 2,
  location: MediaStoreReferenceLocation(
    sourceKey: 'external_primary:42',
    mediaStoreId: 42,
    volumeName: 'external_primary',
    contentUri: MediaStoreReferenceLocation.canonicalContentUri(
      'external_primary',
      42,
    ),
  ),
  mimeType: 'image/jpeg',
  importedAt: DateTime.utc(2026, 7, 19),
  sourceMode: 'mediaStoreReference',
  status: 'ready',
);

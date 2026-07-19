import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/ocr/media_ocr_input.dart';
import 'package:memoshot/features/library/domain/media_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'memoshot_ocr_input_test_',
    );
  });

  tearDown(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('arquivo privado gera lease permanente e release é no-op', () async {
    final file = File('${temporaryDirectory.path}/private.png')
      ..writeAsBytesSync([1, 2, 3]);
    final bridge = _FakeBridge();
    final resolver = LocalMediaOcrInputResolver(bridge);

    final lease = await resolver.resolve(_privateItem(file.path));

    expect(lease.localPath, file.path);
    expect(lease.isTemporary, isFalse);
    await lease.release();
    await lease.release();
    expect(file.existsSync(), isTrue);
    expect(bridge.releasedTokens, isEmpty);
    expect(() => lease.localPath, throwsStateError);
    await resolver.close();
  });

  test('arquivo privado inexistente falha com código controlado', () async {
    final resolver = LocalMediaOcrInputResolver(_FakeBridge());

    await expectLater(
      resolver.resolve(_privateItem('${temporaryDirectory.path}/missing.png')),
      throwsA(
        isA<MediaOcrInputException>().having(
          (error) => error.code,
          'code',
          MediaOcrInputFailureCode.privateSourceUnavailable,
        ),
      ),
    );
    await resolver.close();
  });

  test(
    'referência gera lease temporário e libera somente pelo token',
    () async {
      final bridge = _FakeBridge(
        prepared: ReferencedOcrInput(
          localPath: '${temporaryDirectory.path}/temporary.png',
          token: 'opaque-token',
        ),
      );
      final resolver = LocalMediaOcrInputResolver(bridge);

      final lease = await resolver.resolve(_referencedItem());

      expect(lease.isTemporary, isTrue);
      expect(lease.localPath, endsWith('temporary.png'));
      await lease.close();
      await lease.close();
      expect(bridge.releasedTokens, ['opaque-token']);
      await resolver.close();
    },
  );

  test(
    'duas preparações da mesma referência possuem leases próprios',
    () async {
      final bridge = _FakeBridge();
      final resolver = LocalMediaOcrInputResolver(bridge);

      final first = await resolver.resolve(_referencedItem());
      final second = await resolver.resolve(_referencedItem());
      await first.release();
      await second.release();

      expect(bridge.preparedCount, 2);
      expect(bridge.releasedTokens, ['token-1', 'token-2']);
      await resolver.close();
    },
  );

  test('close libera leases ativos e impede novas resoluções', () async {
    final bridge = _FakeBridge();
    final resolver = LocalMediaOcrInputResolver(bridge);
    await resolver.resolve(_referencedItem());

    await resolver.close();

    expect(bridge.releasedTokens, ['token-1']);
    await expectLater(resolver.resolve(_referencedItem()), throwsStateError);
  });

  test('resultado tardio após close é liberado e ignorado', () async {
    final pending = Completer<ReferencedOcrInput>();
    final bridge = _FakeBridge(pending: pending);
    final resolver = LocalMediaOcrInputResolver(bridge);
    final resolution = resolver.resolve(_referencedItem());

    await resolver.close();
    pending.complete(
      ReferencedOcrInput(
        localPath: '${temporaryDirectory.path}/late.png',
        token: 'late-token',
      ),
    );

    await expectLater(resolution, throwsStateError);
    expect(bridge.releasedTokens, ['late-token']);
  });

  test('falha da bridge é preservada sem criar lease', () async {
    final resolver = LocalMediaOcrInputResolver(
      _FakeBridge(
        error: const MediaOcrInputException(
          MediaOcrInputFailureCode.referencedSourceTooLarge,
        ),
      ),
    );

    await expectLater(
      resolver.resolve(_referencedItem()),
      throwsA(
        isA<MediaOcrInputException>().having(
          (error) => error.code,
          'code',
          MediaOcrInputFailureCode.referencedSourceTooLarge,
        ),
      ),
    );
    await resolver.close();
  });

  test(
    'MethodChannel envia somente volume e ID e libera somente token',
    () async {
      const channel = MethodChannel(mediaStoreOcrInputChannelName);
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'prepare') {
              return <String, Object>{
                'localPath': '${temporaryDirectory.path}/channel.png',
                'token': 'channel-token',
              };
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      const bridge = MethodChannelMediaStoreOcrInputBridge(channel);

      final prepared = await bridge.prepare(
        _referencedItem().location as MediaStoreReferenceLocation,
      );
      await bridge.release(prepared.token);

      expect(calls.singleWhere((call) => call.method == 'prepare').arguments, {
        'volumeName': 'external_primary',
        'mediaStoreId': 42,
      });
      expect(calls.singleWhere((call) => call.method == 'release').arguments, {
        'token': 'channel-token',
      });
    },
  );
}

MediaItem _privateItem(String path) => MediaItem(
  id: 1,
  location: PrivateFileLocation(privatePath: path, internalName: 'private.png'),
  importedAt: DateTime(2026),
  sourceMode: 'photoPicker',
  status: 'ready',
);

MediaItem _referencedItem() => MediaItem(
  id: 2,
  location: MediaStoreReferenceLocation(
    sourceKey: 'external_primary:42',
    mediaStoreId: 42,
    volumeName: 'external_primary',
    contentUri: 'content://media/external_primary/images/media/42',
  ),
  mimeType: 'image/png',
  mediaHash: null,
  importedAt: DateTime(2026),
  sourceMode: 'mediaStoreReference',
  status: 'ready',
);

class _FakeBridge implements MediaStoreOcrInputBridge {
  _FakeBridge({this.prepared, this.pending, this.error});

  final ReferencedOcrInput? prepared;
  final Completer<ReferencedOcrInput>? pending;
  final Object? error;
  int preparedCount = 0;
  final List<String> releasedTokens = [];

  @override
  Future<ReferencedOcrInput> prepare(
    MediaStoreReferenceLocation location,
  ) async {
    preparedCount++;
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return prepared ??
        ReferencedOcrInput(
          localPath: '/cache/memoshot_ocr/token-$preparedCount.png',
          token: 'token-$preparedCount',
        );
  }

  @override
  Future<void> release(String token) async => releasedTokens.add(token);
}

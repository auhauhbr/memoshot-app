import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/media_store/media_store_content.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/library/presentation/media_item_thumbnail.dart';

void main() {
  testWidgets('arquivo privado reserva placeholder e limita decodificação', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('private_thumb_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/item.png')
      ..writeAsBytesSync(base64Decode(_minimalPng));

    await tester.pumpWidget(
      _app(
        mediaItem: _privateMedia(1, file.path),
        cacheWidth: compactThumbnailDecodeSize,
        cacheHeight: compactThumbnailDecodeSize,
      ),
    );

    expect(find.byKey(const Key('media-thumbnail-loading')), findsOneWidget);
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('private-thumbnail-1')),
    );
    expect(image.image, isA<ResizeImage>());
    final provider = image.image as ResizeImage;
    expect(provider.width, compactThumbnailDecodeSize);
    expect(provider.height, compactThumbnailDecodeSize);

    expect(find.byKey(const ValueKey('private-thumbnail-1')), findsOneWidget);
  });

  testWidgets('referência mostra placeholder e depois miniatura limitada', (
    tester,
  ) async {
    final completer = Completer<ReferencedMediaThumbnail>();
    final gateway = _Gateway(
      futures: {
        42: [completer.future],
      },
    );
    await tester.pumpWidget(_app(gateway: gateway));
    expect(find.byKey(const Key('media-thumbnail-loading')), findsOneWidget);

    completer.complete(_availableThumbnail());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('referenced-thumbnail-image-2')),
      findsOneWidget,
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    expect(gateway.loadCount, 1);
  });

  testWidgets('rebuild do mesmo item não inicia outra solicitação', (
    tester,
  ) async {
    final completer = Completer<ReferencedMediaThumbnail>();
    final gateway = _Gateway(
      futures: {
        42: [completer.future],
      },
    );
    await tester.pumpWidget(_app(gateway: gateway));
    await tester.pumpWidget(_app(gateway: gateway));

    expect(gateway.loadCount, 1);
    completer.complete(_availableThumbnail());
    await tester.pumpAndSettle();
  });

  testWidgets('mudança de item ignora resultado antigo e não mantém bytes', (
    tester,
  ) async {
    final oldResult = Completer<ReferencedMediaThumbnail>();
    final currentResult = Completer<ReferencedMediaThumbnail>();
    final gateway = _Gateway(
      futures: {
        42: [oldResult.future],
        43: [currentResult.future],
      },
    );
    await tester.pumpWidget(
      _app(gateway: gateway, mediaItem: _referencedMedia(1, 42)),
    );
    await tester.pumpWidget(
      _app(gateway: gateway, mediaItem: _referencedMedia(2, 43)),
    );

    oldResult.complete(_availableThumbnail());
    await tester.pump();
    expect(
      find.byKey(const ValueKey('referenced-thumbnail-image-1')),
      findsNothing,
    );
    expect(find.byKey(const Key('media-thumbnail-loading')), findsOneWidget);

    currentResult.complete(_availableThumbnail());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('referenced-thumbnail-image-2')),
      findsOneWidget,
    );
  });

  testWidgets('dispose durante carregamento ignora conclusão tardia', (
    tester,
  ) async {
    final completer = Completer<ReferencedMediaThumbnail>();
    final gateway = _Gateway(
      futures: {
        42: [completer.future],
      },
    );
    await tester.pumpWidget(_app(gateway: gateway));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    completer.complete(_availableThumbnail());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('falha temporária oferece retry sem loop automático', (
    tester,
  ) async {
    final retry = Completer<ReferencedMediaThumbnail>();
    final gateway = _Gateway(
      futures: {
        42: [
          Future.value(
            const ReferencedMediaThumbnail(
              availability: ReferencedMediaAvailability.temporaryFailure,
            ),
          ),
          retry.future,
        ],
      },
    );
    await tester.pumpWidget(_app(gateway: gateway, showMessage: true));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(gateway.loadCount, 1);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(find.byKey(const Key('media-thumbnail-loading')), findsOneWidget);
    expect(gateway.loadCount, 2);

    retry.complete(_availableThumbnail());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('referenced-thumbnail-image-2')),
      findsOneWidget,
    );
  });

  for (final value in [
    (ReferencedMediaAvailability.unavailable, 'Imagem indisponível.'),
    (
      ReferencedMediaAvailability.permissionDenied,
      'Revise o acesso às imagens.',
    ),
  ]) {
    testWidgets('referência ${value.$1.name} mostra estado específico', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          gateway: _Gateway(
            futures: {
              42: [
                Future.value(ReferencedMediaThumbnail(availability: value.$1)),
              ],
            },
          ),
          showMessage: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(value.$2), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
      expect(find.textContaining('content://'), findsNothing);
      expect(find.textContaining('external_primary:42'), findsNothing);
    });
  }
}

Widget _app({
  MediaStoreContentGateway? gateway,
  MediaItem? mediaItem,
  bool showMessage = false,
  int cacheWidth = regularThumbnailDecodeSize,
  int cacheHeight = regularThumbnailDecodeSize,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox.square(
      dimension: 300,
      child: MediaItemThumbnail(
        mediaItem: mediaItem ?? _referencedMedia(2, 42),
        gateway: gateway ?? _Gateway(futures: const {}),
        showMessage: showMessage,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
      ),
    ),
  ),
);

MediaItem _privateMedia(int id, String path) => MediaItem(
  id: id,
  location: PrivateFileLocation(
    privatePath: path,
    internalName: 'item-$id.png',
  ),
  importedAt: DateTime.utc(2026),
  sourceMode: 'test',
  status: 'ready',
);

MediaItem _referencedMedia(int id, int mediaStoreId) => MediaItem(
  id: id,
  location: MediaStoreReferenceLocation(
    sourceKey: 'external_primary:$mediaStoreId',
    mediaStoreId: mediaStoreId,
    volumeName: 'external_primary',
    contentUri: 'content://media/external_primary/images/media/$mediaStoreId',
  ),
  importedAt: DateTime.utc(2026),
  sourceMode: 'mediaStoreReference',
  status: 'ready',
);

ReferencedMediaThumbnail _availableThumbnail() => ReferencedMediaThumbnail(
  availability: ReferencedMediaAvailability.available,
  bytes: base64Decode(_minimalPng),
);

class _Gateway implements MediaStoreContentGateway {
  _Gateway({required Map<int, List<Future<ReferencedMediaThumbnail>>> futures})
    : _futures = {
        for (final entry in futures.entries) entry.key: [...entry.value],
      };

  final Map<int, List<Future<ReferencedMediaThumbnail>>> _futures;
  int loadCount = 0;

  @override
  Future<ReferencedMediaAvailability> checkAvailability(
    MediaStoreReferenceLocation location,
  ) async => (await loadThumbnail(location)).availability;

  @override
  Future<ReferencedMediaThumbnail> loadThumbnail(
    MediaStoreReferenceLocation location,
  ) {
    loadCount++;
    final queue = _futures[location.mediaStoreId];
    if (queue == null || queue.isEmpty) {
      return Completer<ReferencedMediaThumbnail>().future;
    }
    return queue.removeAt(0);
  }
}

const _minimalPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

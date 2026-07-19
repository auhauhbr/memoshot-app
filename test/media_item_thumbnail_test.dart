import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/media_store/media_store_content.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/library/presentation/media_item_thumbnail.dart';

void main() {
  testWidgets('miniatura privada continua usando arquivo local', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaItemThumbnail(
          mediaItem: MediaItem(
            id: 1,
            location: PrivateFileLocation(
              privatePath: '/arquivo/inexistente.png',
              internalName: 'inexistente.png',
            ),
            importedAt: DateTime.utc(2026),
            sourceMode: 'test',
            status: 'ready',
          ),
          showMessage: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('private-thumbnail-1')), findsOneWidget);
  });

  testWidgets('referência mostra carregamento e miniatura limitada', (
    tester,
  ) async {
    final completer = Completer<ReferencedMediaThumbnail>();
    final gateway = FakeMediaStoreContentGateway(future: completer.future);
    await tester.pumpWidget(_app(gateway));
    expect(
      find.byKey(const Key('referenced-thumbnail-loading')),
      findsOneWidget,
    );

    completer.complete(
      ReferencedMediaThumbnail(
        availability: ReferencedMediaAvailability.available,
        bytes: base64Decode(_minimalPng),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('referenced-thumbnail-image')), findsOneWidget);
    expect(gateway.loadCount, 1);
  });

  for (final value in [
    (
      ReferencedMediaAvailability.unavailable,
      'Esta imagem não está mais disponível no dispositivo.',
    ),
    (
      ReferencedMediaAvailability.permissionDenied,
      'O MemoShot não tem acesso a esta imagem.',
    ),
    (
      ReferencedMediaAvailability.temporaryFailure,
      'Não foi possível carregar esta imagem agora.',
    ),
  ]) {
    testWidgets('referência ${value.$1.name} mostra estado seguro', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          FakeMediaStoreContentGateway(
            future: Future.value(
              ReferencedMediaThumbnail(availability: value.$1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(value.$2), findsOneWidget);
      expect(find.textContaining('content://'), findsNothing);
      expect(find.textContaining('external_primary:42'), findsNothing);
    });
  }
}

Widget _app(MediaStoreContentGateway gateway) => MaterialApp(
  home: Scaffold(
    body: MediaItemThumbnail(
      mediaItem: MediaItem(
        id: 2,
        location: MediaStoreReferenceLocation(
          sourceKey: 'external_primary:42',
          mediaStoreId: 42,
          volumeName: 'external_primary',
          contentUri: 'content://media/external_primary/images/media/42',
        ),
        importedAt: DateTime.utc(2026),
        sourceMode: 'mediaStoreReference',
        status: 'ready',
      ),
      gateway: gateway,
      showMessage: true,
    ),
  ),
);

class FakeMediaStoreContentGateway implements MediaStoreContentGateway {
  FakeMediaStoreContentGateway({required this.future});

  final Future<ReferencedMediaThumbnail> future;
  int loadCount = 0;

  @override
  Future<ReferencedMediaAvailability> checkAvailability(
    MediaStoreReferenceLocation location,
  ) async => (await future).availability;

  @override
  Future<ReferencedMediaThumbnail> loadThumbnail(
    MediaStoreReferenceLocation location,
  ) {
    loadCount++;
    return future;
  }
}

const _minimalPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

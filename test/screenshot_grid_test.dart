import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/media_store/media_store_content.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/library/presentation/media_item_thumbnail.dart';
import 'package:memoshot/features/library/presentation/screenshot_grid.dart';

void main() {
  test('decisão responsiva usa duas, três e quatro colunas', () {
    expect(
      ScreenshotGridLayout.columnCount(availableWidth: 339, textScaleFactor: 1),
      2,
    );
    expect(
      ScreenshotGridLayout.columnCount(availableWidth: 400, textScaleFactor: 1),
      3,
    );
    expect(
      ScreenshotGridLayout.columnCount(availableWidth: 500, textScaleFactor: 1),
      4,
    );
    expect(
      ScreenshotGridLayout.columnCount(
        availableWidth: 500,
        textScaleFactor: 1.3,
      ),
      2,
    );
  });

  testWidgets('card é quadrado, contém imagem e usa decodificação compacta', (
    tester,
  ) async {
    final gateway = _PendingGateway();
    await tester.pumpWidget(
      _gridApp(width: 400, gateway: gateway, item: _referencedItem(7)),
    );

    final delegate =
        tester
                .widget<GridView>(
                  find.byKey(const Key('persisted-screenshot-grid')),
                )
                .gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(delegate.childAspectRatio, 1);
    expect(find.byKey(const Key('media-thumbnail-loading')), findsOneWidget);

    gateway.completer.complete(
      ReferencedMediaThumbnail(
        availability: ReferencedMediaAvailability.available,
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      ),
    );
    await tester.pump();
    final thumbnail = tester.widget<MediaItemThumbnail>(
      find.byType(MediaItemThumbnail),
    );
    expect(thumbnail.fit, BoxFit.contain);
    expect(thumbnail.cacheWidth, compactThumbnailDecodeSize);
    expect(thumbnail.cacheHeight, compactThumbnailDecodeSize);
    expect(thumbnail.key, const ValueKey<int>(7));
  });
}

Widget _gridApp({
  required double width,
  required MediaStoreContentGateway gateway,
  required MediaItem item,
}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: ScreenshotGrid(
          mediaItems: [item],
          ocrStates: const {},
          onItemTap: (_) {},
          showStorageNote: false,
          thumbnailGateway: gateway,
        ),
      ),
    ),
  ),
);

MediaItem _referencedItem(int id) => MediaItem(
  id: id,
  location: MediaStoreReferenceLocation(
    sourceKey: 'external_primary:$id',
    mediaStoreId: id,
    volumeName: 'external_primary',
    contentUri: 'content://media/external_primary/images/media/$id',
  ),
  importedAt: DateTime.utc(2026),
  sourceMode: 'mediaStoreReference',
  status: 'ready',
);

class _PendingGateway implements MediaStoreContentGateway {
  final completer = Completer<ReferencedMediaThumbnail>();

  @override
  Future<ReferencedMediaAvailability> checkAvailability(
    MediaStoreReferenceLocation location,
  ) async => ReferencedMediaAvailability.available;

  @override
  Future<ReferencedMediaThumbnail> loadThumbnail(
    MediaStoreReferenceLocation location,
  ) => completer.future;
}

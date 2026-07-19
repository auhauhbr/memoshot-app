import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/features/library/domain/media_item.dart';

void main() {
  test('arquivo privado possui localização válida e igualdade previsível', () {
    final first = PrivateFileLocation(
      privatePath: '/privado/item.png',
      internalName: 'item.png',
    );
    final second = PrivateFileLocation(
      privatePath: '/privado/item.png',
      internalName: 'item.png',
    );
    final item = _item(first);

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(item.isPrivateFile, isTrue);
    expect(item.isMediaStoreReference, isFalse);
    expect(item.privatePath, '/privado/item.png');
    expect(item.sourceKey, isNull);
  });

  test('referência MediaStore é imutável, válida e não finge ser caminho', () {
    final modified = DateTime.utc(2026, 7, 19);
    final first = MediaStoreReferenceLocation(
      sourceKey: 'external_primary:42',
      mediaStoreId: 42,
      volumeName: 'external_primary',
      contentUri: 'content://media/external_primary/images/media/42',
      dateModified: modified,
    );
    final second = MediaStoreReferenceLocation(
      sourceKey: 'external_primary:42',
      mediaStoreId: 42,
      volumeName: 'external_primary',
      contentUri: 'content://media/external_primary/images/media/42',
      dateModified: modified,
    );
    final item = _item(first);

    expect(first, second);
    expect(item.isPrivateFile, isFalse);
    expect(item.isMediaStoreReference, isTrue);
    expect(item.privatePath, isNull);
    expect(item.internalName, isNull);
    expect(item.sourceKey, 'external_primary:42');
  });

  test('rejeita campos vazios, IDs, volumes, chaves e URIs incompatíveis', () {
    expect(
      () => PrivateFileLocation(privatePath: '', internalName: 'item.png'),
      throwsArgumentError,
    );
    for (final values in [
      ('external:1', 0, 'external', 'content://media/external/images/media/0'),
      (
        'external:1',
        1,
        '../external',
        'content://media/external/images/media/1',
      ),
      ('external:2', 1, 'external', 'content://media/external/images/media/1'),
      ('external:1', 1, 'external', 'file:///tmp/item.png'),
      (
        'external:1',
        1,
        'external',
        'content://example/external/images/media/1',
      ),
    ]) {
      expect(
        () => MediaStoreReferenceLocation(
          sourceKey: values.$1,
          mediaStoreId: values.$2,
          volumeName: values.$3,
          contentUri: values.$4,
        ),
        throwsArgumentError,
      );
    }
  });
}

MediaItem _item(MediaItemLocation location) => MediaItem(
  id: 1,
  location: location,
  importedAt: DateTime.utc(2026),
  sourceMode: 'test',
  status: 'ready',
);

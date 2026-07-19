import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/database/contexto_database.dart';
import 'package:memoshot/features/categories/data/category_repository.dart';
import 'package:memoshot/features/categories/data/category_store.dart';
import 'package:memoshot/features/library/data/media_item_store.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/library/domain/media_page.dart';

void main() {
  group('paginação por cursor', () {
    late ContextoDatabase database;
    late DriftMediaItemStore store;

    setUp(() {
      database = ContextoDatabase.forTesting(NativeDatabase.memory());
      store = DriftMediaItemStore(database);
    });

    tearDown(() => database.close());

    for (final total in [5700, 10000]) {
      test('$total itens são percorridos em páginas sem omissão', () async {
        await _insertReferencedItems(database, total, sameCapturedAt: true);

        final first = await store.readMediaPage(const MediaPageRequest());
        expect(first.items, hasLength(defaultMediaPageSize));
        expect(first.items.first.id, total);
        expect(first.items.last.id, total - defaultMediaPageSize + 1);
        expect(first.nextCursor, isNotNull);

        final ids = <int>[];
        MediaPageCursor? cursor;
        do {
          final page = await store.readMediaPage(
            MediaPageRequest(cursor: cursor),
          );
          ids.addAll(page.items.map((item) => item.id));
          cursor = page.nextCursor;
        } while (cursor != null);

        expect(ids, hasLength(total));
        expect(ids.toSet(), hasLength(total));
        expect(ids, List<int>.generate(total, (index) => total - index));
      });
    }

    test('limita página, usa ID no empate e chega à página final', () async {
      await _insertReferencedItems(database, 125, sameCapturedAt: true);
      final first = await store.readMediaPage(
        const MediaPageRequest(pageSize: 1000),
      );
      final second = await store.readMediaPage(
        MediaPageRequest(cursor: first.nextCursor),
      );
      final third = await store.readMediaPage(
        MediaPageRequest(cursor: second.nextCursor),
      );

      expect(first.items, hasLength(maximumMediaPageSize));
      expect(second.items, hasLength(maximumMediaPageSize));
      expect(third.items, hasLength(5));
      expect(third.nextCursor, isNull);
      expect(
        [
          ...first.items,
          ...second.items,
          ...third.items,
        ].map((item) => item.id).toSet(),
        hasLength(125),
      );
    });

    test('página preserva arquivo privado e referência MediaStore', () async {
      final temporary = File(
        '${Directory.systemTemp.path}/memoshot-pagination-private.png',
      )..writeAsBytesSync(const [1]);
      addTearDown(() {
        if (temporary.existsSync()) temporary.deleteSync();
      });
      await store.insertItem(
        privatePath: temporary.path,
        internalName: 'private.png',
        mimeType: 'image/png',
        mediaHash: 'private-hash',
        importedAt: DateTime.utc(2026, 1, 1),
        capturedAt: DateTime.utc(2026, 1, 1),
        sourceMode: 'test',
        status: 'ready',
      );
      await store.insertMediaStoreReference(
        location: MediaStoreReferenceLocation(
          sourceKey: 'external_primary:7',
          mediaStoreId: 7,
          volumeName: 'external_primary',
          contentUri: 'content://media/external_primary/images/media/7',
        ),
        mimeType: 'image/png',
        importedAt: DateTime.utc(2026, 1, 2),
        capturedAt: DateTime.utc(2026, 1, 2),
        sourceMode: 'mediaStoreReference',
        status: 'ready',
      );

      final page = await store.readMediaPage(const MediaPageRequest());
      expect(page.items, hasLength(2));
      expect(page.items.first.isMediaStoreReference, isTrue);
      expect(page.items.last.isPrivateFile, isTrue);
    });

    test('pesquisa e etiquetas AND continuam paginadas', () async {
      await _insertReferencedItems(database, 130, sameCapturedAt: false);
      final tagOne = await database
          .into(database.tags)
          .insert(
            TagsCompanion.insert(
              name: 'Um',
              normalizedName: 'um',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          );
      final tagTwo = await database
          .into(database.tags)
          .insert(
            TagsCompanion.insert(
              name: 'Dois',
              normalizedName: 'dois',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          );
      await database.batch((batch) {
        for (var id = 1; id <= 130; id++) {
          batch.insert(
            database.ocrResults,
            OcrResultsCompanion.insert(
              mediaItemId: Value(id),
              fullText: 'Projeto número $id',
              normalizedText: const Value('projeto'),
              engine: 'test',
              engineVersion: '1',
              processedAt: DateTime.utc(2026),
            ),
          );
          if (id <= 115) {
            batch.insert(
              database.mediaTags,
              MediaTagsCompanion.insert(
                mediaItemId: id,
                tagId: tagOne,
                createdAt: DateTime.utc(2026),
              ),
            );
          }
          if (id <= 100) {
            batch.insert(
              database.mediaTags,
              MediaTagsCompanion.insert(
                mediaItemId: id,
                tagId: tagTwo,
                createdAt: DateTime.utc(2026),
              ),
            );
          }
        }
      });

      final request = MediaPageRequest(tagIds: {tagOne, tagTwo});
      final first = await store.searchMediaPage('projeto', request);
      final second = await store.searchMediaPage(
        'projeto',
        MediaPageRequest(cursor: first.nextCursor, tagIds: request.tagIds),
      );

      expect(first.items, hasLength(60));
      expect(second.items, hasLength(40));
      expect(second.nextCursor, isNull);
      expect(
        [
          ...first.items,
          ...second.items,
        ].map((match) => match.mediaItem.id).toSet(),
        hasLength(100),
      );
      expect(await store.countMediaItems(tagIds: request.tagIds), 100);
    });

    test('consulta principal não usa OFFSET crescente', () {
      final source = File(
        'lib/features/library/data/media_item_store.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'\bOFFSET\b', caseSensitive: false).hasMatch(source),
        isFalse,
      );
    });
  });

  test('pasta pagina somente associações diretas e conta via SQL', () async {
    final database = ContextoDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertReferencedItems(database, 150, sameCapturedAt: true);
    final repository = LocalCategoryRepository(
      store: DriftCategoryStore(database),
    );
    final root = await repository.createRootCategory('Raiz');
    final child = await repository.createSubcategory(
      parentId: root.id,
      name: 'Filha',
    );
    await database.batch((batch) {
      for (var id = 1; id <= 130; id++) {
        batch.insert(
          database.mediaCategories,
          MediaCategoriesCompanion.insert(
            mediaItemId: id,
            categoryId: root.id,
            createdAt: DateTime.utc(2026),
          ),
        );
      }
      for (var id = 131; id <= 150; id++) {
        batch.insert(
          database.mediaCategories,
          MediaCategoriesCompanion.insert(
            mediaItemId: id,
            categoryId: child.id,
            createdAt: DateTime.utc(2026),
          ),
        );
      }
    });

    final first = await repository.loadMediaPageByCategory(root.id);
    final second = await repository.loadMediaPageByCategory(
      root.id,
      MediaPageRequest(cursor: first.nextCursor),
    );
    final third = await repository.loadMediaPageByCategory(
      root.id,
      MediaPageRequest(cursor: second.nextCursor),
    );

    expect(first.items, hasLength(60));
    expect(second.items, hasLength(60));
    expect(third.items, hasLength(10));
    expect(
      [...first.items, ...second.items, ...third.items].map((item) => item.id),
      everyElement(lessThanOrEqualTo(130)),
    );
    expect(await repository.countMediaItemsByCategory(root.id), 130);
    await expectLater(
      repository.loadMediaPageByCategory(9999),
      throwsA(isA<CategoryHierarchyException>()),
    );
  });

  test('cursor mantém ordenação após reabrir o banco', () async {
    final directory = Directory.systemTemp.createTempSync(
      'memoshot-pagination-persistence-',
    );
    final file = File('${directory.path}/library.sqlite');
    var database = ContextoDatabase.forTesting(NativeDatabase(file));
    await _insertReferencedItems(database, 75, sameCapturedAt: true);
    var store = DriftMediaItemStore(database);
    final first = await store.readMediaPage(const MediaPageRequest());
    await database.close();

    database = ContextoDatabase.forTesting(NativeDatabase(file));
    store = DriftMediaItemStore(database);
    final second = await store.readMediaPage(
      MediaPageRequest(cursor: first.nextCursor),
    );

    expect(second.items, hasLength(15));
    expect(
      second.items.map((item) => item.id),
      List.generate(15, (i) => 15 - i),
    );
    await database.close();
    directory.deleteSync(recursive: true);
  });
}

Future<void> _insertReferencedItems(
  ContextoDatabase database,
  int total, {
  required bool sameCapturedAt,
}) async {
  await database.customSelect('SELECT 1').get();
  final base = DateTime.utc(2026, 1, 1);
  await database.batch((batch) {
    for (var id = 1; id <= total; id++) {
      final capturedAt = sameCapturedAt
          ? base
          : base.add(Duration(seconds: id));
      batch.insert(
        database.mediaItems,
        MediaItemsCompanion.insert(
          storageKind: const Value('mediaStoreReference'),
          privatePath: const Value(null),
          internalName: const Value(null),
          sourceKey: Value('external_primary:$id'),
          mediaStoreId: Value(id),
          volumeName: const Value('external_primary'),
          contentUri: Value(
            'content://media/external_primary/images/media/$id',
          ),
          importedAt: capturedAt,
          capturedAt: Value(capturedAt),
          sourceMode: 'mediaStoreReference',
          status: 'ready',
        ),
      );
    }
  });
}

import 'dart:io';

import 'package:memoshot/core/database/contexto_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migra schema 8 para 12 preservando dados e hierarquia', () async {
    final directory = Directory.systemTemp.createTempSync(
      'memoshot_migration_test_',
    );
    final databaseFile = File('${directory.path}/contexto.sqlite');

    final legacy = _LegacyDatabase(NativeDatabase(databaseFile));
    await legacy.customStatement(
      '''
      INSERT INTO media_items (
        private_path, internal_name, mime_type, imported_at, source_mode, status
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''',
      [
        '${directory.path}/copia.png',
        'copia.png',
        'image/png',
        DateTime(2025).millisecondsSinceEpoch ~/ 1000,
        'photoPicker',
        'ready',
      ],
    );
    await legacy.customStatement(
      '''
      INSERT INTO automatic_import_settings (
        id, enabled, last_media_id, enabled_at, last_scan_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''',
      [
        1,
        1,
        42,
        DateTime(2025).millisecondsSinceEpoch ~/ 1000,
        DateTime(2025).millisecondsSinceEpoch ~/ 1000,
        DateTime(2025).millisecondsSinceEpoch ~/ 1000,
      ],
    );
    await legacy.customStatement(
      '''
      INSERT INTO media_items (
        private_path, internal_name, mime_type, imported_at, source_mode,
        import_origin, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        '${directory.path}/compartilhada-antiga.png',
        'compartilhada-antiga.png',
        'image/png',
        DateTime(2025).millisecondsSinceEpoch ~/ 1000,
        'photoPicker',
        'shared',
        'ready',
      ],
    );
    await legacy.customStatement(
      "INSERT INTO categories (name, normalized_name, created_at) VALUES ('Teste', 'teste', ?)",
      [DateTime(2025).millisecondsSinceEpoch ~/ 1000],
    );
    await legacy.customStatement(
      'INSERT INTO media_categories (media_item_id, category_id, created_at) VALUES (1, 1, ?)',
      [DateTime(2025).millisecondsSinceEpoch ~/ 1000],
    );
    await legacy.customStatement(
      '''
      INSERT INTO processing_jobs (
        media_item_id, job_type, status, attempts, created_at
      ) VALUES (?, ?, ?, ?, ?)
    ''',
      [1, 'ocr', 'completed', 1, DateTime(2025).millisecondsSinceEpoch ~/ 1000],
    );
    await legacy.customStatement(
      '''
      INSERT INTO ocr_results (
        media_item_id, full_text, normalized_text, engine, engine_version,
        processed_at
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''',
      [
        1,
        'Texto fictício preservado',
        'texto ficticio preservado',
        'Teste',
        '1',
        DateTime(2025).millisecondsSinceEpoch ~/ 1000,
      ],
    );
    await legacy.close();

    final migrated = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    final rows = await migrated.select(migrated.mediaItems).get();
    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();

    expect(version.read<int>('user_version'), 12);
    expect(rows, hasLength(2));
    expect(rows.first.internalName, 'copia.png');
    expect(rows.first.mediaHash, isNull);
    expect(rows.first.importOrigin, 'picker');
    expect(rows.first.capturedAt, rows.first.importedAt);
    expect(rows.last.importOrigin, 'shared');
    expect(rows.last.capturedAt, rows.last.importedAt);
    final ocrRows = await migrated.select(migrated.ocrResults).get();
    expect(ocrRows.single.fullText, 'Texto fictício preservado');
    expect(ocrRows.single.normalizedText, 'texto ficticio preservado');
    expect(await migrated.select(migrated.processingJobs).get(), hasLength(1));
    final categories = await migrated.select(migrated.categories).get();
    expect(categories, hasLength(1));
    expect(categories.single.id, 1);
    expect(categories.single.name, 'Teste');
    expect(categories.single.normalizedName, 'teste');
    expect(categories.single.parentId, isNull);
    final mediaCategories = await migrated
        .select(migrated.mediaCategories)
        .get();
    expect(mediaCategories, hasLength(1));
    expect(mediaCategories.single.mediaItemId, 1);
    expect(mediaCategories.single.categoryId, 1);
    expect(await migrated.select(migrated.tags).get(), isEmpty);
    expect(await migrated.select(migrated.mediaTags).get(), isEmpty);
    expect(
      await migrated.select(migrated.classificationSuggestions).get(),
      isEmpty,
    );
    final settings = await migrated
        .select(migrated.automaticImportSettings)
        .getSingle();
    expect(settings.enabled, isTrue);
    expect(settings.lastMediaId, 42);

    await (migrated.update(migrated.mediaItems)
          ..where((item) => item.id.equals(rows.first.id)))
        .write(const MediaItemsCompanion(mediaHash: Value('hash-repetido')));
    await expectLater(
      migrated
          .into(migrated.mediaItems)
          .insert(
            MediaItemsCompanion.insert(
              privatePath: '${directory.path}/outra.png',
              internalName: 'outra.png',
              mimeType: const Value('image/png'),
              mediaHash: const Value('hash-repetido'),
              importedAt: DateTime(2026),
              sourceMode: 'photoPicker',
              status: 'ready',
              importOrigin: const Value('shared'),
            ),
          ),
      throwsA(anything),
    );
    final sharedId = await migrated
        .into(migrated.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            privatePath: '${directory.path}/compartilhada.png',
            internalName: 'compartilhada.png',
            importedAt: DateTime(2026),
            sourceMode: 'photoPicker',
            status: 'ready',
            importOrigin: const Value('shared'),
          ),
        );
    final persistedCapture = DateTime(2024, 7, 8, 9, 10);
    await (migrated.update(migrated.mediaItems)
          ..where((item) => item.id.equals(sharedId)))
        .write(MediaItemsCompanion(capturedAt: Value(persistedCapture)));
    final tagId = await migrated
        .into(migrated.tags)
        .insert(
          TagsCompanion.insert(
            name: 'Urgente',
            normalizedName: 'urgente',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
    await migrated
        .into(migrated.mediaTags)
        .insert(
          MediaTagsCompanion.insert(
            mediaItemId: sharedId,
            tagId: tagId,
            createdAt: DateTime(2026),
          ),
        );
    expect(
      (await (migrated.select(
        migrated.mediaItems,
      )..where((item) => item.id.equals(sharedId))).getSingle()).importOrigin,
      'shared',
    );

    await migrated.close();

    final reopened = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    final reopenedOcr = await reopened.select(reopened.ocrResults).getSingle();
    expect(reopenedOcr.normalizedText, 'texto ficticio preservado');
    expect(await reopened.select(reopened.mediaItems).get(), hasLength(3));
    expect(
      (await (reopened.select(
        reopened.mediaItems,
      )..where((item) => item.id.equals(sharedId))).getSingle()).capturedAt,
      persistedCapture,
    );
    expect(await reopened.select(reopened.processingJobs).get(), hasLength(1));
    expect((await reopened.select(reopened.tags).getSingle()).name, 'Urgente');
    expect(
      (await reopened.select(reopened.mediaTags).getSingle()).mediaItemId,
      sharedId,
    );
    await reopened.close();
    directory.deleteSync(recursive: true);
  });

  test('migra schema 10 para 12 preservando IDs e associações', () async {
    final directory = Directory.systemTemp.createTempSync(
      'memoshot_migration_10_test_',
    );
    final databaseFile = File('${directory.path}/contexto.sqlite');
    final legacy = _LegacyDatabase(NativeDatabase(databaseFile));
    await legacy.customSelect('SELECT 1').get();
    await legacy.customStatement(
      'ALTER TABLE media_items ADD COLUMN captured_at INTEGER NULL',
    );
    await legacy.customStatement('''
      CREATE TABLE tags (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        normalized_name TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await legacy.customStatement('''
      CREATE TABLE media_tags (
        media_item_id INTEGER NOT NULL
          REFERENCES media_items (id) ON DELETE CASCADE,
        tag_id INTEGER NOT NULL
          REFERENCES tags (id) ON DELETE CASCADE,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (media_item_id, tag_id)
      )
    ''');
    await legacy.customStatement(
      '''
      INSERT INTO media_items (
        id, private_path, internal_name, imported_at, source_mode, status
      ) VALUES (3, '/tmp/preservada.png', 'preservada.png', ?, 'photoPicker', 'ready')
      ''',
      [DateTime(2025).millisecondsSinceEpoch ~/ 1000],
    );
    await legacy.customStatement(
      "INSERT INTO categories (id, name, normalized_name, created_at) VALUES (7, 'Livros', 'livros', ?)",
      [DateTime(2025).millisecondsSinceEpoch ~/ 1000],
    );
    await legacy.customStatement(
      'INSERT INTO media_categories (media_item_id, category_id, created_at) VALUES (3, 7, ?)',
      [DateTime(2025).millisecondsSinceEpoch ~/ 1000],
    );
    await legacy.customStatement('PRAGMA user_version = 10');
    await legacy.close();

    final migrated = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();
    final category = await migrated.select(migrated.categories).getSingle();
    final relation = await migrated
        .select(migrated.mediaCategories)
        .getSingle();

    expect(version.read<int>('user_version'), 12);
    expect(category.id, 7);
    expect(category.name, 'Livros');
    expect(category.parentId, isNull);
    expect(relation.mediaItemId, 3);
    expect(relation.categoryId, 7);
    expect(await migrated.select(migrated.mediaItems).get(), hasLength(1));
    expect(
      await migrated.select(migrated.classificationSuggestions).get(),
      isEmpty,
    );

    await migrated.close();
    directory.deleteSync(recursive: true);
  });

  test('migra schema 11 para 12 e cria fila vazia', () async {
    final directory = Directory.systemTemp.createTempSync(
      'memoshot_migration_11_test_',
    );
    final databaseFile = File('${directory.path}/contexto.sqlite');
    final legacy = _LegacyDatabase(NativeDatabase(databaseFile));
    await legacy.customSelect('SELECT 1').get();
    await legacy.customStatement(
      'ALTER TABLE media_items ADD COLUMN captured_at INTEGER NULL',
    );
    await legacy.customStatement('''
      CREATE TABLE tags (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        normalized_name TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await legacy.customStatement('''
      CREATE TABLE media_tags (
        media_item_id INTEGER NOT NULL
          REFERENCES media_items (id) ON DELETE CASCADE,
        tag_id INTEGER NOT NULL
          REFERENCES tags (id) ON DELETE CASCADE,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (media_item_id, tag_id)
      )
    ''');
    await legacy.customStatement(
      'ALTER TABLE categories ADD COLUMN parent_id INTEGER NULL '
      'REFERENCES categories (id) ON DELETE RESTRICT',
    );
    final timestamp = DateTime(2025).millisecondsSinceEpoch ~/ 1000;
    await legacy.customStatement(
      "INSERT INTO media_items (id, private_path, internal_name, imported_at, "
      "source_mode, status) VALUES (4, '/tmp/item.png', 'item.png', ?, "
      "'picker', 'ready')",
      [timestamp],
    );
    await legacy.customStatement(
      "INSERT INTO categories (id, name, normalized_name, created_at) "
      "VALUES (9, 'Livros', 'livros', ?)",
      [timestamp],
    );
    await legacy.customStatement(
      'INSERT INTO media_categories '
      '(media_item_id, category_id, created_at) VALUES (4, 9, ?)',
      [timestamp],
    );
    await legacy.customStatement(
      "INSERT INTO ocr_results (media_item_id, full_text, normalized_text, "
      "engine, engine_version, processed_at) VALUES "
      "(4, 'Texto preservado', 'texto preservado', 'Teste', '1', ?)",
      [timestamp],
    );
    await legacy.customStatement('PRAGMA user_version = 11');
    await legacy.close();

    final migrated = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    expect(
      (await migrated.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      12,
    );
    expect((await migrated.select(migrated.mediaItems).getSingle()).id, 4);
    expect((await migrated.select(migrated.categories).getSingle()).id, 9);
    expect(
      (await migrated.select(migrated.mediaCategories).getSingle()).categoryId,
      9,
    );
    expect(
      (await migrated.select(migrated.ocrResults).getSingle()).fullText,
      'Texto preservado',
    );
    expect(
      await migrated.select(migrated.classificationSuggestions).get(),
      isEmpty,
    );

    await migrated.close();
    directory.deleteSync(recursive: true);
  });
}

class _LegacyDatabase extends GeneratedDatabase {
  _LegacyDatabase(super.executor);

  @override
  final List<TableInfo> allTables = const [];

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await customStatement('''
        CREATE TABLE media_items (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          private_path TEXT NOT NULL,
          internal_name TEXT NOT NULL,
          mime_type TEXT NULL,
          media_hash TEXT NULL,
          imported_at INTEGER NOT NULL,
          source_mode TEXT NOT NULL,
          import_origin TEXT NOT NULL DEFAULT 'picker',
          status TEXT NOT NULL
        )
      ''');
      await customStatement('''
        CREATE TABLE automatic_import_settings (
          id INTEGER NOT NULL PRIMARY KEY,
          enabled INTEGER NOT NULL DEFAULT 0,
          last_media_id INTEGER NULL,
          enabled_at INTEGER NULL,
          last_scan_at INTEGER NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await customStatement('''
        CREATE TABLE categories (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          normalized_name TEXT NOT NULL UNIQUE,
          created_at INTEGER NOT NULL
        )
      ''');
      await customStatement('''
        CREATE TABLE media_categories (
          media_item_id INTEGER NOT NULL
            REFERENCES media_items (id) ON DELETE CASCADE,
          category_id INTEGER NOT NULL
            REFERENCES categories (id) ON DELETE CASCADE,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (media_item_id, category_id)
        )
      ''');
      await customStatement('''
        CREATE TABLE processing_jobs (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          media_item_id INTEGER NOT NULL
            REFERENCES media_items (id) ON DELETE CASCADE,
          job_type TEXT NOT NULL,
          status TEXT NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          error_code TEXT NULL,
          created_at INTEGER NOT NULL,
          started_at INTEGER NULL,
          finished_at INTEGER NULL,
          UNIQUE (media_item_id, job_type)
        )
      ''');
      await customStatement(
        'CREATE UNIQUE INDEX media_items_media_hash_unique '
        'ON media_items (media_hash) WHERE media_hash IS NOT NULL',
      );
      await customStatement('''
        CREATE TABLE ocr_results (
          media_item_id INTEGER NOT NULL PRIMARY KEY
            REFERENCES media_items (id) ON DELETE CASCADE,
          full_text TEXT NOT NULL,
          normalized_text TEXT NOT NULL DEFAULT '',
          engine TEXT NOT NULL,
          engine_version TEXT NOT NULL,
          processed_at INTEGER NOT NULL
        )
      ''');
    },
  );
}

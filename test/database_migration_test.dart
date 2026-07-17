import 'dart:io';

import 'package:contexto/core/database/contexto_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migra schema 5 para 6 preservando as tabelas existentes', () async {
    final directory = Directory.systemTemp.createTempSync(
      'contexto_migration_test_',
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

    expect(version.read<int>('user_version'), 6);
    expect(rows, hasLength(1));
    expect(rows.single.internalName, 'copia.png');
    expect(rows.single.mediaHash, isNull);
    final ocrRows = await migrated.select(migrated.ocrResults).get();
    expect(ocrRows.single.fullText, 'Texto fictício preservado');
    expect(ocrRows.single.normalizedText, 'texto ficticio preservado');
    expect(await migrated.select(migrated.processingJobs).get(), hasLength(1));
    expect(await migrated.select(migrated.categories).get(), isEmpty);
    expect(await migrated.select(migrated.mediaCategories).get(), isEmpty);

    await (migrated.update(migrated.mediaItems)
          ..where((item) => item.id.equals(rows.single.id)))
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
            ),
          ),
      throwsA(anything),
    );

    await migrated.close();

    final reopened = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    final reopenedOcr = await reopened.select(reopened.ocrResults).getSingle();
    expect(reopenedOcr.normalizedText, 'texto ficticio preservado');
    expect(await reopened.select(reopened.mediaItems).get(), hasLength(1));
    expect(await reopened.select(reopened.processingJobs).get(), hasLength(1));
    await reopened.close();
    directory.deleteSync(recursive: true);
  });
}

class _LegacyDatabase extends GeneratedDatabase {
  _LegacyDatabase(super.executor);

  @override
  final List<TableInfo> allTables = const [];

  @override
  int get schemaVersion => 5;

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
          status TEXT NOT NULL
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

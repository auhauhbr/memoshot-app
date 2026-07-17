import 'dart:io';

import 'package:contexto/core/database/contexto_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migra schema 2 para 3 preservando media_items', () async {
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
    await legacy.close();

    final migrated = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    final rows = await migrated.select(migrated.mediaItems).get();
    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();

    expect(version.read<int>('user_version'), 3);
    expect(rows, hasLength(1));
    expect(rows.single.internalName, 'copia.png');
    expect(rows.single.mediaHash, isNull);
    final ocrTable = await migrated
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'ocr_results'",
        )
        .getSingleOrNull();
    expect(ocrTable, isNotNull);

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
    directory.deleteSync(recursive: true);
  });
}

class _LegacyDatabase extends GeneratedDatabase {
  _LegacyDatabase(super.executor);

  @override
  final List<TableInfo> allTables = const [];

  @override
  int get schemaVersion => 2;

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
      await customStatement(
        'CREATE UNIQUE INDEX media_items_media_hash_unique '
        'ON media_items (media_hash) WHERE media_hash IS NOT NULL',
      );
    },
  );
}

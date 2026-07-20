import 'dart:io';

import 'package:memoshot/core/database/contexto_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migra schema 8 para 17 preservando dados e hierarquia', () async {
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

    expect(version.read<int>('user_version'), 17);
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
    expect(await migrated.select(migrated.classificationJobs).get(), isEmpty);
    expect(
      await migrated.select(migrated.existingScreenshotCandidates).get(),
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
              privatePath: Value('${directory.path}/outra.png'),
              internalName: Value('outra.png'),
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
            privatePath: Value('${directory.path}/compartilhada.png'),
            internalName: Value('compartilhada.png'),
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

  test('migra schema 10 para 17 preservando IDs e associações', () async {
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

    expect(version.read<int>('user_version'), 17);
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
    expect(await migrated.select(migrated.classificationJobs).get(), isEmpty);

    await migrated.close();
    directory.deleteSync(recursive: true);
  });

  test('migra schema 11 para 17 e cria estruturas novas vazias', () async {
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
      17,
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
    expect(await migrated.select(migrated.classificationJobs).get(), isEmpty);

    await migrated.close();
    directory.deleteSync(recursive: true);
  });

  test('migra schema 12 para 17 preservando sugestões e organização', () async {
    final directory = Directory.systemTemp.createTempSync(
      'memoshot_migration_12_test_',
    );
    final databaseFile = File('${directory.path}/contexto.sqlite');
    final timestamp = DateTime.utc(2026, 7, 19);
    var database = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    final mediaIds = <int>[];
    for (var index = 0; index < 4; index++) {
      mediaIds.add(
        await database
            .into(database.mediaItems)
            .insert(
              MediaItemsCompanion.insert(
                privatePath: Value('${directory.path}/item-$index.png'),
                internalName: Value('item-$index.png'),
                importedAt: timestamp,
                sourceMode: 'photoPicker',
                status: 'ready',
              ),
            ),
      );
      await database
          .into(database.ocrResults)
          .insert(
            OcrResultsCompanion.insert(
              mediaItemId: Value(mediaIds.last),
              fullText: 'Texto preservado $index',
              normalizedText: Value('texto preservado $index'),
              engine: 'Teste',
              engineVersion: '1',
              processedAt: timestamp,
            ),
          );
    }
    final rootId = await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Carreira',
            normalizedName: 'carreira',
            createdAt: timestamp,
          ),
        );
    final childId = await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Entrevistas',
            normalizedName: 'entrevistas',
            parentId: Value(rootId),
            createdAt: timestamp,
          ),
        );
    await database
        .into(database.mediaCategories)
        .insert(
          MediaCategoriesCompanion.insert(
            mediaItemId: mediaIds.first,
            categoryId: childId,
            createdAt: timestamp,
          ),
        );
    final tagId = await database
        .into(database.tags)
        .insert(
          TagsCompanion.insert(
            name: 'Urgente',
            normalizedName: 'urgente',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    await database
        .into(database.mediaTags)
        .insert(
          MediaTagsCompanion.insert(
            mediaItemId: mediaIds.first,
            tagId: tagId,
            createdAt: timestamp,
          ),
        );
    const statuses = ['pendingReview', 'accepted', 'rejected', 'autoApplied'];
    for (var index = 0; index < statuses.length; index++) {
      await database
          .into(database.classificationSuggestions)
          .insert(
            ClassificationSuggestionsCompanion.insert(
              mediaItemId: Value(mediaIds[index]),
              suggestedCategoryName: const Value('Carreira'),
              confidence: 0.9,
              hasSuggestion: true,
              suggestedTagsJson: '[]',
              evidenceJson: '[]',
              status: statuses[index],
              reviewReason: const Value('manualReview'),
              engineVersion: 1,
              createdAt: timestamp,
              updatedAt: timestamp,
              resolvedAt: Value(index == 0 ? null : timestamp),
            ),
          );
    }
    await database.close();

    final schemaEditor = _SchemaEditorDatabase(NativeDatabase(databaseFile));
    await schemaEditor.customStatement('DROP TABLE classification_jobs');
    await schemaEditor.customStatement('PRAGMA user_version = 12');
    await schemaEditor.close();

    database = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    expect(
      (await database.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      17,
    );
    expect(await database.select(database.mediaItems).get(), hasLength(4));
    expect(await database.select(database.ocrResults).get(), hasLength(4));
    expect(
      (await database.select(database.ocrResults).get()).map(
        (row) => row.fullText,
      ),
      contains('Texto preservado 0'),
    );
    final categories = await database.select(database.categories).get();
    expect(categories, hasLength(2));
    expect(categories.singleWhere((row) => row.id == childId).parentId, rootId);
    expect(await database.select(database.mediaCategories).get(), hasLength(1));
    expect(await database.select(database.tags).get(), hasLength(1));
    expect(await database.select(database.mediaTags).get(), hasLength(1));
    expect(
      (await database.select(database.classificationSuggestions).get()).map(
        (row) => row.status,
      ),
      containsAll(statuses),
    );
    expect(await database.select(database.classificationJobs).get(), isEmpty);
    expect(
      await database.select(database.existingScreenshotCandidates).get(),
      isEmpty,
    );

    await database.close();
    directory.deleteSync(recursive: true);
  });

  test('migra schema 13 para 17 preservando todo o estado anterior', () async {
    final directory = Directory.systemTemp.createTempSync(
      'memoshot_migration_13_test_',
    );
    final databaseFile = File('${directory.path}/contexto.sqlite');
    final timestamp = DateTime.utc(2026, 7, 19);
    var database = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    final mediaId = await database
        .into(database.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            privatePath: Value('${directory.path}/preservada.png'),
            internalName: Value('preservada.png'),
            importedAt: timestamp,
            sourceMode: 'photoPicker',
            status: 'ready',
            mediaHash: const Value('hash-preservado'),
          ),
        );
    await database
        .into(database.ocrResults)
        .insert(
          OcrResultsCompanion.insert(
            mediaItemId: Value(mediaId),
            fullText: 'OCR preservado',
            normalizedText: const Value('ocr preservado'),
            engine: 'Teste',
            engineVersion: '1',
            processedAt: timestamp,
          ),
        );
    await database
        .into(database.processingJobs)
        .insert(
          ProcessingJobsCompanion.insert(
            mediaItemId: mediaId,
            jobType: 'ocr',
            status: 'completed',
            createdAt: timestamp,
          ),
        );
    final categoryId = await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Documentos',
            normalizedName: 'documentos',
            createdAt: timestamp,
          ),
        );
    await database
        .into(database.mediaCategories)
        .insert(
          MediaCategoriesCompanion.insert(
            mediaItemId: mediaId,
            categoryId: categoryId,
            createdAt: timestamp,
          ),
        );
    final tagId = await database
        .into(database.tags)
        .insert(
          TagsCompanion.insert(
            name: 'Importante',
            normalizedName: 'importante',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    await database
        .into(database.mediaTags)
        .insert(
          MediaTagsCompanion.insert(
            mediaItemId: mediaId,
            tagId: tagId,
            createdAt: timestamp,
          ),
        );
    await database
        .into(database.classificationSuggestions)
        .insert(
          ClassificationSuggestionsCompanion.insert(
            mediaItemId: Value(mediaId),
            confidence: 0.8,
            hasSuggestion: true,
            suggestedTagsJson: '[]',
            evidenceJson: '[]',
            status: 'accepted',
            engineVersion: 1,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    await database
        .into(database.classificationJobs)
        .insert(
          ClassificationJobsCompanion.insert(
            mediaItemId: Value(mediaId),
            state: 'completed',
            availableAt: timestamp,
            engineVersion: 1,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    await database.close();

    final editor = _SchemaEditorDatabase(NativeDatabase(databaseFile));
    await editor.customStatement('DROP TABLE existing_screenshot_candidates');
    await editor.customStatement(
      'DROP TABLE existing_screenshot_inventory_states',
    );
    await editor.customStatement('PRAGMA user_version = 13');
    await editor.close();

    database = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    expect(
      (await database.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      17,
    );
    expect(
      (await database.select(database.mediaItems).getSingle()).mediaHash,
      'hash-preservado',
    );
    expect(
      (await database.select(database.ocrResults).getSingle()).fullText,
      'OCR preservado',
    );
    expect(await database.select(database.processingJobs).get(), hasLength(1));
    expect(
      await database.select(database.classificationJobs).get(),
      hasLength(1),
    );
    expect(
      (await database.select(database.classificationSuggestions).getSingle())
          .status,
      'accepted',
    );
    expect(await database.select(database.categories).get(), hasLength(1));
    expect(await database.select(database.mediaCategories).get(), hasLength(1));
    expect(await database.select(database.tags).get(), hasLength(1));
    expect(await database.select(database.mediaTags).get(), hasLength(1));
    expect(
      await database.select(database.existingScreenshotCandidates).get(),
      isEmpty,
    );

    await database.close();
    directory.deleteSync(recursive: true);
  });

  test(
    'migra schema 14 para 17 tornando itens antigos arquivos privados',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'memoshot_migration_14_test_',
      );
      final databaseFile = File('${directory.path}/contexto.sqlite');
      final timestamp = DateTime.utc(2026, 7, 19);
      var database = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
      final mediaId = await database
          .into(database.mediaItems)
          .insert(
            MediaItemsCompanion.insert(
              privatePath: Value('${directory.path}/preservada.png'),
              internalName: const Value('preservada.png'),
              mediaHash: const Value('hash-14'),
              importedAt: timestamp,
              sourceMode: 'photoPicker',
              status: 'ready',
            ),
          );
      await database
          .into(database.ocrResults)
          .insert(
            OcrResultsCompanion.insert(
              mediaItemId: Value(mediaId),
              fullText: 'OCR 14',
              normalizedText: const Value('ocr 14'),
              engine: 'Teste',
              engineVersion: '1',
              processedAt: timestamp,
            ),
          );
      await database
          .into(database.processingJobs)
          .insert(
            ProcessingJobsCompanion.insert(
              mediaItemId: mediaId,
              jobType: 'ocr',
              status: 'completed',
              createdAt: timestamp,
            ),
          );
      final categoryId = await database
          .into(database.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Preservada',
              normalizedName: 'preservada',
              createdAt: timestamp,
            ),
          );
      await database
          .into(database.mediaCategories)
          .insert(
            MediaCategoriesCompanion.insert(
              mediaItemId: mediaId,
              categoryId: categoryId,
              createdAt: timestamp,
            ),
          );
      final tagId = await database
          .into(database.tags)
          .insert(
            TagsCompanion.insert(
              name: 'Importante',
              normalizedName: 'importante-14',
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      await database
          .into(database.mediaTags)
          .insert(
            MediaTagsCompanion.insert(
              mediaItemId: mediaId,
              tagId: tagId,
              createdAt: timestamp,
            ),
          );
      await database
          .into(database.classificationSuggestions)
          .insert(
            ClassificationSuggestionsCompanion.insert(
              mediaItemId: Value(mediaId),
              confidence: 0.9,
              hasSuggestion: true,
              suggestedTagsJson: '[]',
              evidenceJson: '[]',
              status: 'accepted',
              engineVersion: 1,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      await database
          .into(database.classificationJobs)
          .insert(
            ClassificationJobsCompanion.insert(
              mediaItemId: Value(mediaId),
              state: 'completed',
              availableAt: timestamp,
              engineVersion: 1,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      await database
          .into(database.existingScreenshotCandidates)
          .insert(
            ExistingScreenshotCandidatesCompanion.insert(
              sourceKey: 'external:77',
              mediaStoreId: 77,
              volumeName: 'external',
              contentUri: 'content://media/external/images/media/77',
              discoveredAt: timestamp,
              lastSeenAt: timestamp,
              availabilityState: 'available',
            ),
          );
      await database.close();

      final editor = _SchemaEditorDatabase(NativeDatabase(databaseFile));
      await _downgradeMediaItemsTo14(editor);
      await editor.close();

      database = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
      final row = await database.select(database.mediaItems).getSingle();
      expect(row.id, mediaId);
      expect(row.storageKind, 'privateFile');
      expect(row.privatePath, '${directory.path}/preservada.png');
      expect(row.internalName, 'preservada.png');
      expect(row.mediaHash, 'hash-14');
      expect(row.sourceKey, isNull);
      expect(row.contentUri, isNull);
      expect(
        (await database.select(database.ocrResults).getSingle()).fullText,
        'OCR 14',
      );
      expect(
        await database.select(database.processingJobs).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.classificationJobs).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.classificationSuggestions).get(),
        hasLength(1),
      );
      expect(await database.select(database.categories).get(), hasLength(1));
      expect(
        await database.select(database.mediaCategories).get(),
        hasLength(1),
      );
      expect(await database.select(database.tags).get(), hasLength(1));
      expect(await database.select(database.mediaTags).get(), hasLength(1));
      expect(
        (await database
                .select(database.existingScreenshotCandidates)
                .getSingle())
            .sourceKey,
        'external:77',
      );
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        17,
      );
      await database.close();
      directory.deleteSync(recursive: true);
    },
  );

  test(
    'migra schema 15 para 17 criando somente a fila histórica vazia',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'memoshot_migration_15_test_',
      );
      final databaseFile = File('${directory.path}/contexto.sqlite');
      final timestamp = DateTime.utc(2026, 7, 19);
      var database = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
      await database
          .into(database.mediaItems)
          .insert(
            MediaItemsCompanion.insert(
              privatePath: const Value('/privado/preservado.png'),
              internalName: const Value('preservado.png'),
              importedAt: timestamp,
              sourceMode: 'photoPicker',
              status: 'ready',
            ),
          );
      await database
          .into(database.mediaItems)
          .insert(
            MediaItemsCompanion.insert(
              storageKind: const Value('mediaStoreReference'),
              sourceKey: const Value('external:77'),
              mediaStoreId: const Value(77),
              volumeName: const Value('external'),
              contentUri: const Value(
                'content://media/external/images/media/77',
              ),
              importedAt: timestamp,
              sourceMode: 'mediaStoreReference',
              status: 'ready',
            ),
          );
      await database
          .into(database.existingScreenshotCandidates)
          .insert(
            ExistingScreenshotCandidatesCompanion.insert(
              sourceKey: 'external:77',
              mediaStoreId: 77,
              volumeName: 'external',
              contentUri: 'content://media/external/images/media/77',
              discoveredAt: timestamp,
              lastSeenAt: timestamp,
              availabilityState: 'available',
            ),
          );
      await database.close();

      final editor = _SchemaEditorDatabase(NativeDatabase(databaseFile));
      await editor.customStatement('DROP TABLE historical_media_import_jobs');
      await editor.customStatement('PRAGMA user_version = 15');
      await editor.close();

      database = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        17,
      );
      expect(await database.select(database.mediaItems).get(), hasLength(2));
      expect(
        (await database.select(database.mediaItems).get()).map(
          (row) => row.storageKind,
        ),
        containsAll(['privateFile', 'mediaStoreReference']),
      );
      expect(
        await database.select(database.existingScreenshotCandidates).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.historicalMediaImportJobs).get(),
        isEmpty,
      );
      await database.close();
      directory.deleteSync(recursive: true);
    },
  );

  test('migra schema 16 para 17 sem preencher itens históricos', () async {
    final directory = Directory.systemTemp.createTempSync(
      'memoshot_migration_16_test_',
    );
    final databaseFile = File('${directory.path}/contexto.sqlite');
    final timestamp = DateTime.utc(2026, 7, 19);
    var database = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    final mediaId = await database
        .into(database.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            privatePath: const Value('/privado/historico.png'),
            internalName: const Value('historico.png'),
            importedAt: timestamp,
            capturedAt: Value(timestamp),
            sourceMode: 'photoPicker',
            status: 'ready',
          ),
        );
    await database.close();

    final editor = _SchemaEditorDatabase(NativeDatabase(databaseFile));
    await editor.customStatement('DROP TABLE media_capture_contexts');
    await editor.customStatement('PRAGMA user_version = 16');
    await editor.close();

    database = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    expect(
      (await database.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      17,
    );
    expect(
      (await database.select(database.mediaItems).getSingle()).id,
      mediaId,
    );
    expect(await database.select(database.mediaCaptureContexts).get(), isEmpty);
    await database.close();
    directory.deleteSync(recursive: true);
  });
}

Future<void> _downgradeMediaItemsTo14(GeneratedDatabase database) async {
  await database.customStatement('PRAGMA foreign_keys = OFF');
  await database.customStatement('PRAGMA legacy_alter_table = ON');
  await database.customStatement(
    'ALTER TABLE media_items RENAME TO media_items_v15',
  );
  await database.customStatement('''
    CREATE TABLE media_items (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      private_path TEXT NOT NULL,
      internal_name TEXT NOT NULL,
      mime_type TEXT NULL,
      media_hash TEXT NULL,
      imported_at INTEGER NOT NULL,
      captured_at INTEGER NULL,
      source_mode TEXT NOT NULL,
      import_origin TEXT NOT NULL DEFAULT 'picker',
      status TEXT NOT NULL
    )
  ''');
  await database.customStatement('''
    INSERT INTO media_items (
      id, private_path, internal_name, mime_type, media_hash, imported_at,
      captured_at, source_mode, import_origin, status
    ) SELECT id, private_path, internal_name, mime_type, media_hash, imported_at,
      captured_at, source_mode, import_origin, status FROM media_items_v15
  ''');
  await database.customStatement('DROP TABLE media_items_v15');
  await database.customStatement(
    'CREATE UNIQUE INDEX media_items_media_hash_unique '
    'ON media_items (media_hash) WHERE media_hash IS NOT NULL',
  );
  await database.customStatement('PRAGMA user_version = 14');
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

class _SchemaEditorDatabase extends GeneratedDatabase {
  _SchemaEditorDatabase(super.executor);

  @override
  final List<TableInfo> allTables = const [];

  @override
  int get schemaVersion => 17;
}

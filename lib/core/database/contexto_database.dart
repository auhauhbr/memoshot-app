import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../text/text_normalizer.dart';

part 'contexto_database.g.dart';

class MediaItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get privatePath => text()();

  TextColumn get internalName => text()();

  TextColumn get mimeType => text().nullable()();

  TextColumn get mediaHash => text().nullable()();

  DateTimeColumn get importedAt => dateTime()();

  TextColumn get sourceMode => text()();

  TextColumn get importOrigin => text().withDefault(const Constant('picker'))();

  TextColumn get status => text()();
}

class OcrResults extends Table {
  IntColumn get mediaItemId =>
      integer().references(MediaItems, #id, onDelete: KeyAction.cascade)();

  TextColumn get fullText => text()();

  TextColumn get normalizedText => text().withDefault(const Constant(''))();

  TextColumn get engine => text()();

  TextColumn get engineVersion => text()();

  DateTimeColumn get processedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {mediaItemId};
}

class ProcessingJobs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get mediaItemId =>
      integer().references(MediaItems, #id, onDelete: KeyAction.cascade)();

  TextColumn get jobType => text()();

  TextColumn get status => text()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get errorCode => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get startedAt => dateTime().nullable()();

  DateTimeColumn get finishedAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {mediaItemId, jobType},
  ];
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get normalizedName => text().unique()();

  DateTimeColumn get createdAt => dateTime()();
}

class MediaCategories extends Table {
  IntColumn get mediaItemId =>
      integer().references(MediaItems, #id, onDelete: KeyAction.cascade)();

  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {mediaItemId, categoryId};
}

@DriftDatabase(
  tables: [MediaItems, OcrResults, ProcessingJobs, Categories, MediaCategories],
)
class ContextoDatabase extends _$ContextoDatabase {
  ContextoDatabase() : super(_openConnection());

  ContextoDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createMediaHashIndex();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(mediaItems, mediaItems.mediaHash);
        await _createMediaHashIndex();
      }
      if (from < 3) {
        await migrator.createTable(ocrResults);
      }
      if (from < 4) {
        await migrator.createTable(processingJobs);
      }
      if (from >= 3 && from < 5) {
        await migrator.addColumn(ocrResults, ocrResults.normalizedText);
        await _backfillNormalizedOcrText();
      }
      if (from < 6) {
        await migrator.createTable(categories);
        await migrator.createTable(mediaCategories);
      }
      if (from < 7) {
        await migrator.addColumn(mediaItems, mediaItems.importOrigin);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _backfillNormalizedOcrText();
    },
  );

  Future<void> _createMediaHashIndex() {
    return customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS media_items_media_hash_unique '
      'ON media_items (media_hash) WHERE media_hash IS NOT NULL',
    );
  }

  Future<void> _backfillNormalizedOcrText() async {
    final rows = await customSelect(
      'SELECT media_item_id, full_text FROM ocr_results '
      "WHERE normalized_text = '' AND full_text <> ''",
      readsFrom: {ocrResults},
    ).get();
    const normalizer = TextNormalizer();
    for (final row in rows) {
      await customUpdate(
        'UPDATE ocr_results SET normalized_text = ? WHERE media_item_id = ?',
        variables: [
          Variable<String>(normalizer.normalize(row.read<String>('full_text'))),
          Variable<int>(row.read<int>('media_item_id')),
        ],
        updates: {ocrResults},
      );
    }
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'contexto');
  }
}

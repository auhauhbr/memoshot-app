import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'contexto_database.g.dart';

class MediaItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get privatePath => text()();

  TextColumn get internalName => text()();

  TextColumn get mimeType => text().nullable()();

  TextColumn get mediaHash => text().nullable()();

  DateTimeColumn get importedAt => dateTime()();

  TextColumn get sourceMode => text()();

  TextColumn get status => text()();
}

class OcrResults extends Table {
  IntColumn get mediaItemId =>
      integer().references(MediaItems, #id, onDelete: KeyAction.cascade)();

  TextColumn get fullText => text()();

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

@DriftDatabase(tables: [MediaItems, OcrResults, ProcessingJobs])
class ContextoDatabase extends _$ContextoDatabase {
  ContextoDatabase() : super(_openConnection());

  ContextoDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

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
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createMediaHashIndex() {
    return customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS media_items_media_hash_unique '
      'ON media_items (media_hash) WHERE media_hash IS NOT NULL',
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'contexto');
  }
}

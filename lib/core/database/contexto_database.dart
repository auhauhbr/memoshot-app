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

@DriftDatabase(tables: [MediaItems])
class ContextoDatabase extends _$ContextoDatabase {
  ContextoDatabase() : super(_openConnection());

  ContextoDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

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

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'contexto_database.g.dart';

class MediaItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get privatePath => text()();

  TextColumn get internalName => text()();

  TextColumn get mimeType => text().nullable()();

  DateTimeColumn get importedAt => dateTime()();

  TextColumn get sourceMode => text()();

  TextColumn get status => text()();
}

@DriftDatabase(tables: [MediaItems])
class ContextoDatabase extends _$ContextoDatabase {
  ContextoDatabase() : super(_openConnection());

  ContextoDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'contexto');
  }
}

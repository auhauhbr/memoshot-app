import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../domain/media_item.dart' as domain;

abstract interface class MediaItemStore {
  Future<int> insertItem({
    required String privatePath,
    required String internalName,
    required String? mimeType,
    required DateTime importedAt,
    required String sourceMode,
    required String status,
  });

  Future<List<domain.MediaItem>> readItems();

  Future<void> close();
}

class DriftMediaItemStore implements MediaItemStore {
  DriftMediaItemStore(this._database);

  final ContextoDatabase _database;

  @override
  Future<int> insertItem({
    required String privatePath,
    required String internalName,
    required String? mimeType,
    required DateTime importedAt,
    required String sourceMode,
    required String status,
  }) {
    return _database
        .into(_database.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            privatePath: privatePath,
            internalName: internalName,
            mimeType: Value(mimeType),
            importedAt: importedAt,
            sourceMode: sourceMode,
            status: status,
          ),
        );
  }

  @override
  Future<List<domain.MediaItem>> readItems() async {
    final rows = await (_database.select(
      _database.mediaItems,
    )..orderBy([(item) => OrderingTerm.desc(item.importedAt)])).get();
    return rows
        .map(
          (row) => domain.MediaItem(
            id: row.id,
            privatePath: row.privatePath,
            internalName: row.internalName,
            mimeType: row.mimeType,
            importedAt: row.importedAt,
            sourceMode: row.sourceMode,
            status: row.status,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> close() => _database.close();
}

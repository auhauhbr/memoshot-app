import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../domain/media_item.dart' as domain;

abstract interface class MediaItemStore {
  Future<int> insertItem({
    required String privatePath,
    required String internalName,
    required String? mimeType,
    required String? mediaHash,
    required DateTime importedAt,
    required String sourceMode,
    required String status,
  });

  Future<List<domain.MediaItem>> readItems();

  Future<domain.MediaItem?> findByHash(String mediaHash);

  Future<void> updateHash(int id, String mediaHash);

  Future<void> deleteItem(int id);

  Future<List<RecognizedTextMatch>> searchRecognizedText(
    String normalizedQuery, {
    required int limit,
  });

  Future<void> close();
}

class RecognizedTextMatch {
  const RecognizedTextMatch({required this.mediaItem, required this.fullText});

  final domain.MediaItem mediaItem;
  final String fullText;
}

class DriftMediaItemStore implements MediaItemStore {
  DriftMediaItemStore(this._database);

  final ContextoDatabase _database;

  @override
  Future<int> insertItem({
    required String privatePath,
    required String internalName,
    required String? mimeType,
    required String? mediaHash,
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
            mediaHash: Value(mediaHash),
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
            mediaHash: row.mediaHash,
            importedAt: row.importedAt,
            sourceMode: row.sourceMode,
            status: row.status,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<domain.MediaItem?> findByHash(String mediaHash) async {
    final row = await (_database.select(
      _database.mediaItems,
    )..where((item) => item.mediaHash.equals(mediaHash))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> updateHash(int id, String mediaHash) async {
    await (_database.update(_database.mediaItems)
          ..where((item) => item.id.equals(id)))
        .write(MediaItemsCompanion(mediaHash: Value(mediaHash)));
  }

  @override
  Future<void> deleteItem(int id) async {
    await (_database.delete(
      _database.mediaItems,
    )..where((item) => item.id.equals(id))).go();
  }

  @override
  Future<List<RecognizedTextMatch>> searchRecognizedText(
    String normalizedQuery, {
    required int limit,
  }) async {
    final escaped = normalizedQuery
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final query = _database.select(_database.mediaItems).join([
      innerJoin(
        _database.ocrResults,
        _database.ocrResults.mediaItemId.equalsExp(_database.mediaItems.id),
      ),
    ]);
    query
      ..where(
        _database.ocrResults.normalizedText.like(
          '%$escaped%',
          escapeChar: r'\',
        ),
      )
      ..orderBy([OrderingTerm.desc(_database.mediaItems.importedAt)])
      ..limit(limit);
    final rows = await query.get();
    return rows
        .map((row) {
          final media = row.readTable(_database.mediaItems);
          final ocr = row.readTable(_database.ocrResults);
          return RecognizedTextMatch(
            mediaItem: _toDomain(media),
            fullText: ocr.fullText,
          );
        })
        .toList(growable: false);
  }

  domain.MediaItem _toDomain(MediaItem row) {
    return domain.MediaItem(
      id: row.id,
      privatePath: row.privatePath,
      internalName: row.internalName,
      mimeType: row.mimeType,
      mediaHash: row.mediaHash,
      importedAt: row.importedAt,
      sourceMode: row.sourceMode,
      status: row.status,
    );
  }

  @override
  Future<void> close() => _database.close();
}

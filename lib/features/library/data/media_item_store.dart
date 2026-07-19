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
    DateTime? capturedAt,
    required String sourceMode,
    required String status,
    domain.ImportOrigin importOrigin = domain.ImportOrigin.picker,
  });

  Future<int> insertMediaStoreReference({
    required domain.MediaStoreReferenceLocation location,
    required String? mimeType,
    required DateTime importedAt,
    required DateTime? capturedAt,
    required String sourceMode,
    required String status,
    domain.ImportOrigin importOrigin = domain.ImportOrigin.picker,
  });

  Future<List<domain.MediaItem>> readItems({int? tagId});

  Future<domain.MediaItem?> findById(int id);

  Future<domain.MediaItem?> findByHash(String mediaHash);

  Future<domain.MediaItem?> findBySourceKey(String sourceKey);

  Future<void> updateHash(int id, String mediaHash);

  Future<void> deleteItem(int id);

  Future<List<RecognizedTextMatch>> searchRecognizedText(
    String normalizedQuery, {
    int? tagId,
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
    DateTime? capturedAt,
    required String sourceMode,
    required String status,
    domain.ImportOrigin importOrigin = domain.ImportOrigin.picker,
  }) {
    return _database
        .into(_database.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            storageKind: const Value('privateFile'),
            privatePath: Value(privatePath),
            internalName: Value(internalName),
            mimeType: Value(mimeType),
            mediaHash: Value(mediaHash),
            importedAt: importedAt,
            capturedAt: Value(capturedAt),
            sourceMode: sourceMode,
            status: status,
            importOrigin: Value(importOrigin.databaseValue),
          ),
        );
  }

  @override
  Future<int> insertMediaStoreReference({
    required domain.MediaStoreReferenceLocation location,
    required String? mimeType,
    required DateTime importedAt,
    required DateTime? capturedAt,
    required String sourceMode,
    required String status,
    domain.ImportOrigin importOrigin = domain.ImportOrigin.picker,
  }) {
    return _database
        .into(_database.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            storageKind: const Value('mediaStoreReference'),
            privatePath: const Value(null),
            internalName: const Value(null),
            sourceKey: Value(location.sourceKey),
            mediaStoreId: Value(location.mediaStoreId),
            volumeName: Value(location.volumeName),
            contentUri: Value(location.contentUri),
            sourceDateModified: Value(location.dateModified),
            mimeType: Value(mimeType),
            mediaHash: const Value(null),
            importedAt: importedAt,
            capturedAt: Value(capturedAt),
            sourceMode: sourceMode,
            status: status,
            importOrigin: Value(importOrigin.databaseValue),
          ),
        );
  }

  @override
  Future<List<domain.MediaItem>> readItems({int? tagId}) async {
    if (tagId == null) {
      final rows =
          await (_database.select(_database.mediaItems)..orderBy([
                (_) => OrderingTerm.desc(
                  const CustomExpression<DateTime>(
                    'COALESCE(media_items.captured_at, media_items.imported_at)',
                  ),
                ),
                (item) => OrderingTerm.desc(item.importedAt),
                (item) => OrderingTerm.desc(item.id),
              ]))
              .get();
      return rows.map(_toDomain).toList(growable: false);
    }

    final query = _database.select(_database.mediaItems).join([
      innerJoin(
        _database.mediaTags,
        _database.mediaTags.mediaItemId.equalsExp(_database.mediaItems.id),
      ),
    ]);
    query
      ..where(_database.mediaTags.tagId.equals(tagId))
      ..orderBy(_recentFirstOrdering);
    final rows = await query.get();
    return rows
        .map((row) => _toDomain(row.readTable(_database.mediaItems)))
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
  Future<domain.MediaItem?> findById(int id) async {
    final row = await (_database.select(
      _database.mediaItems,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<domain.MediaItem?> findBySourceKey(String sourceKey) async {
    final row = await (_database.select(
      _database.mediaItems,
    )..where((item) => item.sourceKey.equals(sourceKey))).getSingleOrNull();
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
    int? tagId,
    required int limit,
  }) async {
    final escaped = normalizedQuery
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final query = tagId == null
        ? _database.select(_database.mediaItems).join([
            innerJoin(
              _database.ocrResults,
              _database.ocrResults.mediaItemId.equalsExp(
                _database.mediaItems.id,
              ),
            ),
          ])
        : _database.select(_database.mediaItems).join([
            innerJoin(
              _database.ocrResults,
              _database.ocrResults.mediaItemId.equalsExp(
                _database.mediaItems.id,
              ),
            ),
            innerJoin(
              _database.mediaTags,
              _database.mediaTags.mediaItemId.equalsExp(
                _database.mediaItems.id,
              ),
            ),
          ]);
    query
      ..where(
        _database.ocrResults.normalizedText.like(
              '%$escaped%',
              escapeChar: r'\',
            ) &
            (tagId == null
                ? const Constant(true)
                : _database.mediaTags.tagId.equals(tagId)),
      )
      ..orderBy(_recentFirstOrdering)
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

  List<OrderingTerm> get _recentFirstOrdering => [
    OrderingTerm.desc(
      const CustomExpression<DateTime>(
        'COALESCE(media_items.captured_at, media_items.imported_at)',
      ),
    ),
    OrderingTerm.desc(_database.mediaItems.importedAt),
    OrderingTerm.desc(_database.mediaItems.id),
  ];

  domain.MediaItem _toDomain(MediaItem row) {
    return domain.MediaItem(
      id: row.id,
      location: _location(row),
      mimeType: row.mimeType,
      mediaHash: row.mediaHash,
      importedAt: row.importedAt,
      capturedAt: row.capturedAt,
      sourceMode: row.sourceMode,
      status: row.status,
      importOrigin: domain.ImportOrigin.fromDatabase(row.importOrigin),
    );
  }

  domain.MediaItemLocation _location(MediaItem row) {
    return domain.mediaItemLocationFromStorage(
      storageKind: row.storageKind,
      privatePath: row.privatePath,
      internalName: row.internalName,
      sourceKey: row.sourceKey,
      mediaStoreId: row.mediaStoreId,
      volumeName: row.volumeName,
      contentUri: row.contentUri,
      sourceDateModified: row.sourceDateModified,
    );
  }

  @override
  Future<void> close() => _database.close();
}

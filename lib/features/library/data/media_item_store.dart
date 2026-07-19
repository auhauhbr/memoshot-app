import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../domain/media_item.dart' as domain;
import '../domain/media_page.dart';

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

abstract interface class PagedMediaItemStore implements MediaItemStore {
  Future<MediaPage<domain.MediaItem>> readMediaPage(MediaPageRequest request);

  Future<MediaPage<RecognizedTextMatch>> searchMediaPage(
    String normalizedQuery,
    MediaPageRequest request,
  );

  Future<int> countMediaItems({Set<int> tagIds = const {}});
}

abstract interface class RecentMediaItemStore implements MediaItemStore {
  Future<List<domain.MediaItem>> readRecentItems({
    required int limit,
    Set<int> tagIds = const {},
  });
}

class RecognizedTextMatch {
  const RecognizedTextMatch({required this.mediaItem, required this.fullText});

  final domain.MediaItem mediaItem;
  final String fullText;
}

class DriftMediaItemStore implements PagedMediaItemStore, RecentMediaItemStore {
  DriftMediaItemStore(this._database);

  final ContextoDatabase _database;

  @override
  Future<List<domain.MediaItem>> readRecentItems({
    required int limit,
    Set<int> tagIds = const {},
  }) async {
    final request = MediaPageRequest(pageSize: limit, tagIds: tagIds);
    final rows = await _readPageRows(request: request, exactLimit: true);
    return List.unmodifiable(rows.map(_queryRowToDomain));
  }

  @override
  Future<MediaPage<domain.MediaItem>> readMediaPage(
    MediaPageRequest request,
  ) async {
    final rows = await _readPageRows(request: request);
    final pageSize = request.effectivePageSize;
    final hasMore = rows.length > pageSize;
    final visible = rows.take(pageSize).map(_queryRowToDomain).toList();
    return MediaPage(
      items: List.unmodifiable(visible),
      nextCursor: hasMore && visible.isNotEmpty
          ? MediaPage.cursorFor(visible.last)
          : null,
    );
  }

  @override
  Future<MediaPage<RecognizedTextMatch>> searchMediaPage(
    String normalizedQuery,
    MediaPageRequest request,
  ) async {
    final rows = await _readPageRows(
      request: request,
      normalizedQuery: normalizedQuery,
      includeOcrText: true,
    );
    final pageSize = request.effectivePageSize;
    final hasMore = rows.length > pageSize;
    final matches = rows.take(pageSize).map((row) {
      return RecognizedTextMatch(
        mediaItem: _queryRowToDomain(row),
        fullText: row.read<String>('ocr_full_text'),
      );
    }).toList();
    return MediaPage(
      items: List.unmodifiable(matches),
      nextCursor: hasMore && matches.isNotEmpty
          ? MediaPage.cursorFor(matches.last.mediaItem)
          : null,
    );
  }

  Future<List<QueryRow>> _readPageRows({
    required MediaPageRequest request,
    String? normalizedQuery,
    bool includeOcrText = false,
    bool exactLimit = false,
  }) {
    final variables = <Variable<Object>>[];
    final joins = <String>[];
    final conditions = <String>[];
    if (normalizedQuery != null) {
      joins.add(
        'INNER JOIN ocr_results ON ocr_results.media_item_id = media_items.id',
      );
      final escaped = normalizedQuery
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      conditions.add("ocr_results.normalized_text LIKE ? ESCAPE '\\'");
      variables.add(Variable<String>('%$escaped%'));
    }
    for (final tagId in request.tagIds.toList()..sort()) {
      conditions.add(
        'EXISTS (SELECT 1 FROM media_tags '
        'WHERE media_tags.media_item_id = media_items.id '
        'AND media_tags.tag_id = ?)',
      );
      variables.add(Variable<int>(tagId));
    }
    if (request.cursor case final cursor?) {
      conditions.add(
        '(COALESCE(media_items.captured_at, media_items.imported_at) < ? '
        'OR (COALESCE(media_items.captured_at, media_items.imported_at) = ? '
        'AND media_items.id < ?))',
      );
      variables
        ..add(Variable<DateTime>(cursor.capturedAt))
        ..add(Variable<DateTime>(cursor.capturedAt))
        ..add(Variable<int>(cursor.id));
    }
    variables.add(
      Variable<int>(request.effectivePageSize + (exactLimit ? 0 : 1)),
    );
    final selectOcr = includeOcrText
        ? ', ocr_results.full_text AS ocr_full_text'
        : '';
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    return _database
        .customSelect(
          '''
      SELECT media_items.*$selectOcr
      FROM media_items
      ${joins.join('\n')}
      $where
      ORDER BY COALESCE(media_items.captured_at, media_items.imported_at) DESC,
        media_items.id DESC
      LIMIT ?
      ''',
          variables: variables,
          readsFrom: {
            _database.mediaItems,
            if (normalizedQuery != null) _database.ocrResults,
            if (request.tagIds.isNotEmpty) _database.mediaTags,
          },
        )
        .get();
  }

  @override
  Future<int> countMediaItems({Set<int> tagIds = const {}}) async {
    final variables = <Variable<Object>>[];
    final conditions = <String>[];
    for (final tagId in tagIds.toList()..sort()) {
      conditions.add(
        'EXISTS (SELECT 1 FROM media_tags '
        'WHERE media_tags.media_item_id = media_items.id '
        'AND media_tags.tag_id = ?)',
      );
      variables.add(Variable<int>(tagId));
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final row = await _database
        .customSelect(
          'SELECT COUNT(*) AS item_count FROM media_items $where',
          variables: variables,
          readsFrom: {
            _database.mediaItems,
            if (tagIds.isNotEmpty) _database.mediaTags,
          },
        )
        .getSingle();
    return row.read<int>('item_count');
  }

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

  domain.MediaItem _queryRowToDomain(QueryRow row) {
    return domain.MediaItem(
      id: row.read<int>('id'),
      location: domain.mediaItemLocationFromStorage(
        storageKind: row.read<String>('storage_kind'),
        privatePath: row.readNullable<String>('private_path'),
        internalName: row.readNullable<String>('internal_name'),
        sourceKey: row.readNullable<String>('source_key'),
        mediaStoreId: row.readNullable<int>('media_store_id'),
        volumeName: row.readNullable<String>('volume_name'),
        contentUri: row.readNullable<String>('content_uri'),
        sourceDateModified: row.readNullable<DateTime>('source_date_modified'),
      ),
      mimeType: row.readNullable<String>('mime_type'),
      mediaHash: row.readNullable<String>('media_hash'),
      importedAt: row.read<DateTime>('imported_at'),
      capturedAt: row.readNullable<DateTime>('captured_at'),
      sourceMode: row.read<String>('source_mode'),
      status: row.read<String>('status'),
      importOrigin: domain.ImportOrigin.fromDatabase(
        row.read<String>('import_origin'),
      ),
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

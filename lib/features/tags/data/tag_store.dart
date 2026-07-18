import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../../library/domain/media_item.dart' as media_domain;
import '../domain/tag.dart' as domain;

abstract interface class TagStore {
  Future<int> insertTag({
    required String name,
    required String normalizedName,
    required DateTime createdAt,
    required DateTime updatedAt,
  });

  Future<List<domain.Tag>> listTags();

  Future<List<domain.TagSummary>> listWithMediaCounts();

  Future<domain.Tag?> findById(int id);

  Future<domain.Tag?> findByNormalizedName(String normalizedName);

  Future<void> updateTag({
    required int id,
    required String name,
    required String normalizedName,
    required DateTime updatedAt,
  });

  Future<void> deleteTag(int id);

  Future<void> addToMedia({
    required int tagId,
    required int mediaItemId,
    required DateTime createdAt,
  });

  Future<void> removeFromMedia({required int tagId, required int mediaItemId});

  Future<bool> associationExists({
    required int tagId,
    required int mediaItemId,
  });

  Future<List<domain.Tag>> listForMedia(int mediaItemId);

  Future<List<media_domain.MediaItem>> listMediaForTag(int tagId);
}

class DriftTagStore implements TagStore {
  DriftTagStore(this._database);

  final ContextoDatabase _database;

  @override
  Future<int> insertTag({
    required String name,
    required String normalizedName,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return _database
        .into(_database.tags)
        .insert(
          TagsCompanion.insert(
            name: name,
            normalizedName: normalizedName,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );
  }

  @override
  Future<List<domain.Tag>> listTags() async {
    final rows =
        await (_database.select(_database.tags)..orderBy([
              (tag) => OrderingTerm.asc(tag.normalizedName),
              (tag) => OrderingTerm.asc(tag.id),
            ]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<domain.TagSummary>> listWithMediaCounts() async {
    final count = _database.mediaTags.mediaItemId.count();
    final query = _database.select(_database.tags).join([
      leftOuterJoin(
        _database.mediaTags,
        _database.mediaTags.tagId.equalsExp(_database.tags.id),
      ),
    ]);
    query
      ..addColumns([count])
      ..groupBy([_database.tags.id])
      ..orderBy([
        OrderingTerm.asc(_database.tags.normalizedName),
        OrderingTerm.asc(_database.tags.id),
      ]);
    final rows = await query.get();
    return rows
        .map(
          (row) => domain.TagSummary(
            tag: _toDomain(row.readTable(_database.tags)),
            mediaCount: row.read(count) ?? 0,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<domain.Tag?> findById(int id) async {
    final row = await (_database.select(
      _database.tags,
    )..where((tag) => tag.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<domain.Tag?> findByNormalizedName(String normalizedName) async {
    final row =
        await (_database.select(_database.tags)
              ..where((tag) => tag.normalizedName.equals(normalizedName)))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> updateTag({
    required int id,
    required String name,
    required String normalizedName,
    required DateTime updatedAt,
  }) async {
    await (_database.update(
      _database.tags,
    )..where((tag) => tag.id.equals(id))).write(
      TagsCompanion(
        name: Value(name),
        normalizedName: Value(normalizedName),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  @override
  Future<void> deleteTag(int id) async {
    await (_database.delete(
      _database.tags,
    )..where((tag) => tag.id.equals(id))).go();
  }

  @override
  Future<void> addToMedia({
    required int tagId,
    required int mediaItemId,
    required DateTime createdAt,
  }) async {
    await _database
        .into(_database.mediaTags)
        .insert(
          MediaTagsCompanion.insert(
            mediaItemId: mediaItemId,
            tagId: tagId,
            createdAt: createdAt,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<void> removeFromMedia({
    required int tagId,
    required int mediaItemId,
  }) async {
    await (_database.delete(_database.mediaTags)..where(
          (association) =>
              association.tagId.equals(tagId) &
              association.mediaItemId.equals(mediaItemId),
        ))
        .go();
  }

  @override
  Future<bool> associationExists({
    required int tagId,
    required int mediaItemId,
  }) async {
    final row =
        await (_database.select(_database.mediaTags)..where(
              (association) =>
                  association.tagId.equals(tagId) &
                  association.mediaItemId.equals(mediaItemId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  @override
  Future<List<domain.Tag>> listForMedia(int mediaItemId) async {
    final query = _database.select(_database.tags).join([
      innerJoin(
        _database.mediaTags,
        _database.mediaTags.tagId.equalsExp(_database.tags.id),
      ),
    ]);
    query
      ..where(_database.mediaTags.mediaItemId.equals(mediaItemId))
      ..orderBy([
        OrderingTerm.asc(_database.tags.normalizedName),
        OrderingTerm.asc(_database.tags.id),
      ]);
    final rows = await query.get();
    return rows
        .map((row) => _toDomain(row.readTable(_database.tags)))
        .toList(growable: false);
  }

  @override
  Future<List<media_domain.MediaItem>> listMediaForTag(int tagId) async {
    final query = _database.select(_database.mediaItems).join([
      innerJoin(
        _database.mediaTags,
        _database.mediaTags.mediaItemId.equalsExp(_database.mediaItems.id),
      ),
    ]);
    query
      ..where(_database.mediaTags.tagId.equals(tagId))
      ..orderBy([
        OrderingTerm.desc(
          const CustomExpression<DateTime>(
            'COALESCE(media_items.captured_at, media_items.imported_at)',
          ),
        ),
        OrderingTerm.desc(_database.mediaItems.importedAt),
        OrderingTerm.desc(_database.mediaItems.id),
      ]);
    final rows = await query.get();
    return rows
        .map((row) => _mediaToDomain(row.readTable(_database.mediaItems)))
        .toList(growable: false);
  }

  domain.Tag _toDomain(Tag row) {
    return domain.Tag(
      id: row.id,
      name: row.name,
      normalizedName: row.normalizedName,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  media_domain.MediaItem _mediaToDomain(MediaItem row) {
    return media_domain.MediaItem(
      id: row.id,
      privatePath: row.privatePath,
      internalName: row.internalName,
      mimeType: row.mimeType,
      mediaHash: row.mediaHash,
      importedAt: row.importedAt,
      capturedAt: row.capturedAt,
      sourceMode: row.sourceMode,
      status: row.status,
      importOrigin: media_domain.ImportOrigin.fromDatabase(row.importOrigin),
    );
  }
}

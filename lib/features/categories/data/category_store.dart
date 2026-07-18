import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../../library/domain/media_item.dart' as media_domain;
import '../domain/category.dart' as domain;

abstract interface class CategoryStore {
  Future<int> insertCategory({
    required String name,
    required String normalizedName,
    required DateTime createdAt,
  });

  Future<domain.Category?> findByNormalizedName(String normalizedName);

  Future<List<domain.CategorySummary>> listWithMediaCounts();

  Future<List<domain.Category>> listForMedia(int mediaItemId);

  Future<void> replaceForMedia(int mediaItemId, Set<int> categoryIds);

  Future<void> updateCategory({
    required int id,
    required String name,
    required String normalizedName,
  });

  Future<void> deleteCategory(int id);

  Future<List<media_domain.MediaItem>> listMediaForCategory(int categoryId);
}

class DriftCategoryStore implements CategoryStore {
  DriftCategoryStore(this._database);

  final ContextoDatabase _database;

  @override
  Future<int> insertCategory({
    required String name,
    required String normalizedName,
    required DateTime createdAt,
  }) {
    return _database
        .into(_database.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            normalizedName: normalizedName,
            createdAt: createdAt,
          ),
        );
  }

  @override
  Future<domain.Category?> findByNormalizedName(String normalizedName) async {
    final row =
        await (_database.select(_database.categories)..where(
              (category) => category.normalizedName.equals(normalizedName),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<domain.CategorySummary>> listWithMediaCounts() async {
    final count = _database.mediaCategories.mediaItemId.count();
    final query = _database.select(_database.categories).join([
      leftOuterJoin(
        _database.mediaCategories,
        _database.mediaCategories.categoryId.equalsExp(_database.categories.id),
      ),
    ]);
    query
      ..addColumns([count])
      ..groupBy([_database.categories.id])
      ..orderBy([
        OrderingTerm.asc(_database.categories.normalizedName),
        OrderingTerm.asc(_database.categories.id),
      ]);
    final rows = await query.get();
    return rows
        .map((row) {
          return domain.CategorySummary(
            category: _toDomain(row.readTable(_database.categories)),
            mediaCount: row.read(count) ?? 0,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<domain.Category>> listForMedia(int mediaItemId) async {
    final query = _database.select(_database.categories).join([
      innerJoin(
        _database.mediaCategories,
        _database.mediaCategories.categoryId.equalsExp(_database.categories.id),
      ),
    ]);
    query
      ..where(_database.mediaCategories.mediaItemId.equals(mediaItemId))
      ..orderBy([OrderingTerm.asc(_database.categories.normalizedName)]);
    final rows = await query.get();
    return rows
        .map((row) => _toDomain(row.readTable(_database.categories)))
        .toList(growable: false);
  }

  @override
  Future<void> replaceForMedia(int mediaItemId, Set<int> categoryIds) {
    return _database.transaction(() async {
      await (_database.delete(
        _database.mediaCategories,
      )..where((row) => row.mediaItemId.equals(mediaItemId))).go();
      final createdAt = DateTime.now();
      for (final categoryId in categoryIds) {
        await _database
            .into(_database.mediaCategories)
            .insert(
              MediaCategoriesCompanion.insert(
                mediaItemId: mediaItemId,
                categoryId: categoryId,
                createdAt: createdAt,
              ),
            );
      }
    });
  }

  @override
  Future<void> updateCategory({
    required int id,
    required String name,
    required String normalizedName,
  }) async {
    await (_database.update(
      _database.categories,
    )..where((category) => category.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(name),
        normalizedName: Value(normalizedName),
      ),
    );
  }

  @override
  Future<void> deleteCategory(int id) {
    return _database.transaction(() async {
      await (_database.delete(
        _database.categories,
      )..where((category) => category.id.equals(id))).go();
    });
  }

  @override
  Future<List<media_domain.MediaItem>> listMediaForCategory(
    int categoryId,
  ) async {
    final query = _database.select(_database.mediaItems).join([
      innerJoin(
        _database.mediaCategories,
        _database.mediaCategories.mediaItemId.equalsExp(
          _database.mediaItems.id,
        ),
      ),
    ]);
    query
      ..where(_database.mediaCategories.categoryId.equals(categoryId))
      ..orderBy([OrderingTerm.desc(_database.mediaItems.importedAt)]);
    final rows = await query.get();
    return rows
        .map((row) => _mediaToDomain(row.readTable(_database.mediaItems)))
        .toList(growable: false);
  }

  domain.Category _toDomain(Category row) {
    return domain.Category(
      id: row.id,
      name: row.name,
      normalizedName: row.normalizedName,
      createdAt: row.createdAt,
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
      sourceMode: row.sourceMode,
      status: row.status,
    );
  }
}

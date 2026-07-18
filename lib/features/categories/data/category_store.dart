import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../../library/domain/media_item.dart' as media_domain;
import '../domain/category.dart' as domain;

enum CategoryMoveStoreResult {
  moved,
  categoryNotFound,
  parentNotFound,
  selfParent,
  cycle,
  duplicate,
}

abstract interface class CategoryStore {
  Future<int> insertCategory({
    required String name,
    required String normalizedName,
    required DateTime createdAt,
    required int? parentId,
  });

  Future<domain.Category?> findByNormalizedName(
    String normalizedName, {
    required int? parentId,
  });

  Future<domain.Category?> findById(int id);

  Future<List<domain.Category>> listRoots();

  Future<List<domain.Category>> listChildren(int parentId);

  Future<List<domain.CategorySummary>> listWithMediaCounts();

  Future<List<domain.CategorySummary>> listSummariesByParent(int? parentId);

  Future<List<domain.Category>> listForMedia(int mediaItemId);

  Future<void> replaceForMedia(int mediaItemId, Set<int> categoryIds);

  Future<void> updateCategory({
    required int id,
    required String name,
    required String normalizedName,
  });

  Future<CategoryMoveStoreResult> moveCategory({
    required int id,
    required int? parentId,
  });

  Future<bool> hasChildren(int id);

  Future<bool> wouldCreateCycle({
    required int categoryId,
    required int parentId,
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
    required int? parentId,
  }) {
    return _database
        .into(_database.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            normalizedName: normalizedName,
            parentId: Value(parentId),
            createdAt: createdAt,
          ),
        );
  }

  @override
  Future<domain.Category?> findByNormalizedName(
    String normalizedName, {
    required int? parentId,
  }) async {
    final query = _database.select(_database.categories)
      ..where((category) => category.normalizedName.equals(normalizedName));
    query.where(
      (category) => parentId == null
          ? category.parentId.isNull()
          : category.parentId.equals(parentId),
    );
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<domain.Category?> findById(int id) async {
    final row = await (_database.select(
      _database.categories,
    )..where((category) => category.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<domain.Category>> listRoots() => _listByParent(null);

  @override
  Future<List<domain.Category>> listChildren(int parentId) =>
      _listByParent(parentId);

  Future<List<domain.Category>> _listByParent(int? parentId) async {
    final query = _database.select(_database.categories);
    query
      ..where(
        (category) => parentId == null
            ? category.parentId.isNull()
            : category.parentId.equals(parentId),
      )
      ..orderBy([
        (category) => OrderingTerm.asc(category.normalizedName),
        (category) => OrderingTerm.asc(category.id),
      ]);
    return (await query.get()).map(_toDomain).toList(growable: false);
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
  Future<List<domain.CategorySummary>> listSummariesByParent(
    int? parentId,
  ) async {
    final rows = await _database
        .customSelect(
          '''
      SELECT categories.*,
        (SELECT COUNT(*) FROM media_categories
          WHERE media_categories.category_id = categories.id) AS media_count,
        (SELECT COUNT(*) FROM categories AS children
          WHERE children.parent_id = categories.id) AS child_count
      FROM categories
      WHERE ${parentId == null ? 'categories.parent_id IS NULL' : 'categories.parent_id = ?'}
      ORDER BY categories.normalized_name, categories.id
      ''',
          variables: parentId == null ? const [] : [Variable<int>(parentId)],
          readsFrom: {_database.categories, _database.mediaCategories},
        )
        .get();
    return rows
        .map(
          (row) => domain.CategorySummary(
            category: domain.Category(
              id: row.read<int>('id'),
              name: row.read<String>('name'),
              normalizedName: row.read<String>('normalized_name'),
              createdAt: row.read<DateTime>('created_at'),
              parentId: row.readNullable<int>('parent_id'),
            ),
            mediaCount: row.read<int>('media_count'),
            childCount: row.read<int>('child_count'),
          ),
        )
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
      ..orderBy([
        OrderingTerm.asc(_database.categories.normalizedName),
        OrderingTerm.asc(_database.categories.id),
      ]);
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
  Future<CategoryMoveStoreResult> moveCategory({
    required int id,
    required int? parentId,
  }) {
    return _database.transaction(() async {
      final category = await findById(id);
      if (category == null) return CategoryMoveStoreResult.categoryNotFound;
      if (parentId == id) return CategoryMoveStoreResult.selfParent;
      if (parentId != null) {
        if (await findById(parentId) == null) {
          return CategoryMoveStoreResult.parentNotFound;
        }
        if (await wouldCreateCycle(categoryId: id, parentId: parentId)) {
          return CategoryMoveStoreResult.cycle;
        }
      }
      if (await findByNormalizedName(
            category.normalizedName,
            parentId: parentId,
          )
          case final conflict? when conflict.id != id) {
        return CategoryMoveStoreResult.duplicate;
      }
      try {
        await (_database.update(_database.categories)
              ..where((row) => row.id.equals(id)))
            .write(CategoriesCompanion(parentId: Value(parentId)));
      } catch (_) {
        final conflict = await findByNormalizedName(
          category.normalizedName,
          parentId: parentId,
        );
        if (conflict != null && conflict.id != id) {
          return CategoryMoveStoreResult.duplicate;
        }
        rethrow;
      }
      return CategoryMoveStoreResult.moved;
    });
  }

  @override
  Future<bool> hasChildren(int id) async {
    final child =
        await (_database.select(_database.categories)
              ..where((category) => category.parentId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    return child != null;
  }

  @override
  Future<bool> wouldCreateCycle({
    required int categoryId,
    required int parentId,
  }) async {
    final row = await _database
        .customSelect(
          '''
      WITH RECURSIVE descendants(id) AS (
        VALUES (?)
        UNION
        SELECT categories.id
        FROM categories
        JOIN descendants ON categories.parent_id = descendants.id
      )
      SELECT EXISTS(
        SELECT 1 FROM descendants WHERE id = ?
      ) AS creates_cycle
      ''',
          variables: [Variable<int>(categoryId), Variable<int>(parentId)],
          readsFrom: {_database.categories},
        )
        .getSingle();
    return row.read<int>('creates_cycle') != 0;
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

  domain.Category _toDomain(Category row) {
    return domain.Category(
      id: row.id,
      name: row.name,
      normalizedName: row.normalizedName,
      createdAt: row.createdAt,
      parentId: row.parentId,
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

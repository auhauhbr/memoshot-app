import 'dart:io';

import '../../../core/text/text_normalizer.dart';
import '../../library/domain/media_item.dart';
import '../../library/domain/media_page.dart';
import '../domain/category.dart';
import 'category_store.dart';

enum CategoryValidationError { empty, tooLong, duplicate }

class CategoryValidationException implements Exception {
  const CategoryValidationException(this.error);

  final CategoryValidationError error;
}

enum CategoryHierarchyError {
  categoryNotFound,
  parentNotFound,
  selfParent,
  cycle,
  hasChildren,
}

class CategoryHierarchyException implements Exception {
  const CategoryHierarchyException(this.error);

  final CategoryHierarchyError error;
}

abstract interface class CategoryRepository {
  Future<List<CategorySummary>> loadCategories();

  Future<Category> createCategory(String name);

  Future<Category> createRootCategory(String name);

  Future<Category> createSubcategory({
    required int parentId,
    required String name,
  });

  Future<List<Category>> loadRootCategories();

  Future<List<CategorySummary>> loadRootCategorySummaries();

  Future<List<Category>> loadChildCategories(int parentId);

  Future<List<CategorySummary>> loadChildCategorySummaries(int parentId);

  Future<Category?> findCategoryById(int id);

  Future<List<Category>> loadAncestors(int categoryId);

  Future<CategoryPath> loadPath(int categoryId);

  Future<List<Category>> loadDescendants(int categoryId);

  Future<Category> moveCategory(Category category, {required int? parentId});

  Future<bool> hasChildren(int categoryId);

  Future<bool> wouldCreateCycle({
    required int categoryId,
    required int? parentId,
  });

  Future<List<Category>> loadForMedia(int mediaItemId);

  Future<void> replaceForMedia(int mediaItemId, Set<int> categoryIds);

  Future<Category> renameCategory(Category category, String name);

  Future<void> deleteCategory(int categoryId);

  /// Carregamento completo legado. Não usar em pastas potencialmente grandes.
  Future<List<MediaItem>> loadMediaForCategory(int categoryId);
}

abstract interface class PagedCategoryRepository implements CategoryRepository {
  Future<MediaPage<MediaItem>> loadMediaPageByCategory(
    int categoryId, [
    MediaPageRequest request,
  ]);

  Future<int> countMediaItemsByCategory(int categoryId);
}

class LocalCategoryRepository implements PagedCategoryRepository {
  LocalCategoryRepository({
    required CategoryStore store,
    TextNormalizer normalizer = const TextNormalizer(),
  }) : this._(store, normalizer);

  LocalCategoryRepository._(this._store, this._normalizer);

  final CategoryStore _store;
  final TextNormalizer _normalizer;

  @override
  Future<MediaPage<MediaItem>> loadMediaPageByCategory(
    int categoryId, [
    MediaPageRequest request = const MediaPageRequest(),
  ]) async {
    await _requireCategory(categoryId);
    final store = _store;
    if (store is! PagedCategoryStore) {
      final all = await loadMediaForCategory(categoryId);
      final filtered = request.cursor == null
          ? all
          : all.where((item) {
              final cursor = request.cursor!;
              final comparison = item.effectiveCapturedAt.compareTo(
                cursor.capturedAt,
              );
              return comparison < 0 || (comparison == 0 && item.id < cursor.id);
            }).toList();
      final items = filtered.take(request.effectivePageSize).toList();
      return MediaPage(
        items: List.unmodifiable(items),
        nextCursor: filtered.length > items.length && items.isNotEmpty
            ? MediaPage.cursorFor(items.last)
            : null,
      );
    }
    final page = await store.listMediaPageForCategory(categoryId, request);
    final available = page.items
        .where((item) {
          final path = item.privatePath;
          return path == null || File(path).existsSync();
        })
        .toList(growable: false);
    return MediaPage(items: available, nextCursor: page.nextCursor);
  }

  @override
  Future<int> countMediaItemsByCategory(int categoryId) async {
    await _requireCategory(categoryId);
    final store = _store;
    if (store is PagedCategoryStore) {
      return store.countMediaForCategory(categoryId);
    }
    return (await loadMediaForCategory(categoryId)).length;
  }

  @override
  Future<List<CategorySummary>> loadCategories() {
    return _store.listWithMediaCounts();
  }

  @override
  Future<Category> createCategory(String name) async {
    return createRootCategory(name);
  }

  @override
  Future<Category> createRootCategory(String name) {
    return _createCategory(name: name, parentId: null);
  }

  @override
  Future<Category> createSubcategory({
    required int parentId,
    required String name,
  }) async {
    if (await _store.findById(parentId) == null) {
      throw const CategoryHierarchyException(
        CategoryHierarchyError.parentNotFound,
      );
    }
    return _createCategory(name: name, parentId: parentId);
  }

  Future<Category> _createCategory({
    required String name,
    required int? parentId,
  }) async {
    final visibleName = name.trim();
    final normalizedName = _normalizer.normalize(visibleName);
    if (normalizedName.isEmpty) {
      throw const CategoryValidationException(CategoryValidationError.empty);
    }
    if (visibleName.length > 40) {
      throw const CategoryValidationException(CategoryValidationError.tooLong);
    }
    if (await _store.findByNormalizedName(normalizedName, parentId: parentId) !=
        null) {
      throw const CategoryValidationException(
        CategoryValidationError.duplicate,
      );
    }

    final createdAt = DateTime.now();
    try {
      final id = await _store.insertCategory(
        name: visibleName,
        normalizedName: normalizedName,
        createdAt: createdAt,
        parentId: parentId,
      );
      return Category(
        id: id,
        name: visibleName,
        normalizedName: normalizedName,
        createdAt: createdAt,
        parentId: parentId,
      );
    } catch (_) {
      if (parentId != null && await _store.findById(parentId) == null) {
        throw const CategoryHierarchyException(
          CategoryHierarchyError.parentNotFound,
        );
      }
      if (await _store.findByNormalizedName(
            normalizedName,
            parentId: parentId,
          ) !=
          null) {
        throw const CategoryValidationException(
          CategoryValidationError.duplicate,
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<Category>> loadRootCategories() => _store.listRoots();

  @override
  Future<List<CategorySummary>> loadRootCategorySummaries() {
    return _store.listSummariesByParent(null);
  }

  @override
  Future<List<Category>> loadChildCategories(int parentId) async {
    if (await _store.findById(parentId) == null) {
      throw const CategoryHierarchyException(
        CategoryHierarchyError.parentNotFound,
      );
    }
    return _store.listChildren(parentId);
  }

  @override
  Future<List<CategorySummary>> loadChildCategorySummaries(int parentId) async {
    if (await _store.findById(parentId) == null) {
      throw const CategoryHierarchyException(
        CategoryHierarchyError.parentNotFound,
      );
    }
    return _store.listSummariesByParent(parentId);
  }

  @override
  Future<Category?> findCategoryById(int id) => _store.findById(id);

  @override
  Future<List<Category>> loadAncestors(int categoryId) async {
    final category = await _requireCategory(categoryId);
    final ancestors = <Category>[];
    final visited = <int>{category.id};
    var parentId = category.parentId;
    while (parentId != null) {
      if (!visited.add(parentId)) {
        throw const CategoryHierarchyException(CategoryHierarchyError.cycle);
      }
      final parent = await _store.findById(parentId);
      if (parent == null) {
        throw const CategoryHierarchyException(
          CategoryHierarchyError.parentNotFound,
        );
      }
      ancestors.add(parent);
      parentId = parent.parentId;
    }
    return ancestors.reversed.toList(growable: false);
  }

  @override
  Future<CategoryPath> loadPath(int categoryId) async {
    final category = await _requireCategory(categoryId);
    return CategoryPath([...await loadAncestors(categoryId), category]);
  }

  @override
  Future<List<Category>> loadDescendants(int categoryId) async {
    await _requireCategory(categoryId);
    final descendants = <Category>[];
    final visited = <int>{categoryId};
    final firstChildren = await _store.listChildren(categoryId);
    final pending = <Category>[...firstChildren.reversed];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (!visited.add(current.id)) {
        throw const CategoryHierarchyException(CategoryHierarchyError.cycle);
      }
      descendants.add(current);
      final children = await _store.listChildren(current.id);
      pending.addAll(children.reversed);
    }
    return descendants;
  }

  @override
  Future<Category> moveCategory(
    Category category, {
    required int? parentId,
  }) async {
    final result = await _store.moveCategory(
      id: category.id,
      parentId: parentId,
    );
    switch (result) {
      case CategoryMoveStoreResult.moved:
        final moved = await _store.findById(category.id);
        if (moved != null) return moved;
        throw const CategoryHierarchyException(
          CategoryHierarchyError.categoryNotFound,
        );
      case CategoryMoveStoreResult.categoryNotFound:
        throw const CategoryHierarchyException(
          CategoryHierarchyError.categoryNotFound,
        );
      case CategoryMoveStoreResult.parentNotFound:
        throw const CategoryHierarchyException(
          CategoryHierarchyError.parentNotFound,
        );
      case CategoryMoveStoreResult.selfParent:
        throw const CategoryHierarchyException(
          CategoryHierarchyError.selfParent,
        );
      case CategoryMoveStoreResult.cycle:
        throw const CategoryHierarchyException(CategoryHierarchyError.cycle);
      case CategoryMoveStoreResult.duplicate:
        throw const CategoryValidationException(
          CategoryValidationError.duplicate,
        );
    }
  }

  @override
  Future<bool> hasChildren(int categoryId) async {
    await _requireCategory(categoryId);
    return _store.hasChildren(categoryId);
  }

  @override
  Future<bool> wouldCreateCycle({
    required int categoryId,
    required int? parentId,
  }) async {
    await _requireCategory(categoryId);
    if (parentId == null) return false;
    if (await _store.findById(parentId) == null) {
      throw const CategoryHierarchyException(
        CategoryHierarchyError.parentNotFound,
      );
    }
    return _store.wouldCreateCycle(categoryId: categoryId, parentId: parentId);
  }

  @override
  Future<List<Category>> loadForMedia(int mediaItemId) {
    return _store.listForMedia(mediaItemId);
  }

  @override
  Future<void> replaceForMedia(int mediaItemId, Set<int> categoryIds) {
    return _store.replaceForMedia(mediaItemId, categoryIds);
  }

  @override
  Future<Category> renameCategory(Category category, String name) async {
    final current = await _requireCategory(category.id);
    final (visibleName, normalizedName) = _validateName(name);
    final existing = await _store.findByNormalizedName(
      normalizedName,
      parentId: current.parentId,
    );
    if (existing != null && existing.id != category.id) {
      throw const CategoryValidationException(
        CategoryValidationError.duplicate,
      );
    }
    try {
      await _store.updateCategory(
        id: category.id,
        name: visibleName,
        normalizedName: normalizedName,
      );
    } catch (_) {
      final conflict = await _store.findByNormalizedName(
        normalizedName,
        parentId: current.parentId,
      );
      if (conflict != null && conflict.id != category.id) {
        throw const CategoryValidationException(
          CategoryValidationError.duplicate,
        );
      }
      rethrow;
    }
    return Category(
      id: category.id,
      name: visibleName,
      normalizedName: normalizedName,
      createdAt: current.createdAt,
      parentId: current.parentId,
    );
  }

  @override
  Future<void> deleteCategory(int categoryId) async {
    await _requireCategory(categoryId);
    if (await _store.hasChildren(categoryId)) {
      throw const CategoryHierarchyException(
        CategoryHierarchyError.hasChildren,
      );
    }
    try {
      await _store.deleteCategory(categoryId);
    } catch (_) {
      if (await _store.hasChildren(categoryId)) {
        throw const CategoryHierarchyException(
          CategoryHierarchyError.hasChildren,
        );
      }
      rethrow;
    }
  }

  Future<Category> _requireCategory(int id) async {
    final category = await _store.findById(id);
    if (category == null) {
      throw const CategoryHierarchyException(
        CategoryHierarchyError.categoryNotFound,
      );
    }
    return category;
  }

  @override
  Future<List<MediaItem>> loadMediaForCategory(int categoryId) async {
    final items = await _store.listMediaForCategory(categoryId);
    return items
        .where((item) {
          final path = item.privatePath;
          return path == null || File(path).existsSync();
        })
        .toList(growable: false);
  }

  (String, String) _validateName(String name) {
    final visibleName = name.trim();
    final normalizedName = _normalizer.normalize(visibleName);
    if (normalizedName.isEmpty) {
      throw const CategoryValidationException(CategoryValidationError.empty);
    }
    if (visibleName.length > 40) {
      throw const CategoryValidationException(CategoryValidationError.tooLong);
    }
    return (visibleName, normalizedName);
  }
}

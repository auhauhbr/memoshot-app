import 'dart:io';

import '../../../core/text/text_normalizer.dart';
import '../../library/domain/media_item.dart';
import '../domain/category.dart';
import 'category_store.dart';

enum CategoryValidationError { empty, tooLong, duplicate }

class CategoryValidationException implements Exception {
  const CategoryValidationException(this.error);

  final CategoryValidationError error;
}

abstract interface class CategoryRepository {
  Future<List<CategorySummary>> loadCategories();

  Future<Category> createCategory(String name);

  Future<List<Category>> loadForMedia(int mediaItemId);

  Future<void> replaceForMedia(int mediaItemId, Set<int> categoryIds);

  Future<Category> renameCategory(Category category, String name);

  Future<void> deleteCategory(int categoryId);

  Future<List<MediaItem>> loadMediaForCategory(int categoryId);
}

class LocalCategoryRepository implements CategoryRepository {
  LocalCategoryRepository({
    required CategoryStore store,
    TextNormalizer normalizer = const TextNormalizer(),
  }) : this._(store, normalizer);

  LocalCategoryRepository._(this._store, this._normalizer);

  final CategoryStore _store;
  final TextNormalizer _normalizer;

  @override
  Future<List<CategorySummary>> loadCategories() {
    return _store.listWithMediaCounts();
  }

  @override
  Future<Category> createCategory(String name) async {
    final visibleName = name.trim();
    final normalizedName = _normalizer.normalize(visibleName);
    if (normalizedName.isEmpty) {
      throw const CategoryValidationException(CategoryValidationError.empty);
    }
    if (visibleName.length > 40) {
      throw const CategoryValidationException(CategoryValidationError.tooLong);
    }
    if (await _store.findByNormalizedName(normalizedName) != null) {
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
      );
      return Category(
        id: id,
        name: visibleName,
        normalizedName: normalizedName,
        createdAt: createdAt,
      );
    } catch (_) {
      if (await _store.findByNormalizedName(normalizedName) != null) {
        throw const CategoryValidationException(
          CategoryValidationError.duplicate,
        );
      }
      rethrow;
    }
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
    final (visibleName, normalizedName) = _validateName(name);
    final existing = await _store.findByNormalizedName(normalizedName);
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
      final conflict = await _store.findByNormalizedName(normalizedName);
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
      createdAt: category.createdAt,
    );
  }

  @override
  Future<void> deleteCategory(int categoryId) {
    return _store.deleteCategory(categoryId);
  }

  @override
  Future<List<MediaItem>> loadMediaForCategory(int categoryId) async {
    final items = await _store.listMediaForCategory(categoryId);
    return items
        .where((item) => File(item.privatePath).existsSync())
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

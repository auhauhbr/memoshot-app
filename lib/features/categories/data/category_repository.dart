import '../../../core/text/text_normalizer.dart';
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
}

import '../../../core/text/text_normalizer.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/domain/category.dart';
import '../../tags/data/tag_repository.dart';
import '../../tags/domain/tag.dart';
import '../domain/stored_classification_suggestion.dart';

enum ReviewDecisionType { confirm, reject }

class ReviewDecision {
  ReviewDecision.confirm({
    required this.mediaItemId,
    this.selectedCategoryId,
    Iterable<int> selectedTagIds = const [],
    Iterable<String> newTagNames = const [],
  }) : type = ReviewDecisionType.confirm,
       selectedTagIds = Set.unmodifiable(selectedTagIds),
       newTagNames = List.unmodifiable(newTagNames);

  const ReviewDecision.reject({required this.mediaItemId})
    : type = ReviewDecisionType.reject,
      selectedCategoryId = null,
      selectedTagIds = const {},
      newTagNames = const [];

  final int mediaItemId;
  final ReviewDecisionType type;
  final int? selectedCategoryId;
  final Set<int> selectedTagIds;
  final List<String> newTagNames;
}

enum ReviewDecisionFailure {
  suggestionNotFound,
  alreadyResolved,
  mediaNotFound,
  categoryNotFound,
  tagNotFound,
  invalidTag,
}

class ReviewDecisionException implements Exception {
  const ReviewDecisionException(this.failure);

  final ReviewDecisionFailure failure;
}

abstract interface class ReviewDecisionProcessor {
  Future<StoredClassificationSuggestion> resolve(ReviewDecision decision);
}

abstract interface class ReviewDecisionStore {
  Future<StoredClassificationSuggestion> resolve(
    ReviewDecision decision, {
    required DateTime resolvedAt,
  });
}

class LocalReviewDecisionProcessor implements ReviewDecisionProcessor {
  LocalReviewDecisionProcessor(this._store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ReviewDecisionStore _store;
  final DateTime Function() _now;

  @override
  Future<StoredClassificationSuggestion> resolve(ReviewDecision decision) {
    return _store.resolve(decision, resolvedAt: _now());
  }
}

class ReviewSelection {
  ReviewSelection({
    required this.selectedCategory,
    required Iterable<Tag> selectedTags,
    required Iterable<String> newTagNames,
  }) : selectedTags = List.unmodifiable(selectedTags),
       newTagNames = List.unmodifiable(newTagNames);

  final Category? selectedCategory;
  final List<Tag> selectedTags;
  final List<String> newTagNames;
}

class ReviewSelectionLoader {
  const ReviewSelectionLoader({
    required CategoryRepository categoryRepository,
    required TagRepository tagRepository,
    TextNormalizer normalizer = const TextNormalizer(),
  }) : this._(categoryRepository, tagRepository, normalizer);

  const ReviewSelectionLoader._(
    this._categoryRepository,
    this._tagRepository,
    this._normalizer,
  );

  final CategoryRepository _categoryRepository;
  final TagRepository _tagRepository;
  final TextNormalizer _normalizer;

  Future<ReviewSelection> load(
    StoredClassificationSuggestion suggestion,
  ) async {
    final values = await Future.wait<Object>([
      _categoryRepository.loadRootCategories(),
      _tagRepository.loadTags(),
    ]);
    final roots = values[0] as List<Category>;
    final tags = values[1] as List<Tag>;
    final categoryName = suggestion.suggestedCategoryName;
    Category? selectedCategory;
    if (categoryName != null) {
      final normalized = _normalizer.normalize(categoryName);
      final matches = roots.where(
        (category) => category.normalizedName == normalized,
      );
      if (matches.length == 1) selectedCategory = matches.single;
    }

    final tagsByName = {for (final tag in tags) tag.normalizedName: tag};
    final selectedTags = <Tag>[];
    final newTagNames = <String>[];
    final selectedNames = <String>{};
    for (final suggested in suggestion.suggestedTags) {
      final normalized = _normalizer.normalize(suggested.name);
      if (normalized.isEmpty || !selectedNames.add(normalized)) continue;
      final existing = tagsByName[normalized];
      if (existing == null) {
        newTagNames.add(suggested.name.trim());
      } else {
        selectedTags.add(existing);
      }
    }
    return ReviewSelection(
      selectedCategory: selectedCategory,
      selectedTags: selectedTags,
      newTagNames: newTagNames,
    );
  }
}

import '../../../core/text/text_normalizer.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/domain/category.dart';
import '../domain/local_classification_engine.dart';
import '../domain/stored_classification_suggestion.dart';
import 'review_decision.dart';

const automaticClassificationConfidenceThreshold = 0.85;

class AutoClassificationPolicy {
  const AutoClassificationPolicy({
    this.minimumConfidence = automaticClassificationConfidenceThreshold,
    this.normalizer = const TextNormalizer(),
  });

  final double minimumConfidence;
  final TextNormalizer normalizer;

  Category? eligibleRoot({
    required StoredClassificationSuggestion suggestion,
    required Iterable<Category> rootCategories,
    bool mediaItemExists = true,
  }) {
    if (!mediaItemExists ||
        suggestion.status != ClassificationSuggestionStatus.pendingReview ||
        !suggestion.hasSuggestion ||
        suggestion.suggestedCategoryName == null ||
        suggestion.confidence < minimumConfidence ||
        suggestion.reviewReason != ClassificationReviewReason.manualReview) {
      return null;
    }
    final normalized = normalizer.normalize(suggestion.suggestedCategoryName!);
    if (normalized.isEmpty) return null;
    final matches = rootCategories.where(
      (category) =>
          category.parentId == null && category.normalizedName == normalized,
    );
    return matches.length == 1 ? matches.single : null;
  }
}

abstract interface class AutomaticClassificationApplier {
  Future<StoredClassificationSuggestion> apply(
    StoredClassificationSuggestion suggestion,
  );
}

class LocalAutomaticClassificationApplier
    implements AutomaticClassificationApplier {
  LocalAutomaticClassificationApplier({
    required CategoryRepository categoryRepository,
    required ReviewDecisionStore store,
    AutoClassificationPolicy policy = const AutoClassificationPolicy(),
    DateTime Function()? now,
  }) : this._(categoryRepository, store, policy, now ?? DateTime.now);

  LocalAutomaticClassificationApplier._(
    this._categoryRepository,
    this._store,
    this._policy,
    this._now,
  );

  final CategoryRepository _categoryRepository;
  final ReviewDecisionStore _store;
  final AutoClassificationPolicy _policy;
  final DateTime Function() _now;

  @override
  Future<StoredClassificationSuggestion> apply(
    StoredClassificationSuggestion suggestion,
  ) async {
    final roots = await _categoryRepository.loadRootCategories();
    final category = _policy.eligibleRoot(
      suggestion: suggestion,
      rootCategories: roots,
    );
    if (category == null) return suggestion;
    final safeTagNames = suggestion.suggestedTags
        .map((tag) => tag.name)
        .where(LocalClassificationTagCatalog.contains)
        .toSet();
    return _store.autoApply(
      mediaItemId: suggestion.mediaItemId,
      expectedCategoryId: category.id,
      safeTagNames: safeTagNames,
      resolvedAt: _now(),
    );
  }
}

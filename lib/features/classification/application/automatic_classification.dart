import '../../../core/text/text_normalizer.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/domain/category.dart';
import '../domain/local_classification_engine.dart';
import '../domain/stored_classification_suggestion.dart';
import 'review_decision.dart';

const existingRootAutomaticClassificationConfidenceThreshold = 0.85;
const newRootAutomaticClassificationConfidenceThreshold = 0.90;
const minimumIndependentCategoryEvidenceForAutomaticRoot = 2;

enum AutoClassificationPlanType { useExistingRoot, createSafeRoot }

class AutoClassificationPlan {
  const AutoClassificationPlan._({
    required this.type,
    required this.officialCategoryName,
    this.existingRoot,
  });

  const AutoClassificationPlan.useExisting({
    required String officialCategoryName,
    required Category root,
  }) : this._(
         type: AutoClassificationPlanType.useExistingRoot,
         officialCategoryName: officialCategoryName,
         existingRoot: root,
       );

  const AutoClassificationPlan.create({required String officialCategoryName})
    : this._(
        type: AutoClassificationPlanType.createSafeRoot,
        officialCategoryName: officialCategoryName,
      );

  final AutoClassificationPlanType type;
  final String officialCategoryName;
  final Category? existingRoot;
}

class AutoClassificationPolicy {
  const AutoClassificationPolicy({
    this.existingRootMinimumConfidence =
        existingRootAutomaticClassificationConfidenceThreshold,
    this.newRootMinimumConfidence =
        newRootAutomaticClassificationConfidenceThreshold,
    this.normalizer = const TextNormalizer(),
  });

  final double existingRootMinimumConfidence;
  final double newRootMinimumConfidence;
  final TextNormalizer normalizer;

  AutoClassificationPlan? plan({
    required StoredClassificationSuggestion suggestion,
    required Iterable<Category> rootCategories,
    bool mediaItemExists = true,
  }) {
    final suggestedName = suggestion.suggestedCategoryName;
    if (!mediaItemExists ||
        suggestion.status != ClassificationSuggestionStatus.pendingReview ||
        !suggestion.hasSuggestion ||
        suggestedName == null ||
        suggestion.reviewReason != ClassificationReviewReason.manualReview) {
      return null;
    }
    final definition = LocalClassificationCategoryCatalog.definitionFor(
      suggestedName,
    );
    if (definition == null) return null;

    final normalized = normalizer.normalize(definition.name);
    final matches = rootCategories
        .where(
          (category) =>
              category.parentId == null &&
              category.normalizedName == normalized,
        )
        .toList(growable: false);
    if (matches.length > 1) return null;
    if (matches.length == 1) {
      if (suggestion.confidence < existingRootMinimumConfidence) return null;
      return AutoClassificationPlan.useExisting(
        officialCategoryName: definition.name,
        root: matches.single,
      );
    }
    if (suggestion.confidence < newRootMinimumConfidence ||
        !_hasIndependentCategoryEvidence(suggestion, definition.ruleId)) {
      return null;
    }
    return AutoClassificationPlan.create(officialCategoryName: definition.name);
  }

  Category? eligibleRoot({
    required StoredClassificationSuggestion suggestion,
    required Iterable<Category> rootCategories,
    bool mediaItemExists = true,
  }) {
    final result = plan(
      suggestion: suggestion,
      rootCategories: rootCategories,
      mediaItemExists: mediaItemExists,
    );
    return result?.type == AutoClassificationPlanType.useExistingRoot
        ? result!.existingRoot
        : null;
  }

  bool _hasIndependentCategoryEvidence(
    StoredClassificationSuggestion suggestion,
    String categoryRuleId,
  ) {
    final prefix = 'category.$categoryRuleId.';
    final distinctRuleIds = <String>{
      for (final evidence in suggestion.evidence)
        if (evidence.ruleId.startsWith(prefix)) evidence.ruleId,
    };
    return distinctRuleIds.length >=
        minimumIndependentCategoryEvidenceForAutomaticRoot;
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
    final plan = _policy.plan(suggestion: suggestion, rootCategories: roots);
    if (plan == null) return suggestion;
    final safeTagNames = suggestion.suggestedTags
        .map((tag) => tag.name)
        .where(LocalClassificationTagCatalog.contains)
        .toSet();
    return _store.autoApply(
      mediaItemId: suggestion.mediaItemId,
      expectedCategoryId: plan.existingRoot?.id,
      officialCategoryName: plan.officialCategoryName,
      allowSafeRootCreation:
          plan.type == AutoClassificationPlanType.createSafeRoot,
      safeTagNames: safeTagNames,
      resolvedAt: _now(),
    );
  }
}

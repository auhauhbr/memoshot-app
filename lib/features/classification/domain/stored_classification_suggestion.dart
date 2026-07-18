import 'classification_models.dart';

const currentClassificationEngineVersion = 1;

enum ClassificationSuggestionStatus {
  pendingReview,
  accepted,
  rejected,
  autoApplied,
}

enum ClassificationReviewReason {
  lowConfidence,
  ambiguous,
  noCategory,
  noSuggestion,
  manualReview,
}

class StoredClassificationSuggestion {
  StoredClassificationSuggestion({
    required this.mediaItemId,
    required this.suggestedCategoryName,
    required double confidence,
    required this.hasSuggestion,
    required List<SuggestedTag> suggestedTags,
    required List<ClassificationEvidence> evidence,
    required this.status,
    required this.reviewReason,
    required this.engineVersion,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  }) : confidence = confidence.clamp(0, 1).toDouble(),
       suggestedTags = List.unmodifiable(suggestedTags),
       evidence = List.unmodifiable(evidence);

  factory StoredClassificationSuggestion.fromEngine({
    required int mediaItemId,
    required ClassificationSuggestion suggestion,
    required ClassificationReviewReason? reviewReason,
    required DateTime createdAt,
    int engineVersion = currentClassificationEngineVersion,
  }) {
    return StoredClassificationSuggestion(
      mediaItemId: mediaItemId,
      suggestedCategoryName: suggestion.suggestedCategoryName,
      confidence: suggestion.confidence,
      hasSuggestion: suggestion.hasSuggestion,
      suggestedTags: suggestion.suggestedTags,
      evidence: suggestion.evidence,
      status: ClassificationSuggestionStatus.pendingReview,
      reviewReason: reviewReason,
      engineVersion: engineVersion,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  final int mediaItemId;
  final String? suggestedCategoryName;
  final double confidence;
  final bool hasSuggestion;
  final List<SuggestedTag> suggestedTags;
  final List<ClassificationEvidence> evidence;
  final ClassificationSuggestionStatus status;
  final ClassificationReviewReason? reviewReason;
  final int engineVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  StoredClassificationSuggestion copyWith({
    ClassificationSuggestionStatus? status,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    bool clearResolvedAt = false,
  }) {
    return StoredClassificationSuggestion(
      mediaItemId: mediaItemId,
      suggestedCategoryName: suggestedCategoryName,
      confidence: confidence,
      hasSuggestion: hasSuggestion,
      suggestedTags: suggestedTags,
      evidence: evidence,
      status: status ?? this.status,
      reviewReason: reviewReason,
      engineVersion: engineVersion,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: clearResolvedAt ? null : (resolvedAt ?? this.resolvedAt),
    );
  }
}

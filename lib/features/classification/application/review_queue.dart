import '../../library/data/media_item_repository.dart';
import '../../library/domain/media_item.dart';
import '../data/classification_suggestion_repository.dart';
import '../domain/stored_classification_suggestion.dart';

class ReviewQueueItem {
  const ReviewQueueItem({required this.mediaItem, required this.suggestion});

  final MediaItem mediaItem;
  final StoredClassificationSuggestion suggestion;

  String get categoryLabel => suggestion.suggestedCategoryName == null
      ? 'Pasta ainda não identificada'
      : 'Pasta sugerida: ${suggestion.suggestedCategoryName}';

  List<String> get tagNames =>
      suggestion.suggestedTags.map((tag) => tag.name).toList(growable: false);

  String get confidenceLabel =>
      'Confiança das regras: ${(suggestion.confidence * 100).round()}%';

  String get reviewReasonLabel => switch (suggestion.reviewReason) {
    ClassificationReviewReason.lowConfidence =>
      'Classificação com baixa confiança',
    ClassificationReviewReason.ambiguous =>
      'Há mais de uma classificação possível',
    ClassificationReviewReason.noCategory =>
      'Não foi possível determinar uma pasta',
    ClassificationReviewReason.noSuggestion =>
      'Não foi possível classificar este print',
    ClassificationReviewReason.manualReview =>
      'Confirme a organização sugerida',
    null => 'Confirme a organização sugerida',
  };
}

class ReviewQueueLoader {
  const ReviewQueueLoader({
    required ClassificationSuggestionRepository suggestionRepository,
    required MediaItemRepository mediaRepository,
  }) : this._(suggestionRepository, mediaRepository);

  const ReviewQueueLoader._(this._suggestionRepository, this._mediaRepository);

  final ClassificationSuggestionRepository _suggestionRepository;
  final MediaItemRepository _mediaRepository;

  Future<List<ReviewQueueItem>> loadPending() async {
    final values = await Future.wait<Object>([
      _suggestionRepository.loadPendingReview(),
      _mediaRepository.loadAvailableItems(),
    ]);
    final suggestions = values[0] as List<StoredClassificationSuggestion>;
    final mediaItems = values[1] as List<MediaItem>;
    final mediaById = {for (final item in mediaItems) item.id: item};
    return suggestions
        .map((suggestion) {
          final mediaItem = mediaById[suggestion.mediaItemId];
          return mediaItem == null
              ? null
              : ReviewQueueItem(mediaItem: mediaItem, suggestion: suggestion);
        })
        .whereType<ReviewQueueItem>()
        .toList(growable: false);
  }
}

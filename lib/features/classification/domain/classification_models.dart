class ClassificationInput {
  const ClassificationInput({
    required this.ocrText,
    this.sourceMimeType,
    this.capturedAt,
    this.originalFileName,
  });

  final String ocrText;
  final String? sourceMimeType;
  final DateTime? capturedAt;
  final String? originalFileName;

  @override
  bool operator ==(Object other) {
    return other is ClassificationInput &&
        other.ocrText == ocrText &&
        other.sourceMimeType == sourceMimeType &&
        other.capturedAt == capturedAt &&
        other.originalFileName == originalFileName;
  }

  @override
  int get hashCode =>
      Object.hash(ocrText, sourceMimeType, capturedAt, originalFileName);
}

enum ClassificationEvidenceType { keyword, pattern, metadata }

class ClassificationEvidence {
  ClassificationEvidence({
    required this.ruleId,
    required this.type,
    required this.description,
    required double weight,
    this.safeMatch,
    this.position,
    this.count,
  }) : weight = _boundedConfidence(weight);

  final String ruleId;
  final ClassificationEvidenceType type;
  final String description;
  final double weight;

  /// Somente termos fixos do catálogo podem ser expostos aqui.
  /// Valores encontrados por padrões sensíveis permanecem ausentes.
  final String? safeMatch;
  final int? position;
  final int? count;

  @override
  bool operator ==(Object other) {
    return other is ClassificationEvidence &&
        other.ruleId == ruleId &&
        other.type == type &&
        other.description == description &&
        other.weight == weight &&
        other.safeMatch == safeMatch &&
        other.position == position &&
        other.count == count;
  }

  @override
  int get hashCode => Object.hash(
    ruleId,
    type,
    description,
    weight,
    safeMatch,
    position,
    count,
  );
}

class SuggestedTag {
  SuggestedTag({
    required this.name,
    required double confidence,
    required List<ClassificationEvidence> evidence,
  }) : confidence = _boundedConfidence(confidence),
       evidence = List.unmodifiable(evidence);

  final String name;
  final double confidence;
  final List<ClassificationEvidence> evidence;

  @override
  bool operator ==(Object other) {
    return other is SuggestedTag &&
        other.name == name &&
        other.confidence == confidence &&
        _listEquals(other.evidence, evidence);
  }

  @override
  int get hashCode => Object.hash(name, confidence, Object.hashAll(evidence));
}

class ClassificationSuggestion {
  ClassificationSuggestion({
    required this.suggestedCategoryName,
    required List<SuggestedTag> suggestedTags,
    required double confidence,
    required List<ClassificationEvidence> evidence,
  }) : suggestedTags = List.unmodifiable(suggestedTags),
       confidence = _boundedConfidence(confidence),
       evidence = List.unmodifiable(evidence);

  factory ClassificationSuggestion.empty() => ClassificationSuggestion(
    suggestedCategoryName: null,
    suggestedTags: const [],
    confidence: 0,
    evidence: const [],
  );

  final String? suggestedCategoryName;
  final List<SuggestedTag> suggestedTags;

  /// Força das regras locais; não representa precisão estatística.
  final double confidence;
  final List<ClassificationEvidence> evidence;

  bool get hasSuggestion =>
      suggestedCategoryName != null || suggestedTags.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is ClassificationSuggestion &&
        other.suggestedCategoryName == suggestedCategoryName &&
        other.confidence == confidence &&
        _listEquals(other.suggestedTags, suggestedTags) &&
        _listEquals(other.evidence, evidence);
  }

  @override
  int get hashCode => Object.hash(
    suggestedCategoryName,
    Object.hashAll(suggestedTags),
    confidence,
    Object.hashAll(evidence),
  );
}

double _boundedConfidence(double value) => value.clamp(0, 1).toDouble();

bool _listEquals<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

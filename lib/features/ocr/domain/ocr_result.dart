import '../../../core/text/text_normalizer.dart';

class OcrResult {
  OcrResult({
    required this.mediaItemId,
    required this.fullText,
    required this.engine,
    required this.engineVersion,
    required this.processedAt,
    String? normalizedText,
  }) : normalizedText =
           normalizedText ?? const TextNormalizer().normalize(fullText);

  final int mediaItemId;
  final String fullText;
  final String normalizedText;
  final String engine;
  final String engineVersion;
  final DateTime processedAt;
}

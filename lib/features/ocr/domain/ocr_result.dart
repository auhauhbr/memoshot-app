class OcrResult {
  const OcrResult({
    required this.mediaItemId,
    required this.fullText,
    required this.engine,
    required this.engineVersion,
    required this.processedAt,
  });

  final int mediaItemId;
  final String fullText;
  final String engine;
  final String engineVersion;
  final DateTime processedAt;
}

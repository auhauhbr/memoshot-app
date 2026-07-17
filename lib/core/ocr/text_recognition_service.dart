class TextRecognitionOutput {
  const TextRecognitionOutput({
    required this.fullText,
    required this.engine,
    required this.engineVersion,
  });

  final String fullText;
  final String engine;
  final String engineVersion;
}

abstract interface class TextRecognitionService {
  Future<TextRecognitionOutput> recognize(String imagePath);
}

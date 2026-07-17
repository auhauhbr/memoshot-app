import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'text_recognition_service.dart';

class MlKitTextRecognitionService implements TextRecognitionService {
  const MlKitTextRecognitionService();

  @override
  Future<TextRecognitionOutput> recognize(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);
      return TextRecognitionOutput(
        fullText: recognized.text,
        engine: 'Google ML Kit Text Recognition',
        engineVersion: '16.0.1',
      );
    } finally {
      await recognizer.close();
    }
  }
}

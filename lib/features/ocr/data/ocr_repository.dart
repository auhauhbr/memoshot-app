import 'dart:io';

import '../../../core/ocr/text_recognition_service.dart';
import '../../library/domain/media_item.dart';
import '../domain/ocr_result.dart';
import 'ocr_result_store.dart';

abstract interface class OcrRepository {
  Future<OcrResult?> loadFor(int mediaItemId);

  Future<OcrResult> process(MediaItem mediaItem);
}

class LocalOcrRepository implements OcrRepository {
  LocalOcrRepository({
    required OcrResultStore store,
    required TextRecognitionService recognitionService,
  }) : this._(store, recognitionService);

  LocalOcrRepository._(this._store, this._recognitionService);

  final OcrResultStore _store;
  final TextRecognitionService _recognitionService;

  @override
  Future<OcrResult?> loadFor(int mediaItemId) {
    return _store.findByMediaItemId(mediaItemId);
  }

  @override
  Future<OcrResult> process(MediaItem mediaItem) async {
    if (!await File(mediaItem.privatePath).exists()) {
      throw const FileSystemException('Imagem privada indisponível.');
    }

    final output = await _recognitionService.recognize(mediaItem.privatePath);
    final result = OcrResult(
      mediaItemId: mediaItem.id,
      fullText: output.fullText,
      engine: output.engine,
      engineVersion: output.engineVersion,
      processedAt: DateTime.now(),
    );
    await _store.save(result);
    return result;
  }
}

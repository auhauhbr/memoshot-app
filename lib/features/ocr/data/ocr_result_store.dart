import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../../../core/text/text_normalizer.dart';
import '../domain/ocr_result.dart' as domain;

abstract interface class OcrResultStore {
  Future<domain.OcrResult?> findByMediaItemId(int mediaItemId);

  Future<void> save(domain.OcrResult result);
}

class DriftOcrResultStore implements OcrResultStore {
  DriftOcrResultStore(
    ContextoDatabase database, {
    TextNormalizer normalizer = const TextNormalizer(),
  }) : this._(database, normalizer);

  DriftOcrResultStore._(this._database, this._normalizer);

  final ContextoDatabase _database;
  final TextNormalizer _normalizer;

  @override
  Future<domain.OcrResult?> findByMediaItemId(int mediaItemId) async {
    final row =
        await (_database.select(_database.ocrResults)
              ..where((result) => result.mediaItemId.equals(mediaItemId)))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return domain.OcrResult(
      mediaItemId: row.mediaItemId,
      fullText: row.fullText,
      normalizedText: row.normalizedText,
      engine: row.engine,
      engineVersion: row.engineVersion,
      processedAt: row.processedAt,
    );
  }

  @override
  Future<void> save(domain.OcrResult result) {
    return _database
        .into(_database.ocrResults)
        .insertOnConflictUpdate(
          OcrResultsCompanion.insert(
            mediaItemId: Value(result.mediaItemId),
            fullText: result.fullText,
            normalizedText: Value(_normalizer.normalize(result.fullText)),
            engine: result.engine,
            engineVersion: result.engineVersion,
            processedAt: result.processedAt,
          ),
        );
  }
}

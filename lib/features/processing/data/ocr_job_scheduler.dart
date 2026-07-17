import 'processing_job_store.dart';

abstract interface class OcrJobScheduler {
  Future<bool> schedule(int mediaItemId);
}

class LocalOcrJobScheduler implements OcrJobScheduler {
  const LocalOcrJobScheduler(this._store);

  final ProcessingJobStore _store;

  @override
  Future<bool> schedule(int mediaItemId) {
    return _store.createOcrJobIfNeeded(mediaItemId);
  }
}

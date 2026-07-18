import 'dart:async';

import '../../core/sharing/incoming_share_source.dart';
import '../library/data/media_item_repository.dart';
import '../library/domain/media_item.dart';
import '../library/domain/selected_screenshot.dart';

typedef SharedImportCallback = FutureOr<void> Function(ImportResult result);
typedef SharedImportErrorCallback = FutureOr<void> Function();

class SharedImageImportCoordinator {
  SharedImageImportCoordinator({
    required IncomingShareSource source,
    required MediaItemRepository repository,
    required SharedImportCallback onCompleted,
    required SharedImportErrorCallback onError,
  }) : this._(source, repository, onCompleted, onError);

  SharedImageImportCoordinator._(
    this._source,
    this._repository,
    this._onCompleted,
    this._onError,
  );

  final IncomingShareSource _source;
  final MediaItemRepository _repository;
  final SharedImportCallback _onCompleted;
  final SharedImportErrorCallback _onError;
  final Set<String> _activeBatches = {};
  StreamSubscription<List<IncomingSharedMedia>>? _subscription;
  Future<void> _tail = Future.value();
  bool _disposed = false;

  Future<void> start() async {
    if (_subscription != null || _disposed) return;
    try {
      _subscription = _source.mediaStream.listen(
        _enqueue,
        onError: (_) => _onError(),
      );
      final initial = await _source.getInitialMedia();
      _enqueue(initial);
    } catch (_) {
      await _onError();
    }
  }

  void _enqueue(List<IncomingSharedMedia> batch) {
    if (_disposed || batch.isEmpty) return;
    final fingerprint = batch
        .map((item) => '${item.type.name}:${item.path}')
        .join('\u0000');
    if (!_activeBatches.add(fingerprint)) return;
    _tail = _tail.then((_) => _process(batch, fingerprint));
  }

  Future<void> _process(
    List<IncomingSharedMedia> batch,
    String fingerprint,
  ) async {
    final images = batch
        .where((item) => item.type == IncomingMediaType.image)
        .map(
          (item) =>
              SelectedScreenshot(path: item.path, mimeType: item.mimeType),
        )
        .toList(growable: false);
    try {
      final result = images.isEmpty
          ? const ImportResult(
              importedItems: [],
              duplicateCount: 0,
              rejectedCount: 0,
            )
          : await _repository.importScreenshots(
              images,
              origin: ImportOrigin.shared,
            );
      if (!_disposed) await _onCompleted(result);
    } catch (_) {
      if (!_disposed) await _onError();
    } finally {
      try {
        await _source.reset();
      } catch (_) {
        if (!_disposed) await _onError();
      }
      _activeBatches.remove(fingerprint);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    await _tail;
  }
}

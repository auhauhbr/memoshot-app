import 'dart:io';

import '../../../core/media/screenshot_storage.dart';
import '../domain/media_item.dart';
import '../domain/selected_screenshot.dart';
import 'media_item_store.dart';

abstract interface class MediaItemRepository {
  Future<List<MediaItem>> loadAvailableItems();

  Future<List<MediaItem>> importScreenshots(
    List<SelectedScreenshot> screenshots,
  );

  Future<void> close();
}

class LocalMediaItemRepository implements MediaItemRepository {
  LocalMediaItemRepository({
    required MediaItemStore store,
    required ScreenshotStorage storage,
  }) : this._(store, storage);

  LocalMediaItemRepository._(this._store, this._storage);

  final MediaItemStore _store;
  final ScreenshotStorage _storage;

  @override
  Future<List<MediaItem>> loadAvailableItems() async {
    final items = await _store.readItems();
    final available = <MediaItem>[];
    for (final item in items) {
      if (await File(item.privatePath).exists()) {
        available.add(item);
      }
    }
    return available;
  }

  @override
  Future<List<MediaItem>> importScreenshots(
    List<SelectedScreenshot> screenshots,
  ) async {
    final imported = <MediaItem>[];
    for (final screenshot in screenshots) {
      final copy = await _storage.copyToPrivate(screenshot.path);
      final importedAt = DateTime.now();
      try {
        final id = await _store.insertItem(
          privatePath: copy.privatePath,
          internalName: copy.internalName,
          mimeType: screenshot.mimeType,
          importedAt: importedAt,
          sourceMode: 'photoPicker',
          status: 'ready',
        );
        imported.add(
          MediaItem(
            id: id,
            privatePath: copy.privatePath,
            internalName: copy.internalName,
            mimeType: screenshot.mimeType,
            importedAt: importedAt,
            sourceMode: 'photoPicker',
            status: 'ready',
          ),
        );
      } catch (_) {
        await _storage.deletePrivateCopy(copy.privatePath);
        rethrow;
      }
    }
    return imported;
  }

  @override
  Future<void> close() => _store.close();
}

import 'dart:io';

import '../../../core/media/file_hash_calculator.dart';
import '../../../core/media/screenshot_storage.dart';
import '../../../core/text/search_snippet_builder.dart';
import '../../../core/text/text_normalizer.dart';
import '../domain/media_item.dart';
import '../domain/selected_screenshot.dart';
import '../domain/screenshot_search_result.dart';
import '../../processing/data/ocr_job_scheduler.dart';
import 'media_item_store.dart';

class ImportResult {
  const ImportResult({
    required this.importedItems,
    required this.duplicateCount,
    this.rejectedCount = 0,
  });

  final List<MediaItem> importedItems;
  final int duplicateCount;
  final int rejectedCount;
}

abstract interface class MediaItemRepository {
  Future<List<MediaItem>> loadAvailableItems({int? tagId});

  Future<MediaItem?> loadById(int mediaItemId);

  Future<ImportResult> importScreenshots(
    List<SelectedScreenshot> screenshots, {
    ImportOrigin origin = ImportOrigin.picker,
  });

  Future<void> removeItem(MediaItem item);

  Future<List<ScreenshotSearchResult>> searchRecognizedText(
    String query, {
    int? tagId,
    int limit = 100,
  });

  Future<void> close();
}

abstract interface class MediaStoreReferenceMediaItemRepository
    implements MediaItemRepository {
  Future<MediaItem?> loadBySourceKey(String sourceKey);

  Future<MediaItem> createMediaStoreReference({
    required MediaStoreReferenceLocation location,
    required String? mimeType,
    required DateTime? capturedAt,
    DateTime? importedAt,
  });
}

class LocalMediaItemRepository
    implements MediaStoreReferenceMediaItemRepository {
  LocalMediaItemRepository({
    required MediaItemStore store,
    required ScreenshotStorage storage,
    FileHashCalculator hashCalculator = const Sha256FileHashCalculator(),
    OcrJobScheduler? ocrJobScheduler,
    TextNormalizer normalizer = const TextNormalizer(),
    SearchSnippetBuilder snippetBuilder = const SearchSnippetBuilder(),
  }) : this._(
         store,
         storage,
         hashCalculator,
         ocrJobScheduler,
         normalizer,
         snippetBuilder,
       );

  LocalMediaItemRepository._(
    this._store,
    this._storage,
    this._hashCalculator,
    this._ocrJobScheduler,
    this._normalizer,
    this._snippetBuilder,
  );

  final MediaItemStore _store;
  final ScreenshotStorage _storage;
  final FileHashCalculator _hashCalculator;
  final OcrJobScheduler? _ocrJobScheduler;
  final TextNormalizer _normalizer;
  final SearchSnippetBuilder _snippetBuilder;

  @override
  Future<List<MediaItem>> loadAvailableItems({int? tagId}) async {
    await _repairLibrary();
    final items = await _store.readItems(tagId: tagId);
    final available = <MediaItem>[];
    for (final item in items) {
      final path = item.privatePath;
      if (path == null || await File(path).exists()) {
        available.add(item);
      }
    }
    return available;
  }

  @override
  Future<MediaItem?> loadById(int mediaItemId) => _store.findById(mediaItemId);

  @override
  Future<MediaItem?> loadBySourceKey(String sourceKey) =>
      _store.findBySourceKey(sourceKey);

  @override
  Future<MediaItem> createMediaStoreReference({
    required MediaStoreReferenceLocation location,
    required String? mimeType,
    required DateTime? capturedAt,
    DateTime? importedAt,
  }) async {
    final existing = await _store.findBySourceKey(location.sourceKey);
    if (existing != null) return existing;
    final createdAt = importedAt ?? DateTime.now();
    try {
      final id = await _store.insertMediaStoreReference(
        location: location,
        mimeType: mimeType,
        importedAt: createdAt,
        capturedAt: _validCapturedAt(capturedAt, createdAt),
        sourceMode: 'mediaStoreReference',
        status: 'ready',
      );
      return (await _store.findById(id))!;
    } catch (_) {
      final concurrent = await _store.findBySourceKey(location.sourceKey);
      if (concurrent != null) return concurrent;
      rethrow;
    }
  }

  Future<void> _repairLibrary() async {
    var items = await _store.readItems();

    for (final item in items) {
      final path = item.privatePath;
      if (path != null && !await File(path).exists()) {
        try {
          await _store.deleteItem(item.id);
        } catch (_) {
          // Uma falha pontual de limpeza não impede a abertura da biblioteca.
        }
      }
    }

    items = await _store.readItems();
    final legacyItems =
        items
            .where((item) => item.isPrivateFile && item.mediaHash == null)
            .toList()
          ..sort((a, b) {
            final byDate = a.importedAt.compareTo(b.importedAt);
            return byDate != 0 ? byDate : a.id.compareTo(b.id);
          });

    for (final item in legacyItems) {
      final path = item.privatePath!;
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }

      try {
        final hash = await _hashCalculator.calculate(path);
        final existing = await _store.findByHash(hash);
        if (existing == null || existing.id == item.id) {
          await _store.updateHash(item.id, hash);
        } else {
          await _storage.deletePrivateCopy(path);
          await _store.deleteItem(item.id);
        }
      } catch (_) {
        // Os demais registros ainda podem ser reparados com segurança.
      }
    }
  }

  @override
  Future<ImportResult> importScreenshots(
    List<SelectedScreenshot> screenshots, {
    ImportOrigin origin = ImportOrigin.picker,
  }) async {
    final imported = <MediaItem>[];
    var duplicateCount = 0;
    var rejectedCount = 0;

    for (final screenshot in screenshots) {
      try {
        final source = File(screenshot.path);
        if (!await source.exists()) {
          rejectedCount++;
          continue;
        }

        final hash = await _hashCalculator.calculate(screenshot.path);
        if (await _store.findByHash(hash) != null) {
          duplicateCount++;
          continue;
        }

        final copy = await _storage.copyToPrivate(screenshot.path);
        final importedAt = DateTime.now();
        final capturedAt = _validCapturedAt(screenshot.capturedAt, importedAt);
        try {
          final id = await _store.insertItem(
            privatePath: copy.privatePath,
            internalName: copy.internalName,
            mimeType: screenshot.mimeType,
            mediaHash: hash,
            importedAt: importedAt,
            capturedAt: capturedAt,
            sourceMode: 'photoPicker',
            status: 'ready',
            importOrigin: origin,
          );
          final item = MediaItem(
            id: id,
            location: PrivateFileLocation(
              privatePath: copy.privatePath,
              internalName: copy.internalName,
            ),
            mimeType: screenshot.mimeType,
            mediaHash: hash,
            importedAt: importedAt,
            capturedAt: capturedAt,
            sourceMode: 'photoPicker',
            status: 'ready',
            importOrigin: origin,
          );
          imported.add(item);
          try {
            await _ocrJobScheduler?.schedule(item.id);
          } catch (_) {
            // A importação permanece válida e o OCR manual continua disponível.
          }
        } catch (_) {
          final duplicateCreatedConcurrently =
              await _findByHashIgnoringErrors(hash) != null;
          await _storage.deletePrivateCopy(copy.privatePath);
          if (duplicateCreatedConcurrently) {
            duplicateCount++;
            continue;
          }
          rejectedCount++;
        }
      } catch (_) {
        rejectedCount++;
      }
    }

    return ImportResult(
      importedItems: imported,
      duplicateCount: duplicateCount,
      rejectedCount: rejectedCount,
    );
  }

  Future<MediaItem?> _findByHashIgnoringErrors(String hash) async {
    try {
      return await _store.findByHash(hash);
    } catch (_) {
      return null;
    }
  }

  DateTime _validCapturedAt(DateTime? candidate, DateTime importedAt) {
    if (candidate == null) return importedAt;
    final milliseconds = candidate.millisecondsSinceEpoch;
    final latestReasonable = importedAt.add(const Duration(days: 1));
    if (milliseconds <= 0 || candidate.isAfter(latestReasonable)) {
      return importedAt;
    }
    return candidate;
  }

  @override
  Future<void> removeItem(MediaItem item) async {
    if (item.location case PrivateFileLocation(:final privatePath)) {
      await _storage.deletePrivateCopy(privatePath);
    }
    await _store.deleteItem(item.id);
  }

  @override
  Future<List<ScreenshotSearchResult>> searchRecognizedText(
    String query, {
    int? tagId,
    int limit = 100,
  }) async {
    final normalizedQuery = _normalizer.normalize(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }
    final matches = await _store.searchRecognizedText(
      normalizedQuery,
      tagId: tagId,
      limit: limit.clamp(1, 100).toInt(),
    );
    final available = <ScreenshotSearchResult>[];
    for (final match in matches) {
      final path = match.mediaItem.privatePath;
      if (path == null || await File(path).exists()) {
        available.add(
          ScreenshotSearchResult(
            mediaItem: match.mediaItem,
            snippet: _snippetBuilder.build(match.fullText, normalizedQuery),
          ),
        );
      }
    }
    return available;
  }

  @override
  Future<void> close() => _store.close();
}

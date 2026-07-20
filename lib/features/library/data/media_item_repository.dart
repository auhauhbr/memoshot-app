import 'dart:io';

import '../../../core/media/file_hash_calculator.dart';
import '../../../core/media/screenshot_storage.dart';
import '../../../core/text/search_snippet_builder.dart';
import '../../../core/text/text_normalizer.dart';
import '../domain/media_item.dart';
import '../domain/media_page.dart';
import '../domain/selected_screenshot.dart';
import '../domain/screenshot_search_result.dart';
import '../../processing/data/ocr_job_scheduler.dart';
import 'media_item_store.dart';
import 'capture_app_context_repository.dart';

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
  /// Carregamento completo legado. Não usar em telas de biblioteca grandes.
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

abstract interface class PagedMediaItemRepository
    implements MediaItemRepository {
  Future<MediaPage<MediaItem>> loadMediaPage([MediaPageRequest request]);

  Future<MediaPage<MediaItem>> loadMediaPageByTags(MediaPageRequest request);

  Future<MediaPage<ScreenshotSearchResult>> searchMediaPage(
    String query, [
    MediaPageRequest request,
  ]);

  Future<MediaPage<ScreenshotSearchResult>> searchMediaPageByTags(
    String query,
    MediaPageRequest request,
  );

  Future<int> countMediaItems({Set<int> tagIds = const {}});
}

abstract interface class RecentMediaItemRepository
    implements MediaItemRepository {
  Future<List<MediaItem>> loadRecentItems({
    int limit = homeRecentMediaItemLimit,
    Set<int> tagIds = const {},
  });
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
    implements
        MediaStoreReferenceMediaItemRepository,
        PagedMediaItemRepository,
        RecentMediaItemRepository {
  LocalMediaItemRepository({
    required MediaItemStore store,
    required ScreenshotStorage storage,
    FileHashCalculator hashCalculator = const Sha256FileHashCalculator(),
    OcrJobScheduler? ocrJobScheduler,
    TextNormalizer normalizer = const TextNormalizer(),
    SearchSnippetBuilder snippetBuilder = const SearchSnippetBuilder(),
    CaptureAppContextRepository? captureAppContextRepository,
  }) : this._(
         store,
         storage,
         hashCalculator,
         ocrJobScheduler,
         normalizer,
         snippetBuilder,
         captureAppContextRepository,
       );

  LocalMediaItemRepository._(
    this._store,
    this._storage,
    this._hashCalculator,
    this._ocrJobScheduler,
    this._normalizer,
    this._snippetBuilder,
    this._captureAppContextRepository,
  );

  final MediaItemStore _store;
  final ScreenshotStorage _storage;
  final FileHashCalculator _hashCalculator;
  final OcrJobScheduler? _ocrJobScheduler;
  final TextNormalizer _normalizer;
  final SearchSnippetBuilder _snippetBuilder;
  final CaptureAppContextRepository? _captureAppContextRepository;

  @override
  Future<List<MediaItem>> loadRecentItems({
    int limit = homeRecentMediaItemLimit,
    Set<int> tagIds = const {},
  }) async {
    final store = _store;
    if (store is RecentMediaItemStore) {
      return List.unmodifiable(
        await _availableItems(
          await store.readRecentItems(limit: limit, tagIds: tagIds),
        ),
      );
    }
    final page = await loadMediaPage(
      MediaPageRequest(pageSize: limit, tagIds: tagIds),
    );
    return page.items;
  }

  @override
  Future<MediaPage<MediaItem>> loadMediaPage([
    MediaPageRequest request = const MediaPageRequest(),
  ]) async {
    final store = _store;
    if (store is! PagedMediaItemStore) {
      return _legacyMediaPage(await loadAvailableItems(), request);
    }
    final page = await store.readMediaPage(request);
    return MediaPage(
      items: List.unmodifiable(await _availableItems(page.items)),
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<MediaPage<MediaItem>> loadMediaPageByTags(MediaPageRequest request) {
    return loadMediaPage(request);
  }

  @override
  Future<MediaPage<ScreenshotSearchResult>> searchMediaPage(
    String query, [
    MediaPageRequest request = const MediaPageRequest(),
  ]) async {
    final normalizedQuery = _normalizer.normalize(query);
    if (normalizedQuery.isEmpty) {
      return const MediaPage(items: [], nextCursor: null);
    }
    final store = _store;
    if (store is! PagedMediaItemStore) {
      final all = await searchRecognizedText(
        query,
        tagId: request.tagIds.firstOrNull,
        limit: maximumMediaPageSize,
      );
      return _legacySearchPage(all, request);
    }
    final page = await store.searchMediaPage(normalizedQuery, request);
    final results = <ScreenshotSearchResult>[];
    for (final match in page.items) {
      final path = match.mediaItem.privatePath;
      if (path == null || await File(path).exists()) {
        results.add(
          ScreenshotSearchResult(
            mediaItem: match.mediaItem,
            snippet: _snippetBuilder.build(match.fullText, normalizedQuery),
          ),
        );
      }
    }
    return MediaPage(
      items: List.unmodifiable(results),
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<MediaPage<ScreenshotSearchResult>> searchMediaPageByTags(
    String query,
    MediaPageRequest request,
  ) => searchMediaPage(query, request);

  @override
  Future<int> countMediaItems({Set<int> tagIds = const {}}) async {
    final store = _store;
    if (store is PagedMediaItemStore) {
      return store.countMediaItems(tagIds: tagIds);
    }
    return (await loadAvailableItems(tagId: tagIds.firstOrNull)).length;
  }

  Future<List<MediaItem>> _availableItems(List<MediaItem> items) async {
    final available = <MediaItem>[];
    for (final item in items) {
      final path = item.privatePath;
      if (path == null || await File(path).exists()) available.add(item);
    }
    return available;
  }

  MediaPage<MediaItem> _legacyMediaPage(
    List<MediaItem> items,
    MediaPageRequest request,
  ) {
    final filtered = request.cursor == null
        ? items
        : items.where((item) {
            final cursor = request.cursor!;
            final comparison = item.effectiveCapturedAt.compareTo(
              cursor.capturedAt,
            );
            return comparison < 0 || (comparison == 0 && item.id < cursor.id);
          }).toList();
    final visible = filtered.take(request.effectivePageSize).toList();
    return MediaPage(
      items: List.unmodifiable(visible),
      nextCursor: filtered.length > visible.length && visible.isNotEmpty
          ? MediaPage.cursorFor(visible.last)
          : null,
    );
  }

  MediaPage<ScreenshotSearchResult> _legacySearchPage(
    List<ScreenshotSearchResult> items,
    MediaPageRequest request,
  ) {
    final mediaPage = _legacyMediaPage(
      items.map((result) => result.mediaItem).toList(),
      request,
    );
    final byId = {for (final item in items) item.mediaItem.id: item};
    return MediaPage(
      items: List.unmodifiable(mediaPage.items.map((item) => byId[item.id]!)),
      nextCursor: mediaPage.nextCursor,
    );
  }

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
        capturedAt: capturedAt,
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
          final captureContext = screenshot.captureAppContext;
          if (origin == ImportOrigin.automatic && captureContext != null) {
            try {
              await _captureAppContextRepository?.save(id, captureContext);
            } catch (_) {
              // O contexto opcional nunca impede importação, OCR ou classificação.
            }
          }
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

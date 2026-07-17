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
  });

  final List<MediaItem> importedItems;
  final int duplicateCount;
}

abstract interface class MediaItemRepository {
  Future<List<MediaItem>> loadAvailableItems();

  Future<ImportResult> importScreenshots(List<SelectedScreenshot> screenshots);

  Future<void> removeItem(MediaItem item);

  Future<List<ScreenshotSearchResult>> searchRecognizedText(
    String query, {
    int limit = 100,
  });

  Future<void> close();
}

class LocalMediaItemRepository implements MediaItemRepository {
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
  Future<List<MediaItem>> loadAvailableItems() async {
    await _repairLibrary();
    final items = await _store.readItems();
    final available = <MediaItem>[];
    for (final item in items) {
      if (await File(item.privatePath).exists()) {
        available.add(item);
      }
    }
    return available;
  }

  Future<void> _repairLibrary() async {
    var items = await _store.readItems();

    for (final item in items) {
      if (!await File(item.privatePath).exists()) {
        try {
          await _store.deleteItem(item.id);
        } catch (_) {
          // Uma falha pontual de limpeza não impede a abertura da biblioteca.
        }
      }
    }

    items = await _store.readItems();
    final legacyItems = items.where((item) => item.mediaHash == null).toList()
      ..sort((a, b) {
        final byDate = a.importedAt.compareTo(b.importedAt);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });

    for (final item in legacyItems) {
      final file = File(item.privatePath);
      if (!await file.exists()) {
        continue;
      }

      try {
        final hash = await _hashCalculator.calculate(item.privatePath);
        final existing = await _store.findByHash(hash);
        if (existing == null || existing.id == item.id) {
          await _store.updateHash(item.id, hash);
        } else {
          await _storage.deletePrivateCopy(item.privatePath);
          await _store.deleteItem(item.id);
        }
      } catch (_) {
        // Os demais registros ainda podem ser reparados com segurança.
      }
    }
  }

  @override
  Future<ImportResult> importScreenshots(
    List<SelectedScreenshot> screenshots,
  ) async {
    final imported = <MediaItem>[];
    var duplicateCount = 0;

    for (final screenshot in screenshots) {
      final source = File(screenshot.path);
      if (!await source.exists()) {
        throw const FileSystemException('Arquivo de origem indisponível.');
      }

      final hash = await _hashCalculator.calculate(screenshot.path);
      if (await _store.findByHash(hash) != null) {
        duplicateCount++;
        continue;
      }

      final copy = await _storage.copyToPrivate(screenshot.path);
      final importedAt = DateTime.now();
      try {
        final id = await _store.insertItem(
          privatePath: copy.privatePath,
          internalName: copy.internalName,
          mimeType: screenshot.mimeType,
          mediaHash: hash,
          importedAt: importedAt,
          sourceMode: 'photoPicker',
          status: 'ready',
        );
        final item = MediaItem(
          id: id,
          privatePath: copy.privatePath,
          internalName: copy.internalName,
          mimeType: screenshot.mimeType,
          mediaHash: hash,
          importedAt: importedAt,
          sourceMode: 'photoPicker',
          status: 'ready',
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
        rethrow;
      }
    }

    return ImportResult(
      importedItems: imported,
      duplicateCount: duplicateCount,
    );
  }

  Future<MediaItem?> _findByHashIgnoringErrors(String hash) async {
    try {
      return await _store.findByHash(hash);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> removeItem(MediaItem item) async {
    await _storage.deletePrivateCopy(item.privatePath);
    await _store.deleteItem(item.id);
  }

  @override
  Future<List<ScreenshotSearchResult>> searchRecognizedText(
    String query, {
    int limit = 100,
  }) async {
    final normalizedQuery = _normalizer.normalize(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }
    final matches = await _store.searchRecognizedText(
      normalizedQuery,
      limit: limit.clamp(1, 100).toInt(),
    );
    final available = <ScreenshotSearchResult>[];
    for (final match in matches) {
      if (await File(match.mediaItem.privatePath).exists()) {
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

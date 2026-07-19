import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/automatic_import/automatic_screenshot_source.dart';
import 'package:memoshot/core/database/contexto_database.dart'
    show ContextoDatabase;
import 'package:memoshot/core/media/screenshot_storage.dart';
import 'package:memoshot/core/ocr/text_recognition_service.dart';
import 'package:memoshot/features/automatic_import/data/automatic_import_settings_repository.dart';
import 'package:memoshot/features/automatic_import/domain/automatic_import_settings.dart';
import 'package:memoshot/features/background_processing/background_processing_runner.dart';
import 'package:memoshot/features/classification/application/classification_queue_processor.dart';
import 'package:memoshot/features/classification/application/classification_composition.dart';
import 'package:memoshot/features/classification/domain/stored_classification_suggestion.dart';
import 'package:memoshot/features/categories/data/category_repository.dart';
import 'package:memoshot/features/categories/data/category_store.dart';
import 'package:memoshot/features/library/data/media_item_repository.dart';
import 'package:memoshot/features/library/data/media_item_store.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/library/domain/screenshot_search_result.dart';
import 'package:memoshot/features/library/domain/selected_screenshot.dart';
import 'package:memoshot/features/processing/data/ocr_queue_processor.dart';
import 'package:memoshot/features/processing/data/ocr_job_scheduler.dart';
import 'package:memoshot/features/processing/data/processing_job_store.dart';
import 'package:memoshot/features/ocr/data/ocr_repository.dart';
import 'package:memoshot/features/ocr/data/ocr_result_store.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'memoshot_headless_runner_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('automação desativada não toca inbox ou filas', () async {
    final source = _FakeSource();
    final ocr = _FakeOcrQueue();
    final classification = _FakeClassificationQueue();

    final summary = await _runner(
      settings: _FakeSettings(enabled: false),
      source: source,
      ocr: ocr,
      classification: classification,
    ).run();

    expect(summary.resultCode, BackgroundProcessingResultCode.disabled);
    expect(source.loadCalls, 0);
    expect(ocr.recoverCalls, 0);
    expect(classification.recoverCalls, 0);
  });

  test('sem tarefas recupera filas e conclui sem polling', () async {
    final events = <String>[];
    final summary = await _runner(
      settings: _FakeSettings(enabled: true),
      source: _FakeSource(events: events),
      ocr: _FakeOcrQueue(events: events),
      classification: _FakeClassificationQueue(events: events),
    ).run();

    expect(summary.resultCode, BackgroundProcessingResultCode.completed);
    expect(summary.pendingImmediateWork, isFalse);
    expect(events, [
      'recoverOcr',
      'recoverClassification',
      'inbox',
      'ocr',
      'classification',
    ]);
  });

  test('preserva ordem inbox, OCR, classificação e backfill', () async {
    final file = File('${temporaryDirectory.path}/capture.png');
    await file.writeAsBytes([1, 2, 3]);
    final events = <String>[];
    final source = _FakeSource(
      events: events,
      entries: [_entry('one', file.path)],
    );
    final media = _FakeMediaRepository(events: events);
    final classification = _FakeClassificationQueue(
      events: events,
      processed: 1,
    );

    final summary = await _runner(
      settings: _FakeSettings(enabled: true),
      source: source,
      media: media,
      ocr: _FakeOcrQueue(events: events, processed: 1),
      classification: classification,
    ).run();

    expect(summary.importedCount, 1);
    expect(summary.ocrProcessedCount, 1);
    expect(summary.classificationProcessedCount, 1);
    expect(source.acknowledged, ['one']);
    expect(classification.backfillFlags, [true]);
    expect(events, [
      'recoverOcr',
      'recoverClassification',
      'inbox',
      'import',
      'ocr',
      'classification',
    ]);
  });

  test('duplicata confirma a mesma entrada sem importar novamente', () async {
    final file = File('${temporaryDirectory.path}/duplicate.png');
    await file.writeAsBytes([4]);
    final source = _FakeSource(entries: [_entry('duplicate', file.path)]);
    final media = _FakeMediaRepository(duplicate: true);

    final summary = await _runner(
      settings: _FakeSettings(enabled: true),
      source: source,
      media: media,
    ).run();

    expect(summary.importedCount, 0);
    expect(source.acknowledged, ['duplicate']);
    expect(media.importCalls, 1);
  });

  test(
    'limite de lote preserva trabalho imediato para nova execução',
    () async {
      final entries = <BackgroundScreenshotEntry>[];
      for (var index = 0; index < 3; index++) {
        final file = File('${temporaryDirectory.path}/$index.png');
        await file.writeAsBytes([index]);
        entries.add(_entry('$index', file.path));
      }
      final source = _FakeSource(entries: entries);

      final summary = await _runner(
        settings: _FakeSettings(enabled: true),
        source: source,
        maximumCycles: 1,
        maximumItems: 2,
      ).run();

      expect(summary.importedCount, 2);
      expect(source.acknowledged, hasLength(2));
      expect(summary.pendingImmediateWork, isTrue);
      expect(
        summary.resultCode,
        BackgroundProcessingResultCode.cycleLimitReached,
      );
    },
  );

  test('trabalho imediato usa múltiplos ciclos até esvaziar', () async {
    final ocr = _FakeOcrQueue(immediateSequence: [true, false]);
    final summary = await _runner(
      settings: _FakeSettings(enabled: true),
      source: _FakeSource(),
      ocr: ocr,
    ).run();

    expect(ocr.processCalls, 2);
    expect(summary.resultCode, BackgroundProcessingResultCode.completed);
  });

  test('retry futuro não é considerado trabalho imediato', () async {
    final classification = _FakeClassificationQueue(
      processed: 1,
      hasImmediateWork: false,
    );
    final summary = await _runner(
      settings: _FakeSettings(enabled: true),
      source: _FakeSource(),
      classification: classification,
    ).run();

    expect(summary.classificationProcessedCount, 1);
    expect(summary.pendingImmediateWork, isFalse);
    expect(summary.resultCode, BackgroundProcessingResultCode.completed);
  });

  test('cancelamento e timeout cooperativos encerram entre etapas', () async {
    final cancelled = await _runner(
      settings: _FakeSettings(enabled: true),
      source: _FakeSource(),
      isCancelled: () => true,
    ).run();
    expect(cancelled.resultCode, BackgroundProcessingResultCode.cancelled);

    var clockCalls = 0;
    final start = DateTime.utc(2026, 7, 19);
    final timedOut = await _runner(
      settings: _FakeSettings(enabled: true),
      source: _FakeSource(),
      now: () =>
          clockCalls++ == 0 ? start : start.add(const Duration(minutes: 9)),
    ).run();
    expect(
      timedOut.resultCode,
      BackgroundProcessingResultCode.timeLimitReached,
    );
  });

  test('falha de uma entrada não bloqueia a seguinte', () async {
    final first = File('${temporaryDirectory.path}/first.png');
    final second = File('${temporaryDirectory.path}/second.png');
    await first.writeAsBytes([1]);
    await second.writeAsBytes([2]);
    final source = _FakeSource(
      entries: [_entry('first', first.path), _entry('second', second.path)],
    );
    final media = _FakeMediaRepository(failFirst: true);

    final summary = await _runner(
      settings: _FakeSettings(enabled: true),
      source: source,
      media: media,
      maximumCycles: 1,
    ).run();

    expect(media.importCalls, 2);
    expect(source.acknowledged, ['second']);
    expect(summary.importedCount, 1);
  });

  test('payload técnico não contém conteúdo privado', () {
    const summary = BackgroundProcessingSummary(
      importedCount: 1,
      ocrProcessedCount: 2,
      classificationProcessedCount: 3,
      pendingImmediateWork: true,
      resultCode: BackgroundProcessingResultCode.cycleLimitReached,
    );
    final payload = summary.toChannelPayload();
    final serialized = payload.toString();

    expect(payload.keys, {
      'importedCount',
      'ocrProcessedCount',
      'classificationProcessedCount',
      'pendingImmediateWork',
      'resultCode',
    });
    for (final sensitive in [
      'pessoa@exemplo.com',
      '+55 81 99999-0000',
      'https://privado.example',
      r'R$ 1.234,56',
      '/data/user/0/',
      'texto OCR',
    ]) {
      expect(serialized, isNot(contains(sensitive)));
    }
  });

  test(
    'integra inbox, OCR, classificação e autoaplicação sem widgets',
    () async {
      final database = ContextoDatabase.forTesting(NativeDatabase.memory());
      final processingStore = DriftProcessingJobStore(database);
      final ocrStore = DriftOcrResultStore(database);
      final settings = DriftAutomaticImportSettingsRepository(database);
      await settings.enable(baselineMediaId: 0);
      final sourceFile = File('${temporaryDirectory.path}/strong.png');
      await sourceFile.writeAsBytes([7, 8, 9]);
      final source = _FakeSource(entries: [_entry('strong', sourceFile.path)]);
      final mediaRepository = LocalMediaItemRepository(
        store: DriftMediaItemStore(database),
        storage: PrivateScreenshotStorage(
          documentsDirectory: () async => temporaryDirectory,
        ),
        ocrJobScheduler: LocalOcrJobScheduler(processingStore),
      );
      final recognition = _StrongRecognitionService();
      final ocrRepository = LocalOcrRepository(
        store: ocrStore,
        recognitionService: recognition,
      );
      final suggestions = createLocalClassificationRepository(database);
      final categories = LocalCategoryRepository(
        store: DriftCategoryStore(database),
      );
      final classificationQueue = createLocalClassificationQueue(
        database: database,
        suggestionRepository: suggestions,
        categoryRepository: categories,
        mediaRepository: mediaRepository,
        ocrRepository: ocrRepository,
      );
      final ocrQueue = LocalOcrQueueProcessor(
        jobStore: processingStore,
        resultStore: ocrStore,
        recognitionService: recognition,
        classificationJobScheduler: createLocalClassificationJobScheduler(
          database,
        ),
      );
      addTearDown(() async {
        await ocrQueue.close();
        await classificationQueue.close();
        await database.close();
      });

      final summary = await BackgroundProcessingRunner(
        settingsRepository: settings,
        inboxSource: source,
        mediaRepository: mediaRepository,
        ocrQueue: ocrQueue,
        classificationQueue: classificationQueue,
      ).run();

      final items = await mediaRepository.loadAvailableItems();
      expect(summary.importedCount, 1);
      expect(summary.ocrProcessedCount, 1);
      expect(summary.classificationProcessedCount, 1);
      expect(recognition.callCount, 1);
      expect(items, hasLength(1));
      expect(await ocrRepository.loadFor(items.single.id), isNotNull);
      expect(
        (await suggestions.loadByMediaItemId(items.single.id))?.status,
        ClassificationSuggestionStatus.autoApplied,
      );
      expect((await categories.loadRootCategories()).single.name, 'Carreira');
      expect(source.entries, isEmpty);
    },
  );
}

BackgroundProcessingRunner _runner({
  required _FakeSettings settings,
  required _FakeSource source,
  _FakeMediaRepository? media,
  _FakeOcrQueue? ocr,
  _FakeClassificationQueue? classification,
  int maximumCycles = backgroundMaximumCycles,
  int maximumItems = backgroundMaximumItemsPerCycle,
  DateTime Function()? now,
  bool Function()? isCancelled,
}) {
  return BackgroundProcessingRunner(
    settingsRepository: settings,
    inboxSource: source,
    mediaRepository: media ?? _FakeMediaRepository(),
    ocrQueue: ocr ?? _FakeOcrQueue(),
    classificationQueue: classification ?? _FakeClassificationQueue(),
    maximumCycles: maximumCycles,
    maximumItemsPerCycle: maximumItems,
    now: now ?? DateTime.now,
    isCancelled: isCancelled ?? () => false,
  );
}

BackgroundScreenshotEntry _entry(String id, String path) {
  return BackgroundScreenshotEntry(
    entryId: id,
    mediaId: id.hashCode,
    privatePath: path,
    mimeType: 'image/png',
    capturedAt: DateTime.utc(2026, 7, 19),
  );
}

class _FakeSettings implements AutomaticImportSettingsRepository {
  _FakeSettings({required this.enabled});

  bool enabled;

  @override
  Future<AutomaticImportSettings> load() async => AutomaticImportSettings(
    enabled: enabled,
    hasStoredPreference: true,
    lastMediaId: 0,
    updatedAt: DateTime.utc(2026),
  );

  @override
  Future<void> disable() async => enabled = false;

  @override
  Future<void> enable({required int baselineMediaId}) async => enabled = true;

  @override
  Future<void> updateMarker(int lastMediaId) async {}
}

class _FakeSource implements AutomaticScreenshotSource {
  _FakeSource({List<BackgroundScreenshotEntry>? entries, this.events})
    : entries = [...?entries];

  final List<BackgroundScreenshotEntry> entries;
  final List<String>? events;
  final List<String> acknowledged = [];
  int loadCalls = 0;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<List<BackgroundScreenshotEntry>> loadBackgroundInbox() async {
    loadCalls++;
    events?.add('inbox');
    return List.unmodifiable(entries);
  }

  @override
  Future<int> backgroundInboxPendingCount() async => entries.length;

  @override
  Future<void> acknowledgeBackgroundEntry(String entryId) async {
    acknowledged.add(entryId);
    entries.removeWhere((entry) => entry.entryId == entryId);
  }

  @override
  Future<void> rejectBackgroundEntry(String entryId) async {
    entries.removeWhere((entry) => entry.entryId == entryId);
  }

  @override
  Future<BackgroundMonitorStatus> configureBackgroundMonitoring({
    required bool enabled,
    required int lastMediaId,
    bool resetBaseline = false,
  }) async => BackgroundMonitorStatus(
    available: true,
    enabled: enabled,
    lastMediaId: lastMediaId,
  );

  @override
  Future<int> currentMaxMediaId() async => 0;

  @override
  Future<void> deleteTemporary(String path) async {}

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<MediaPermissionStatus> permissionStatus() async =>
      MediaPermissionStatus.fullAccess;

  @override
  Future<MediaPermissionStatus> requestPermission() async =>
      MediaPermissionStatus.fullAccess;

  @override
  Future<AutomaticScreenshotBatch> scanAfter(int lastMediaId) async =>
      AutomaticScreenshotBatch(
        lastExaminedMediaId: lastMediaId,
        items: const [],
      );

  @override
  Future<void> startObserving() async {}

  @override
  Future<void> stopObserving() async {}
}

class _FakeMediaRepository implements MediaItemRepository {
  _FakeMediaRepository({
    this.events,
    this.duplicate = false,
    this.failFirst = false,
  });

  final List<String>? events;
  final bool duplicate;
  final bool failFirst;
  int importCalls = 0;

  @override
  Future<ImportResult> importScreenshots(
    List<SelectedScreenshot> screenshots, {
    ImportOrigin origin = ImportOrigin.picker,
  }) async {
    importCalls++;
    events?.add('import');
    if (failFirst && importCalls == 1) throw StateError('controlled');
    if (duplicate) {
      return const ImportResult(importedItems: [], duplicateCount: 1);
    }
    return ImportResult(
      importedItems: [
        MediaItem(
          id: importCalls,
          privatePath: screenshots.single.path,
          internalName: 'internal.png',
          mimeType: screenshots.single.mimeType,
          importedAt: DateTime.utc(2026),
          sourceMode: 'photoPicker',
          status: 'ready',
          importOrigin: origin,
        ),
      ],
      duplicateCount: 0,
    );
  }

  @override
  Future<void> close() async {}

  @override
  Future<List<MediaItem>> loadAvailableItems({int? tagId}) async => const [];

  @override
  Future<MediaItem?> loadById(int mediaItemId) async => null;

  @override
  Future<void> removeItem(MediaItem item) async {}

  @override
  Future<List<ScreenshotSearchResult>> searchRecognizedText(
    String query, {
    int? tagId,
    int limit = 100,
  }) async => const [];
}

class _FakeOcrQueue implements HeadlessOcrQueue {
  _FakeOcrQueue({
    this.events,
    this.processed = 0,
    List<bool>? immediateSequence,
  }) : _immediateSequence = [...?immediateSequence];

  final List<String>? events;
  final int processed;
  final List<bool> _immediateSequence;
  int recoverCalls = 0;
  int processCalls = 0;

  @override
  Future<int> recoverInterrupted() async {
    recoverCalls++;
    events?.add('recoverOcr');
    return 0;
  }

  @override
  Future<OcrQueueRunSummary> processAvailable({
    required int maximumItems,
  }) async {
    processCalls++;
    events?.add('ocr');
    final immediate = _immediateSequence.isEmpty
        ? false
        : _immediateSequence.removeAt(0);
    return OcrQueueRunSummary(
      processedCount: processed,
      hasImmediateWork: immediate,
    );
  }
}

class _FakeClassificationQueue implements HeadlessClassificationQueue {
  _FakeClassificationQueue({
    this.events,
    this.processed = 0,
    this.hasImmediateWork = false,
  });

  final List<String>? events;
  final int processed;
  final bool hasImmediateWork;
  final List<bool> backfillFlags = [];
  int recoverCalls = 0;

  @override
  Future<int> recoverInterrupted() async {
    recoverCalls++;
    events?.add('recoverClassification');
    return 0;
  }

  @override
  Future<ClassificationQueueRunSummary> processAvailable({
    required int maximumItems,
    required bool enqueueBackfill,
  }) async {
    events?.add('classification');
    backfillFlags.add(enqueueBackfill);
    return ClassificationQueueRunSummary(
      processedCount: processed,
      backfillCount: 0,
      hasImmediateWork: hasImmediateWork,
    );
  }
}

class _StrongRecognitionService implements TextRecognitionService {
  int callCount = 0;

  @override
  Future<TextRecognitionOutput> recognize(String imagePath) async {
    callCount++;
    return const TextRecognitionOutput(
      fullText:
          'vaga entrevista recrutadora currículo candidatura processo seletivo',
      engine: 'fake-local',
      engineVersion: '1',
    );
  }
}

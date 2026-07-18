import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/theme/app_theme.dart';
import 'package:memoshot/features/categories/data/category_repository.dart';
import 'package:memoshot/features/classification/application/review_queue.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_repository.dart';
import 'package:memoshot/features/classification/domain/classification_models.dart';
import 'package:memoshot/features/classification/domain/stored_classification_suggestion.dart';
import 'package:memoshot/features/classification/presentation/review_queue_page.dart';
import 'package:memoshot/features/library/data/media_item_repository.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/library/domain/selected_screenshot.dart';
import 'package:memoshot/features/library/domain/screenshot_search_result.dart';
import 'package:memoshot/features/ocr/data/ocr_repository.dart';
import 'package:memoshot/features/ocr/domain/ocr_result.dart';
import 'package:memoshot/features/processing/data/ocr_queue_processor.dart';
import 'package:memoshot/features/processing/domain/processing_job.dart';
import 'package:memoshot/features/tags/data/tag_repository.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'review_queue_test_',
    );
  });

  tearDown(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('modelo traduz motivos e apresenta confiança como força das regras', () {
    final media = _media(1, '/tmp/one.png');
    final expected = {
      ClassificationReviewReason.lowConfidence:
          'Classificação com baixa confiança',
      ClassificationReviewReason.ambiguous:
          'Há mais de uma classificação possível',
      ClassificationReviewReason.noCategory:
          'Não foi possível determinar uma pasta',
      ClassificationReviewReason.noSuggestion:
          'Não foi possível classificar este print',
      ClassificationReviewReason.manualReview:
          'Confirme a organização sugerida',
    };

    for (final entry in expected.entries) {
      final item = ReviewQueueItem(
        mediaItem: media,
        suggestion: _suggestion(1, reason: entry.key, confidence: 0.68),
      );
      expect(item.reviewReasonLabel, entry.value);
      expect(item.confidenceLabel, 'Confiança das regras: 68%');
    }
  });

  test(
    'loader combina em lote, filtra mídia ausente e preserva ordem',
    () async {
      final first = _media(1, '/tmp/first.png');
      final third = _media(3, '/tmp/third.png');
      final suggestions = [_suggestion(3), _suggestion(2), _suggestion(1)];
      final loader = ReviewQueueLoader(
        suggestionRepository: _SuggestionRepository(pending: suggestions),
        mediaRepository: _MediaRepository([first, third]),
      );

      final items = await loader.loadPending();

      expect(items.map((item) => item.mediaItem.id), [3, 1]);
    },
  );

  testWidgets('mostra carregamento e depois estado vazio', (tester) async {
    final load = Completer<List<StoredClassificationSuggestion>>();
    final suggestions = _SuggestionRepository(loads: [load.future]);
    await tester.pumpWidget(_app(suggestions, _MediaRepository(const [])));

    expect(find.byKey(const Key('review-queue-loading')), findsOneWidget);
    load.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('Tudo organizado'), findsOneWidget);
    expect(find.text('Não há prints aguardando revisão.'), findsOneWidget);
  });

  testWidgets('erro permite tentar novamente', (tester) async {
    final suggestions = _SuggestionRepository(failLoadCount: 1);
    await tester.pumpWidget(_app(suggestions, _MediaRepository(const [])));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar os prints para revisão.'),
      findsOneWidget,
    );
    expect(find.textContaining('privado'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Tudo organizado'), findsOneWidget);
  });

  testWidgets('fila apresenta dados explicáveis e limita etiquetas', (
    tester,
  ) async {
    final image = _image(temporaryDirectory, 'item.png');
    final media = _media(
      1,
      image.path,
      capturedAt: DateTime(2026, 7, 18, 9, 5),
    );
    final suggestion = _suggestion(
      1,
      category: 'Uma pasta sugerida com nome bastante longo para teste',
      confidence: 0.68,
      tags: ['Urgente', 'Vaga', 'Entrevista', 'Contato', 'Data', 'Horário'],
    );
    await tester.pumpWidget(
      _app(
        _SuggestionRepository(pending: [suggestion]),
        _MediaRepository([media]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Pasta sugerida:'), findsOneWidget);
    expect(find.text('Confiança das regras: 68%'), findsOneWidget);
    expect(find.text('Classificação com baixa confiança'), findsOneWidget);
    expect(find.text('Urgente'), findsOneWidget);
    expect(find.text('Entrevista'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    expect(find.text('Contato'), findsNothing);
    expect(find.text('18/07/2026, 09:05'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('categoria ausente e vários itens mantêm ordem recebida', (
    tester,
  ) async {
    final firstImage = _image(temporaryDirectory, 'first.png');
    final secondImage = _image(temporaryDirectory, 'second.png');
    final media = [_media(1, firstImage.path), _media(2, secondImage.path)];
    await tester.pumpWidget(
      _app(
        _SuggestionRepository(
          pending: [_suggestion(2, category: null), _suggestion(1)],
        ),
        _MediaRepository(media),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-item-2')), findsOneWidget);
    expect(find.text('Pasta ainda não identificada'), findsOneWidget);
    final cards = tester.widgetList<InkWell>(find.byType(InkWell)).toList();
    expect(cards, isNotEmpty);
  });

  testWidgets('abre inspeção com imagem, evidências e sem dados sensíveis', (
    tester,
  ) async {
    final image = _image(temporaryDirectory, 'detail.png');
    final media = _media(1, image.path);
    final suggestion = _suggestion(
      1,
      tags: ['Entrevista'],
      evidence: [
        ClassificationEvidence(
          ruleId: 'category.career.interview',
          type: ClassificationEvidenceType.keyword,
          description: 'Encontrou termos relacionados a processos seletivos.',
          weight: 0.68,
          safeMatch: 'entrevista',
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        _SuggestionRepository(pending: [suggestion]),
        _MediaRepository([media]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-item-1')));
    await tester.pumpAndSettle();

    expect(find.text('Revisar sugestão'), findsOneWidget);
    expect(find.byKey(const Key('review-suggestion-image')), findsOneWidget);
    expect(find.text('Etiquetas sugeridas'), findsOneWidget);
    expect(
      find.text('• Encontrou termos relacionados a processos seletivos.'),
      findsOneWidget,
    );
    expect(find.text('Termo identificado: entrevista'), findsOneWidget);
    expect(find.textContaining('category.career'), findsNothing);
    for (final sensitive in [
      'segredo@empresa.com',
      '99999-1234',
      'https://privado.example',
      '8.450,00',
      'OCR completo privado',
    ]) {
      expect(find.textContaining(sensitive), findsNothing);
    }
  });

  testWidgets('inspeção abre o detalhe normal do screenshot', (tester) async {
    final image = _image(temporaryDirectory, 'open-detail.png');
    final media = _media(1, image.path);
    await tester.pumpWidget(
      _app(
        _SuggestionRepository(pending: [_suggestion(1)]),
        _MediaRepository([media]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-item-1')));
    await tester.pumpAndSettle();
    final details = find.byKey(
      const Key('open-screenshot-details-from-review'),
    );
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();

    expect(find.text('Detalhes do screenshot'), findsOneWidget);
  });

  testWidgets('resultado antigo não sobrescreve recarga mais nova', (
    tester,
  ) async {
    final oldLoad = Completer<List<StoredClassificationSuggestion>>();
    final suggestion = _suggestion(1);
    final suggestions = _SuggestionRepository(
      loads: [
        Future.value([suggestion]),
        oldLoad.future,
        Future.value(const []),
      ],
    );
    final key = GlobalKey<ReviewQueuePageState>();
    await tester.pumpWidget(
      _app(
        suggestions,
        _MediaRepository([_media(1, '/tmp/item.png')]),
        pageKey: key,
      ),
    );
    await tester.pumpAndSettle();

    final oldRequest = key.currentState!.reload(showLoading: false);
    await tester.pump();
    final newRequest = key.currentState!.reload(showLoading: false);
    await newRequest;
    await tester.pump();
    oldLoad.complete([suggestion]);
    await oldRequest;
    await tester.pump();

    expect(find.text('Tudo organizado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  _SuggestionRepository suggestions,
  _MediaRepository media, {
  Key? pageKey,
}) {
  final ocr = _OcrRepository();
  return MaterialApp(
    theme: AppTheme.light,
    home: ReviewQueuePage(
      key: pageKey,
      loader: ReviewQueueLoader(
        suggestionRepository: suggestions,
        mediaRepository: media,
      ),
      mediaRepository: media,
      ocrRepository: ocr,
      ocrQueue: _OcrQueue(),
      categoryRepository: _CategoryRepository(),
      tagRepository: _TagRepository(),
    ),
  );
}

class _SuggestionRepository implements ClassificationSuggestionRepository {
  _SuggestionRepository({
    List<StoredClassificationSuggestion> pending = const [],
    List<Future<List<StoredClassificationSuggestion>>> loads = const [],
    int failLoadCount = 0,
  }) : this._(pending, [...loads], failLoadCount);

  _SuggestionRepository._(this._pending, this._loads, this.failLoadCount);

  final List<StoredClassificationSuggestion> _pending;
  final List<Future<List<StoredClassificationSuggestion>>> _loads;
  int failLoadCount;

  @override
  Future<List<StoredClassificationSuggestion>> loadPendingReview() async {
    if (failLoadCount > 0) {
      failLoadCount--;
      throw StateError('privado');
    }
    if (_loads.isNotEmpty) return _loads.removeAt(0);
    return [..._pending];
  }

  @override
  Future<int> countPendingReview() async => _pending.length;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MediaRepository implements MediaItemRepository {
  _MediaRepository(this.items);

  final List<MediaItem> items;

  @override
  Future<List<MediaItem>> loadAvailableItems({int? tagId}) async => [...items];

  @override
  Future<void> removeItem(MediaItem item) async => items.remove(item);

  @override
  Future<void> close() async {}

  @override
  Future<ImportResult> importScreenshots(
    List<SelectedScreenshot> screenshots, {
    ImportOrigin origin = ImportOrigin.picker,
  }) async => const ImportResult(importedItems: [], duplicateCount: 0);

  @override
  Future<List<ScreenshotSearchResult>> searchRecognizedText(
    String query, {
    int? tagId,
    int limit = 100,
  }) async => const [];
}

class _OcrRepository implements OcrRepository {
  @override
  Future<OcrResult?> loadFor(int mediaItemId) async => null;

  @override
  Future<OcrResult> process(MediaItem mediaItem) =>
      throw UnsupportedError('Não usado.');
}

class _OcrQueue implements OcrQueue {
  @override
  Stream<int> get changes => const Stream.empty();

  @override
  Future<OcrItemState> loadState(int mediaItemId) async =>
      OcrItemState.notScheduled;

  @override
  Future<void> close() async {}

  @override
  Future<void> recoverAndStart() async {}

  @override
  Future<void> retry(MediaItem mediaItem) async {}

  @override
  void signal() {}
}

class _CategoryRepository implements CategoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TagRepository implements TagRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StoredClassificationSuggestion _suggestion(
  int mediaItemId, {
  String? category = 'Carreira',
  double confidence = 0.4,
  ClassificationReviewReason reason = ClassificationReviewReason.lowConfidence,
  List<String> tags = const [],
  List<ClassificationEvidence> evidence = const [],
}) {
  return StoredClassificationSuggestion(
    mediaItemId: mediaItemId,
    suggestedCategoryName: category,
    confidence: confidence,
    hasSuggestion: category != null || tags.isNotEmpty,
    suggestedTags: tags
        .map(
          (name) => SuggestedTag(
            name: name,
            confidence: confidence,
            evidence: const [],
          ),
        )
        .toList(),
    evidence: evidence,
    status: ClassificationSuggestionStatus.pendingReview,
    reviewReason: reason,
    engineVersion: 1,
    createdAt: DateTime(2026, 7, 18),
    updatedAt: DateTime(2026, 7, 18),
  );
}

MediaItem _media(int id, String path, {DateTime? capturedAt}) {
  return MediaItem(
    id: id,
    privatePath: path,
    internalName: 'interno-$id.png',
    importedAt: DateTime(2026, 7, 18),
    capturedAt: capturedAt,
    sourceMode: 'photoPicker',
    status: 'ready',
  );
}

File _image(Directory directory, String name) {
  return File('${directory.path}/$name')..writeAsBytesSync(const <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ]);
}

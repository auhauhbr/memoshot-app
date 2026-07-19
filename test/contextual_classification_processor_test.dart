import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/database/contexto_database.dart'
    show ContextoDatabase;
import 'package:memoshot/core/ocr/media_ocr_input.dart';
import 'package:memoshot/core/visual/local_visual_analyzer.dart';
import 'package:memoshot/features/categories/data/category_repository.dart';
import 'package:memoshot/features/categories/data/category_store.dart';
import 'package:memoshot/features/classification/application/classification_processor.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_repository.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_store.dart';
import 'package:memoshot/features/classification/domain/contextual_classification.dart';
import 'package:memoshot/features/library/data/media_item_store.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/ocr/data/ocr_repository.dart';
import 'package:memoshot/features/ocr/domain/ocr_result.dart';

void main() {
  late ContextoDatabase database;
  late Directory directory;
  late LocalCategoryRepository categories;
  late LocalClassificationSuggestionRepository suggestions;

  setUp(() {
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    directory = Directory.systemTemp.createTempSync(
      'memoshot_visual_processor_',
    );
    categories = LocalCategoryRepository(store: DriftCategoryStore(database));
    suggestions = LocalClassificationSuggestionRepository(
      DriftClassificationSuggestionStore(database),
    );
  });

  tearDown(() async {
    await database.close();
    directory.deleteSync(recursive: true);
  });

  test('arquivo privado é analisado sem cópia e nunca é apagado', () async {
    final file = File('${directory.path}/private.png')
      ..writeAsBytesSync([1, 2, 3]);
    final item = await _privateItem(database, file.path);
    final analyzer = _FakeVisualAnalyzer();
    final processor = _processor(
      analyzer: analyzer,
      resolver: LocalMediaOcrInputResolver(_FakeBridge(file.path)),
      categories: categories,
      suggestions: suggestions,
      ocr: _FakeOcrRepository(_ocr(item.id, 'livro capa comum autor')),
    );

    final result = await processor.process(
      mediaItem: item,
      ocrResult: _ocr(item.id, 'livro capa comum autor'),
    );

    expect(result.suggestedCategoryName, 'Livros / Capas');
    expect(analyzer.paths, [file.path]);
    expect(file.existsSync(), isTrue);
    await processor.close();
    expect(analyzer.closed, isTrue);
  });

  test('referência usa temporário e libera token em finally', () async {
    final temporary = File('${directory.path}/temporary.png')
      ..writeAsBytesSync([1]);
    final item = await _referencedItem(database);
    final bridge = _FakeBridge(temporary.path);
    final processor = _processor(
      analyzer: _FakeVisualAnalyzer(),
      resolver: LocalMediaOcrInputResolver(bridge),
      categories: categories,
      suggestions: suggestions,
      ocr: _FakeOcrRepository(_ocr(item.id, 'teclado comprar carrinho preço')),
    );

    await processor.process(
      mediaItem: item,
      ocrResult: _ocr(item.id, 'teclado comprar carrinho preço'),
    );

    expect(bridge.preparedLocations, [item.location]);
    expect(bridge.releasedTokens, ['visual-token']);
    expect(item.privatePath, isNull);
    expect(item.mediaHash, isNull);
    await processor.close();
  });

  test('falha visual usa OCR e libera temporário', () async {
    final temporary = File('${directory.path}/failure.png')
      ..writeAsBytesSync([1]);
    final item = await _referencedItem(database);
    final bridge = _FakeBridge(temporary.path);
    final processor = _processor(
      analyzer: _FakeVisualAnalyzer(error: StateError('falha visual')),
      resolver: LocalMediaOcrInputResolver(bridge),
      categories: categories,
      suggestions: suggestions,
      ocr: _FakeOcrRepository(_ocr(item.id, 'curso aula módulo videoaula')),
    );

    final result = await processor.process(
      mediaItem: item,
      ocrResult: _ocr(item.id, 'curso aula módulo videoaula'),
    );

    expect(result.suggestedCategoryName, 'Estudos / Cursos');
    expect(bridge.releasedTokens, ['visual-token']);
    await processor.close();
  });

  test(
    'reprocessamento individual preserva pasta escolhida pelo usuário',
    () async {
      final file = File('${directory.path}/manual.png')..writeAsBytesSync([1]);
      final item = await _privateItem(database, file.path);
      final manual = await categories.createRootCategory('Pessoal');
      await categories.replaceForMedia(item.id, {manual.id});
      final analyzer = _FakeVisualAnalyzer();
      final processor = _processor(
        analyzer: analyzer,
        resolver: LocalMediaOcrInputResolver(_FakeBridge(file.path)),
        categories: categories,
        suggestions: suggestions,
        ocr: _FakeOcrRepository(
          _ocr(item.id, 'amazon.com.br livro capa comum'),
        ),
      );

      final result = await processor.reprocess(item);

      expect(result.status, IndividualReprocessStatus.preservedManual);
      expect(analyzer.paths, isEmpty);
      expect((await categories.loadForMedia(item.id)).single.name, 'Pessoal');
      await processor.close();
    },
  );
}

ContextualClassificationProcessor _processor({
  required LocalVisualAnalyzer analyzer,
  required MediaOcrInputResolver resolver,
  required LocalCategoryRepository categories,
  required LocalClassificationSuggestionRepository suggestions,
  required OcrRepository ocr,
}) => ContextualClassificationProcessor(
  engine: const ContextualClassificationEngine(),
  visualAnalyzer: analyzer,
  inputResolver: resolver,
  repository: suggestions,
  categoryRepository: categories,
  ocrRepository: ocr,
  now: () => DateTime.utc(2026, 7, 19, 11),
  engineVersion: 1,
);

Future<MediaItem> _privateItem(ContextoDatabase database, String path) async {
  final store = DriftMediaItemStore(database);
  final id = await store.insertItem(
    privatePath: path,
    internalName: 'private.png',
    mimeType: 'image/png',
    mediaHash: 'hash',
    importedAt: DateTime.utc(2026, 7, 19),
    capturedAt: DateTime.utc(2026, 7, 19),
    sourceMode: 'photoPicker',
    status: 'ready',
    importOrigin: ImportOrigin.picker,
  );
  return (await store.findById(id))!;
}

Future<MediaItem> _referencedItem(ContextoDatabase database) async {
  final store = DriftMediaItemStore(database);
  final id = await store.insertMediaStoreReference(
    location: MediaStoreReferenceLocation(
      sourceKey: 'external_primary:42',
      mediaStoreId: 42,
      volumeName: 'external_primary',
      contentUri: 'content://media/external_primary/images/media/42',
    ),
    mimeType: 'image/png',
    importedAt: DateTime.utc(2026, 7, 19),
    capturedAt: DateTime.utc(2026, 7, 19),
    sourceMode: 'mediaStoreReference',
    status: 'ready',
  );
  return (await store.findById(id))!;
}

OcrResult _ocr(int mediaItemId, String text) => OcrResult(
  mediaItemId: mediaItemId,
  fullText: text,
  engine: 'test',
  engineVersion: '1',
  processedAt: DateTime.utc(2026, 7, 19, 10),
);

class _FakeVisualAnalyzer implements LocalVisualAnalyzer {
  _FakeVisualAnalyzer({this.error});

  final Object? error;
  final List<String> paths = [];
  bool closed = false;

  @override
  Future<VisualAnalysisResult> analyze(String localPath) async {
    paths.add(localPath);
    if (error != null) throw error!;
    return VisualAnalysisResult(
      labels: [VisualLabel(key: 'book', confidence: 0.90)],
      analyzerVersion: 'test',
    );
  }

  @override
  Future<void> close() async => closed = true;
}

class _FakeBridge implements MediaStoreOcrInputBridge {
  _FakeBridge(this.path);

  final String path;
  final List<MediaStoreReferenceLocation> preparedLocations = [];
  final List<String> releasedTokens = [];

  @override
  Future<ReferencedOcrInput> prepare(
    MediaStoreReferenceLocation location,
  ) async {
    preparedLocations.add(location);
    return ReferencedOcrInput(localPath: path, token: 'visual-token');
  }

  @override
  Future<void> release(String token) async => releasedTokens.add(token);
}

class _FakeOcrRepository implements OcrRepository {
  _FakeOcrRepository(this.result);

  final OcrResult result;

  @override
  Future<OcrResult?> loadFor(int mediaItemId) async => result;

  @override
  Future<OcrResult> process(MediaItem mediaItem) async => result;
}

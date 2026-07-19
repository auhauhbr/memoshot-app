import 'dart:io';

import 'package:memoshot/core/database/contexto_database.dart'
    show ContextoDatabase;
import 'package:memoshot/core/media/screenshot_storage.dart';
import 'package:memoshot/features/library/data/media_item_repository.dart';
import 'package:memoshot/features/library/data/media_item_store.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/ocr/data/ocr_result_store.dart';
import 'package:memoshot/features/ocr/domain/ocr_result.dart';
import 'package:memoshot/features/tags/data/tag_repository.dart';
import 'package:memoshot/features/tags/data/tag_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late ContextoDatabase database;
  late DriftMediaItemStore mediaStore;
  late DriftOcrResultStore ocrStore;
  late LocalMediaItemRepository repository;
  late LocalTagRepository tagRepository;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'memoshot_search_test_',
    );
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    mediaStore = DriftMediaItemStore(database);
    ocrStore = DriftOcrResultStore(database);
    repository = LocalMediaItemRepository(
      store: mediaStore,
      storage: PrivateScreenshotStorage(
        documentsDirectory: () async => temporaryDirectory,
      ),
    );
    tagRepository = LocalTagRepository(store: DriftTagStore(database));
  });

  tearDown(() async {
    await repository.close();
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('localiza termo simples ignorando maiúsculas e acentos', () async {
    final item = await persistItem(
      mediaStore,
      ocrStore,
      temporaryDirectory,
      idMarker: 1,
      importedAt: DateTime(2026),
      text: 'ENTREVISTA com João e código de acesso',
    );

    expect(
      (await repository.searchRecognizedText('entrevista')).single.mediaItem.id,
      item.id,
    );
    expect(
      (await repository.searchRecognizedText('joao')).single.mediaItem.id,
      item.id,
    );
    final byCode = await repository.searchRecognizedText('codigo');
    expect(byCode.single.mediaItem.id, item.id);
    expect(byCode.single.snippet, contains('código'));
  });

  test('consulta composta respeita ordem e ignora espaços repetidos', () async {
    final matching = await persistItem(
      mediaStore,
      ocrStore,
      temporaryDirectory,
      idMarker: 2,
      importedAt: DateTime(2026, 2),
      text: 'Notebook com RTX   4050 disponível',
    );
    await persistItem(
      mediaStore,
      ocrStore,
      temporaryDirectory,
      idMarker: 3,
      importedAt: DateTime(2026, 1),
      text: 'Modelo 4050 sem a sigla pesquisada antes',
    );

    final results = await repository.searchRecognizedText('  RTX  4050 ');

    expect(results.map((result) => result.mediaItem.id), [matching.id]);
  });

  test(
    'retorna múltiplos resultados recentes e exclui incompatíveis',
    () async {
      final older = await persistItem(
        mediaStore,
        ocrStore,
        temporaryDirectory,
        idMarker: 4,
        importedAt: DateTime(2025),
        text: 'Reunião do projeto local',
      );
      final newer = await persistItem(
        mediaStore,
        ocrStore,
        temporaryDirectory,
        idMarker: 5,
        importedAt: DateTime(2026),
        text: 'Projeto atualizado',
      );
      await persistItem(
        mediaStore,
        ocrStore,
        temporaryDirectory,
        idMarker: 6,
        importedAt: DateTime(2027),
        text: 'Conteúdo incompatível',
      );

      final results = await repository.searchRecognizedText('projeto');

      expect(results.map((result) => result.mediaItem.id), [
        newer.id,
        older.id,
      ]);
    },
  );

  test('resultados seguem captured_at e desempates determinísticos', () async {
    final sameCapture = DateTime(2026, 3, 2);
    final oldestCapture = await persistItem(
      mediaStore,
      ocrStore,
      temporaryDirectory,
      idMarker: 30,
      importedAt: DateTime(2026, 3, 5),
      capturedAt: DateTime(2026, 3, 1),
      text: 'ordenação cronológica',
    );
    final olderImport = await persistItem(
      mediaStore,
      ocrStore,
      temporaryDirectory,
      idMarker: 31,
      importedAt: DateTime(2026, 3, 3),
      capturedAt: sameCapture,
      text: 'ordenação cronológica',
    );
    final newerImport = await persistItem(
      mediaStore,
      ocrStore,
      temporaryDirectory,
      idMarker: 32,
      importedAt: DateTime(2026, 3, 4),
      capturedAt: sameCapture,
      text: 'ordenação cronológica',
    );

    final results = await repository.searchRecognizedText('cronologica');

    expect(results.map((result) => result.mediaItem.id), [
      newerImport.id,
      olderImport.id,
      oldestCapture.id,
    ]);
  });

  test('respeita limite seguro de resultados', () async {
    for (var marker = 7; marker < 12; marker++) {
      await persistItem(
        mediaStore,
        ocrStore,
        temporaryDirectory,
        idMarker: marker,
        importedAt: DateTime(2026, 1, marker),
        text: 'resultado comum $marker',
      );
    }

    final results = await repository.searchRecognizedText('comum', limit: 2);

    expect(results, hasLength(2));
    expect(results.first.mediaItem.importedAt.day, 11);
  });

  test('ignora item cujo arquivo privado não existe', () async {
    final missing = await persistItem(
      mediaStore,
      ocrStore,
      temporaryDirectory,
      idMarker: 12,
      importedAt: DateTime(2026),
      text: 'termo ausente',
    );
    File(missing.privatePath!).deleteSync();

    expect(await repository.searchRecognizedText('termo'), isEmpty);
  });

  test('consulta vazia ou somente com espaços não inicia busca', () async {
    expect(await repository.searchRecognizedText(''), isEmpty);
    expect(await repository.searchRecognizedText('   \n  '), isEmpty);
  });

  test('consulta sem tagId preserva todos os itens', () async {
    final older = await persistItem(
      mediaStore,
      ocrStore,
      temporaryDirectory,
      idMarker: 40,
      importedAt: DateTime(2026, 1),
      text: 'texto comum',
    );
    final newer = await persistItem(
      mediaStore,
      ocrStore,
      temporaryDirectory,
      idMarker: 41,
      importedAt: DateTime(2026, 2),
      text: 'texto comum',
    );

    expect((await repository.loadAvailableItems()).map((item) => item.id), [
      newer.id,
      older.id,
    ]);
  });

  test(
    'tagId filtra texto vazio e tag inexistente não retorna itens',
    () async {
      final item = await persistItem(
        mediaStore,
        ocrStore,
        temporaryDirectory,
        idMarker: 42,
        importedAt: DateTime(2026),
        text: 'conteúdo',
      );
      final tag = await tagRepository.createTag('Trabalho');
      await tagRepository.addToMedia(tagId: tag.id, mediaItemId: item.id);

      expect(
        (await repository.loadAvailableItems(tagId: tag.id)).single.id,
        item.id,
      );
      expect(await repository.loadAvailableItems(tagId: 9999), isEmpty);
    },
  );

  test('pesquisa textual e tagId são combinados com AND', () async {
    final matching = await persistItem(
      mediaStore,
      ocrStore,
      temporaryDirectory,
      idMarker: 43,
      importedAt: DateTime(2026, 2),
      text: 'projeto azul',
    );
    final onlyText = await persistItem(
      mediaStore,
      ocrStore,
      temporaryDirectory,
      idMarker: 44,
      importedAt: DateTime(2026, 3),
      text: 'projeto verde',
    );
    final onlyTag = await persistItem(
      mediaStore,
      ocrStore,
      temporaryDirectory,
      idMarker: 45,
      importedAt: DateTime(2026, 4),
      text: 'outro conteúdo',
    );
    final tag = await tagRepository.createTag('Projetos');
    await tagRepository.addToMedia(tagId: tag.id, mediaItemId: matching.id);
    await tagRepository.addToMedia(tagId: tag.id, mediaItemId: onlyTag.id);

    final results = await repository.searchRecognizedText(
      'projeto',
      tagId: tag.id,
    );

    expect(results.map((result) => result.mediaItem.id), [matching.id]);
    expect(
      results.map((result) => result.mediaItem.id),
      isNot(contains(onlyText.id)),
    );
  });

  test(
    'item com várias etiquetas aparece uma vez e mantém ordenação',
    () async {
      final older = await persistItem(
        mediaStore,
        ocrStore,
        temporaryDirectory,
        idMarker: 46,
        importedAt: DateTime(2026, 4),
        capturedAt: DateTime(2026, 1),
        text: 'termo compartilhado',
      );
      final newer = await persistItem(
        mediaStore,
        ocrStore,
        temporaryDirectory,
        idMarker: 47,
        importedAt: DateTime(2026, 1),
        capturedAt: DateTime(2026, 2),
        text: 'termo compartilhado',
      );
      final selected = await tagRepository.createTag('Selecionada');
      final extra = await tagRepository.createTag('Extra');
      for (final item in [older, newer]) {
        await tagRepository.addToMedia(
          tagId: selected.id,
          mediaItemId: item.id,
        );
      }
      await tagRepository.addToMedia(tagId: extra.id, mediaItemId: newer.id);

      final results = await repository.searchRecognizedText(
        'termo',
        tagId: selected.id,
      );

      expect(results.map((result) => result.mediaItem.id), [
        newer.id,
        older.id,
      ]);
    },
  );

  test(
    'remover vínculo retira resultado e excluir tag preserva item',
    () async {
      final item = await persistItem(
        mediaStore,
        ocrStore,
        temporaryDirectory,
        idMarker: 48,
        importedAt: DateTime(2026),
        text: 'preservar screenshot',
      );
      final tag = await tagRepository.createTag('Temporária');
      await tagRepository.addToMedia(tagId: tag.id, mediaItemId: item.id);
      expect(await repository.loadAvailableItems(tagId: tag.id), hasLength(1));

      await tagRepository.removeFromMedia(tagId: tag.id, mediaItemId: item.id);
      expect(await repository.loadAvailableItems(tagId: tag.id), isEmpty);
      await tagRepository.addToMedia(tagId: tag.id, mediaItemId: item.id);
      await tagRepository.deleteTag(tag.id);

      expect(await repository.loadAvailableItems(tagId: tag.id), isEmpty);
      expect((await repository.loadAvailableItems()).single.id, item.id);
      expect(File(item.privatePath!).existsSync(), isTrue);
    },
  );
}

Future<MediaItem> persistItem(
  DriftMediaItemStore mediaStore,
  DriftOcrResultStore ocrStore,
  Directory directory, {
  required int idMarker,
  required DateTime importedAt,
  DateTime? capturedAt,
  required String text,
}) async {
  final file = File('${directory.path}/search-$idMarker.png')
    ..writeAsBytesSync([1, 2, idMarker]);
  final id = await mediaStore.insertItem(
    privatePath: file.path,
    internalName: 'search-$idMarker.png',
    mimeType: 'image/png',
    mediaHash: 'search-hash-$idMarker',
    importedAt: importedAt,
    capturedAt: capturedAt,
    sourceMode: 'photoPicker',
    status: 'ready',
  );
  await ocrStore.save(
    OcrResult(
      mediaItemId: id,
      fullText: text,
      engine: 'Serviço falso',
      engineVersion: 'teste',
      processedAt: importedAt,
    ),
  );
  return MediaItem(
    id: id,
    privatePath: file.path,
    internalName: 'search-$idMarker.png',
    mimeType: 'image/png',
    mediaHash: 'search-hash-$idMarker',
    importedAt: importedAt,
    capturedAt: capturedAt,
    sourceMode: 'photoPicker',
    status: 'ready',
  );
}

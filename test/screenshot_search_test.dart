import 'dart:io';

import 'package:contexto/core/database/contexto_database.dart'
    show ContextoDatabase;
import 'package:contexto/core/media/screenshot_storage.dart';
import 'package:contexto/features/library/data/media_item_repository.dart';
import 'package:contexto/features/library/data/media_item_store.dart';
import 'package:contexto/features/library/domain/media_item.dart';
import 'package:contexto/features/ocr/data/ocr_result_store.dart';
import 'package:contexto/features/ocr/domain/ocr_result.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late ContextoDatabase database;
  late DriftMediaItemStore mediaStore;
  late DriftOcrResultStore ocrStore;
  late LocalMediaItemRepository repository;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'contexto_search_test_',
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
    File(missing.privatePath).deleteSync();

    expect(await repository.searchRecognizedText('termo'), isEmpty);
  });

  test('consulta vazia ou somente com espaços não inicia busca', () async {
    expect(await repository.searchRecognizedText(''), isEmpty);
    expect(await repository.searchRecognizedText('   \n  '), isEmpty);
  });
}

Future<MediaItem> persistItem(
  DriftMediaItemStore mediaStore,
  DriftOcrResultStore ocrStore,
  Directory directory, {
  required int idMarker,
  required DateTime importedAt,
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
    sourceMode: 'photoPicker',
    status: 'ready',
  );
}

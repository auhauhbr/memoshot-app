import 'dart:io';

import 'package:contexto/core/database/contexto_database.dart'
    show ContextoDatabase;
import 'package:contexto/core/ocr/text_recognition_service.dart';
import 'package:contexto/features/library/data/media_item_store.dart';
import 'package:contexto/features/library/domain/media_item.dart';
import 'package:contexto/features/ocr/data/ocr_repository.dart';
import 'package:contexto/features/ocr/data/ocr_result_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late ContextoDatabase database;
  late DriftMediaItemStore mediaStore;
  late DriftOcrResultStore ocrStore;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'contexto_ocr_test_',
    );
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    mediaStore = DriftMediaItemStore(database);
    ocrStore = DriftOcrResultStore(database);
  });

  tearDown(() async {
    await database.close();
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('serviço falso retorna texto e resultado é salvo', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 1);
    final service = FakeTextRecognitionService(texts: ['Texto fictício']);
    final repository = LocalOcrRepository(
      store: ocrStore,
      recognitionService: service,
    );

    final result = await repository.process(item);
    final persisted = await repository.loadFor(item.id);

    expect(result.fullText, 'Texto fictício');
    expect(persisted?.fullText, 'Texto fictício');
    expect(persisted?.normalizedText, 'texto ficticio');
    expect(service.callCount, 1);
  });

  test('resultado vazio é salvo como processado', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 2);
    final repository = LocalOcrRepository(
      store: ocrStore,
      recognitionService: FakeTextRecognitionService(texts: ['']),
    );

    await repository.process(item);

    final persisted = await repository.loadFor(item.id);
    expect(persisted, isNotNull);
    expect(persisted?.fullText, isEmpty);
    expect(persisted?.normalizedText, isEmpty);
  });

  test('resultado existente é carregado sem executar OCR novamente', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 3);
    final service = FakeTextRecognitionService(texts: ['Persistido']);
    final repository = LocalOcrRepository(
      store: ocrStore,
      recognitionService: service,
    );
    await repository.process(item);

    final reopenedRepository = LocalOcrRepository(
      store: ocrStore,
      recognitionService: FakeTextRecognitionService(
        error: StateError('não deve executar'),
      ),
    );
    final persisted = await reopenedRepository.loadFor(item.id);

    expect(persisted?.fullText, 'Persistido');
    expect(service.callCount, 1);
  });

  test('reprocessamento substitui o resultado anterior', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 4);
    final service = FakeTextRecognitionService(texts: ['Primeiro', 'Segundo']);
    final repository = LocalOcrRepository(
      store: ocrStore,
      recognitionService: service,
    );

    await repository.process(item);
    await repository.process(item);

    final persisted = await repository.loadFor(item.id);
    expect(persisted?.fullText, 'Segundo');
    expect(persisted?.normalizedText, 'segundo');
    expect(service.callCount, 2);
  });

  test('erro do serviço não cria resultado falso', () async {
    final item = await createMediaItem(mediaStore, temporaryDirectory, 5);
    final repository = LocalOcrRepository(
      store: ocrStore,
      recognitionService: FakeTextRecognitionService(
        error: StateError('conteúdo privado'),
      ),
    );

    await expectLater(repository.process(item), throwsStateError);

    expect(await repository.loadFor(item.id), isNull);
  });

  test('arquivo ausente impede processamento sem chamar o serviço', () async {
    final service = FakeTextRecognitionService(texts: ['não deve aparecer']);
    final repository = LocalOcrRepository(
      store: ocrStore,
      recognitionService: service,
    );
    final item = MediaItem(
      id: 99,
      privatePath: '${temporaryDirectory.path}/ausente.png',
      internalName: 'ausente.png',
      importedAt: DateTime(2026),
      sourceMode: 'photoPicker',
      status: 'ready',
    );

    await expectLater(
      repository.process(item),
      throwsA(isA<FileSystemException>()),
    );

    expect(service.callCount, 0);
    expect(await repository.loadFor(item.id), isNull);
  });
}

class FakeTextRecognitionService implements TextRecognitionService {
  FakeTextRecognitionService({this.texts = const [], this.error});

  final List<String> texts;
  final Object? error;
  int callCount = 0;

  @override
  Future<TextRecognitionOutput> recognize(String imagePath) async {
    final callIndex = callCount++;
    if (error != null) {
      throw error!;
    }
    return TextRecognitionOutput(
      fullText: texts[callIndex],
      engine: 'Serviço falso',
      engineVersion: 'teste',
    );
  }
}

Future<MediaItem> createMediaItem(
  DriftMediaItemStore store,
  Directory directory,
  int marker,
) async {
  final file = File('${directory.path}/imagem-$marker.png')
    ..writeAsBytesSync([1, 2, marker]);
  final id = await store.insertItem(
    privatePath: file.path,
    internalName: 'imagem-$marker.png',
    mimeType: 'image/png',
    mediaHash: 'hash-$marker',
    importedAt: DateTime(2026),
    sourceMode: 'photoPicker',
    status: 'ready',
  );
  return MediaItem(
    id: id,
    privatePath: file.path,
    internalName: 'imagem-$marker.png',
    mimeType: 'image/png',
    mediaHash: 'hash-$marker',
    importedAt: DateTime(2026),
    sourceMode: 'photoPicker',
    status: 'ready',
  );
}

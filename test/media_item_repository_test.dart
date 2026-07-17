import 'dart:convert';
import 'dart:io';

import 'package:contexto/core/database/contexto_database.dart'
    show ContextoDatabase;
import 'package:contexto/core/media/screenshot_storage.dart';
import 'package:contexto/features/library/data/media_item_repository.dart';
import 'package:contexto/features/library/data/media_item_store.dart';
import 'package:contexto/features/library/domain/media_item.dart';
import 'package:contexto/features/library/domain/selected_screenshot.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late Directory privateDirectory;
  late ContextoDatabase database;
  late DriftMediaItemStore store;
  late PrivateScreenshotStorage storage;
  late LocalMediaItemRepository repository;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'contexto_repository_test_',
    );
    privateDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}private',
    )..createSync();
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    store = DriftMediaItemStore(database);
    storage = PrivateScreenshotStorage(
      documentsDirectory: () async => privateDirectory,
    );
    repository = LocalMediaItemRepository(store: store, storage: storage);
  });

  tearDown(() async {
    await repository.close();
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('grava e lê um item persistido', () async {
    final original = createTestImage(temporaryDirectory, 'original.png');

    final imported = await repository.importScreenshots([
      SelectedScreenshot(path: original.path, mimeType: 'image/png'),
    ]);
    final loaded = await repository.loadAvailableItems();

    expect(imported, hasLength(1));
    expect(loaded, hasLength(1));
    expect(loaded.single.id, imported.single.id);
    expect(loaded.single.sourceMode, 'photoPicker');
    expect(loaded.single.status, 'ready');
    expect(loaded.single.mimeType, 'image/png');
    expect(File(loaded.single.privatePath).existsSync(), isTrue);
  });

  test('persiste múltiplos itens', () async {
    final first = createTestImage(temporaryDirectory, 'primeira.png');
    final second = createTestImage(temporaryDirectory, 'segunda.png');

    await repository.importScreenshots([
      SelectedScreenshot(path: first.path),
      SelectedScreenshot(path: second.path),
    ]);

    expect(await repository.loadAvailableItems(), hasLength(2));
  });

  test('mantém o arquivo original intacto', () async {
    final original = createTestImage(temporaryDirectory, 'intacta.png');
    final originalBytes = original.readAsBytesSync();

    final imported = await repository.importScreenshots([
      SelectedScreenshot(path: original.path),
    ]);

    expect(original.existsSync(), isTrue);
    expect(original.readAsBytesSync(), originalBytes);
    expect(imported.single.privatePath, isNot(original.path));
    expect(File(imported.single.privatePath).readAsBytesSync(), originalBytes);
  });

  test('não grava item quando a cópia falha', () async {
    final missingPath =
        '${temporaryDirectory.path}${Platform.pathSeparator}ausente.png';

    await expectLater(
      repository.importScreenshots([SelectedScreenshot(path: missingPath)]),
      throwsA(isA<FileSystemException>()),
    );

    expect(await store.readItems(), isEmpty);
  });

  test('remove a cópia privada quando a gravação no banco falha', () async {
    final original = createTestImage(temporaryDirectory, 'falha-banco.png');
    final failingRepository = LocalMediaItemRepository(
      store: FailingMediaItemStore(),
      storage: storage,
    );

    await expectLater(
      failingRepository.importScreenshots([
        SelectedScreenshot(path: original.path),
      ]),
      throwsStateError,
    );

    final screenshotsDirectory = Directory(
      '${privateDirectory.path}${Platform.pathSeparator}screenshots',
    );
    expect(screenshotsDirectory.existsSync(), isTrue);
    expect(screenshotsDirectory.listSync(), isEmpty);
    expect(original.existsSync(), isTrue);
  });

  test('ignora registro cujo arquivo privado não existe', () async {
    final missingPath =
        '${privateDirectory.path}${Platform.pathSeparator}inexistente.png';
    await store.insertItem(
      privatePath: missingPath,
      internalName: 'inexistente.png',
      mimeType: 'image/png',
      importedAt: DateTime(2026),
      sourceMode: 'photoPicker',
      status: 'ready',
    );

    expect(await repository.loadAvailableItems(), isEmpty);
  });
}

class FailingMediaItemStore implements MediaItemStore {
  @override
  Future<int> insertItem({
    required String privatePath,
    required String internalName,
    required String? mimeType,
    required DateTime importedAt,
    required String sourceMode,
    required String status,
  }) {
    throw StateError('Falha simulada no banco');
  }

  @override
  Future<List<MediaItem>> readItems() async => const [];

  @override
  Future<void> close() async {}
}

File createTestImage(Directory directory, String name) {
  const minimalPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
  return File('${directory.path}${Platform.pathSeparator}$name')
    ..writeAsBytesSync(base64Decode(minimalPng));
}

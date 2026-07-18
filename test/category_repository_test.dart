import 'dart:io';

import 'package:contexto/core/database/contexto_database.dart';
import 'package:contexto/features/categories/data/category_repository.dart';
import 'package:contexto/features/categories/data/category_store.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ContextoDatabase database;
  late LocalCategoryRepository repository;
  late int mediaItemId;

  setUp(() async {
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    repository = LocalCategoryRepository(store: DriftCategoryStore(database));
    mediaItemId = await database
        .into(database.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            privatePath: '/tmp/imagem-ficticia.png',
            internalName: 'imagem.png',
            importedAt: DateTime(2025),
            sourceMode: 'photoPicker',
            status: 'ready',
          ),
        );
  });

  tearDown(() => database.close());

  test('cria, lista e preserva o nome visível', () async {
    final created = await repository.createCategory('  Carrêira  ');
    final categories = await repository.loadCategories();

    expect(created.name, 'Carrêira');
    expect(created.normalizedName, 'carreira');
    expect(categories.single.category.name, 'Carrêira');
    expect(categories.single.mediaCount, 0);
  });

  test('rejeita nome vazio ou composto somente por espaços', () async {
    for (final name in ['', '   ']) {
      await expectLater(
        repository.createCategory(name),
        throwsA(
          isA<CategoryValidationException>().having(
            (error) => error.error,
            'erro',
            CategoryValidationError.empty,
          ),
        ),
      );
    }
  });

  test('impede categorias equivalentes após normalização', () async {
    await repository.createCategory('Carreira');
    for (final duplicate in ['carreira', ' Carrêira ']) {
      await expectLater(
        repository.createCategory(duplicate),
        throwsA(
          isA<CategoryValidationException>().having(
            (error) => error.error,
            'erro',
            CategoryValidationError.duplicate,
          ),
        ),
      );
    }
    expect(await repository.loadCategories(), hasLength(1));
  });

  test('impede criação duplicada concorrente pelo banco', () async {
    final outcomes = await Future.wait([
      repository
          .createCategory('Projetos')
          .then<Object>((value) => value)
          .catchError((Object error) => error),
      repository
          .createCategory(' prójetos ')
          .then<Object>((value) => value)
          .catchError((Object error) => error),
    ]);

    expect(outcomes.whereType<CategoryValidationException>(), hasLength(1));
    expect(await repository.loadCategories(), hasLength(1));
  });

  test('associa várias categorias sem duplicar associações', () async {
    final first = await repository.createCategory('Trabalho');
    final second = await repository.createCategory('Estudos');

    await repository.replaceForMedia(mediaItemId, {first.id, second.id});
    await repository.replaceForMedia(mediaItemId, {first.id, second.id});

    expect(await repository.loadForMedia(mediaItemId), hasLength(2));
    final summaries = await repository.loadCategories();
    expect(summaries.map((summary) => summary.mediaCount), everyElement(1));
    expect(await database.select(database.mediaCategories).get(), hasLength(2));
  });

  test('chave composta impede associação duplicada', () async {
    final category = await repository.createCategory('Única');
    final association = MediaCategoriesCompanion.insert(
      mediaItemId: mediaItemId,
      categoryId: category.id,
      createdAt: DateTime(2025),
    );
    await database.into(database.mediaCategories).insert(association);

    await expectLater(
      database.into(database.mediaCategories).insert(association),
      throwsA(anything),
    );
    expect(await database.select(database.mediaCategories).get(), hasLength(1));
  });

  test('desassocia sem remover screenshot ou categoria', () async {
    final first = await repository.createCategory('Trabalho');
    final second = await repository.createCategory('Estudos');
    await repository.replaceForMedia(mediaItemId, {first.id, second.id});

    await repository.replaceForMedia(mediaItemId, {second.id});

    expect((await repository.loadForMedia(mediaItemId)).single.id, second.id);
    expect(await database.select(database.mediaItems).get(), hasLength(1));
    expect(await repository.loadCategories(), hasLength(2));
  });

  test('remoção do screenshot elimina associações', () async {
    final category = await repository.createCategory('Recibos');
    await repository.replaceForMedia(mediaItemId, {category.id});

    await (database.delete(
      database.mediaItems,
    )..where((item) => item.id.equals(mediaItemId))).go();

    expect(await database.select(database.mediaCategories).get(), isEmpty);
    expect(await repository.loadCategories(), hasLength(1));
  });

  test('atualização múltipla faz rollback em falha', () async {
    final category = await repository.createCategory('Importante');
    await repository.replaceForMedia(mediaItemId, {category.id});

    await expectLater(
      repository.replaceForMedia(mediaItemId, {99999}),
      throwsA(anything),
    );

    expect((await repository.loadForMedia(mediaItemId)).single.id, category.id);
  });

  test('categorias persistem ao recriar o repositório', () async {
    await repository.createCategory('Persistente');
    final recreated = LocalCategoryRepository(
      store: DriftCategoryStore(database),
    );

    expect(
      (await recreated.loadCategories()).single.category.name,
      'Persistente',
    );
  });

  test('renomeia categoria, normaliza e preserva associações', () async {
    final category = await repository.createCategory('Trabalho');
    await repository.replaceForMedia(mediaItemId, {category.id});

    final renamed = await repository.renameCategory(category, '  Prójetos  ');

    expect(renamed.name, 'Prójetos');
    expect(renamed.normalizedName, 'projetos');
    expect((await repository.loadForMedia(mediaItemId)).single.id, category.id);
  });

  test('permite manter o próprio nome ao renomear', () async {
    final category = await repository.createCategory('Carreira');

    final renamed = await repository.renameCategory(category, 'Carreira');

    expect(renamed.name, 'Carreira');
    expect(await repository.loadCategories(), hasLength(1));
  });

  test(
    'renomeação rejeita nome vazio e equivalente a outra categoria',
    () async {
      final first = await repository.createCategory('Carreira');
      await repository.createCategory('Estudos');

      await expectLater(
        repository.renameCategory(first, '   '),
        throwsA(
          isA<CategoryValidationException>().having(
            (error) => error.error,
            'erro',
            CategoryValidationError.empty,
          ),
        ),
      );
      await expectLater(
        repository.renameCategory(first, ' estúdos '),
        throwsA(
          isA<CategoryValidationException>().having(
            (error) => error.error,
            'erro',
            CategoryValidationError.duplicate,
          ),
        ),
      );
      expect(
        (await repository.loadCategories()).first.category.name,
        'Carreira',
      );
    },
  );

  test('excluir categoria remove associações e preserva media_item', () async {
    final category = await repository.createCategory('Temporária');
    await repository.replaceForMedia(mediaItemId, {category.id});
    await database
        .into(database.ocrResults)
        .insert(
          OcrResultsCompanion.insert(
            mediaItemId: Value(mediaItemId),
            fullText: 'Texto fictício',
            engine: 'test',
            engineVersion: '1',
            processedAt: DateTime(2025),
          ),
        );

    await repository.deleteCategory(category.id);

    expect(await repository.loadCategories(), isEmpty);
    expect(await database.select(database.mediaCategories).get(), isEmpty);
    expect(await database.select(database.mediaItems).get(), hasLength(1));
    expect(await database.select(database.ocrResults).get(), hasLength(1));
  });

  test('excluir categoria preserva cópia privada e arquivo original', () async {
    final directory = Directory.systemTemp.createTempSync('contexto_category_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final privateCopy = File('${directory.path}/private.png')
      ..writeAsStringSync('private');
    final original = File('${directory.path}/original.png')
      ..writeAsStringSync('original');
    final itemId = await database
        .into(database.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            privatePath: privateCopy.path,
            internalName: 'private.png',
            importedAt: DateTime(2026),
            sourceMode: 'photoPicker',
            status: 'ready',
          ),
        );
    final category = await repository.createCategory('Preservar');
    await repository.replaceForMedia(itemId, {category.id});

    await repository.deleteCategory(category.id);

    expect(privateCopy.existsSync(), isTrue);
    expect(original.existsSync(), isTrue);
    expect(
      await (database.select(
        database.mediaItems,
      )..where((item) => item.id.equals(itemId))).getSingleOrNull(),
      isNotNull,
    );
  });

  test('lista screenshots recentes e ignora cópia ausente', () async {
    final directory = Directory.systemTemp.createTempSync('contexto_filter_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final oldFile = File('${directory.path}/old.png')..writeAsStringSync('old');
    final newFile = File('${directory.path}/new.png')..writeAsStringSync('new');
    final oldId = await database
        .into(database.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            privatePath: oldFile.path,
            internalName: 'old.png',
            importedAt: DateTime(2024),
            sourceMode: 'photoPicker',
            status: 'ready',
          ),
        );
    final newId = await database
        .into(database.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            privatePath: newFile.path,
            internalName: 'new.png',
            importedAt: DateTime(2026),
            sourceMode: 'photoPicker',
            status: 'ready',
          ),
        );
    final category = await repository.createCategory('Ordenada');
    await repository.replaceForMedia(mediaItemId, {category.id});
    await repository.replaceForMedia(oldId, {category.id});
    await repository.replaceForMedia(newId, {category.id});

    final items = await repository.loadMediaForCategory(category.id);

    expect(items.map((item) => item.id), [newId, oldId]);
  });
}

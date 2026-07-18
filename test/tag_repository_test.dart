import 'dart:io';

import 'package:contexto/core/database/contexto_database.dart';
import 'package:contexto/features/tags/data/tag_repository.dart';
import 'package:contexto/features/tags/data/tag_store.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ContextoDatabase database;
  late LocalTagRepository repository;
  late Directory directory;
  late int firstMediaId;
  late int secondMediaId;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('contexto_tags_');
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    repository = LocalTagRepository(store: DriftTagStore(database));
    firstMediaId = await _insertMedia(database, directory, 'primeiro.png', 1);
    secondMediaId = await _insertMedia(database, directory, 'segundo.png', 2);
  });

  tearDown(() async {
    await database.close();
    directory.deleteSync(recursive: true);
  });

  test('cria, lista e encontra etiqueta por id e nome normalizado', () async {
    final urgent = await repository.createTag('  Urgente  ');
    await repository.createTag('Compras');

    expect(urgent.name, 'Urgente');
    expect(urgent.normalizedName, 'urgente');
    expect(urgent.createdAt, urgent.updatedAt);
    expect((await repository.findById(urgent.id))?.name, 'Urgente');
    expect((await repository.findByNormalizedName(' URGENTE '))?.id, urgent.id);
    expect((await repository.loadTags()).map((tag) => tag.name), [
      'Compras',
      'Urgente',
    ]);
  });

  test(
    'normaliza apenas para comparação e preserva acentos visíveis',
    () async {
      final tag = await repository.createTag('  Atenção Máxima  ');

      expect(tag.name, 'Atenção Máxima');
      expect(tag.normalizedName, 'atencao maxima');
    },
  );

  test('rejeita nome vazio e nomes logicamente duplicados', () async {
    await repository.createTag('Urgente');

    await expectLater(
      repository.createTag('   '),
      throwsA(
        isA<TagValidationException>().having(
          (error) => error.error,
          'erro',
          TagValidationError.empty,
        ),
      ),
    );
    for (final duplicate in [' urgente ', 'URGENTE']) {
      await expectLater(
        repository.createTag(duplicate),
        throwsA(
          isA<TagValidationException>().having(
            (error) => error.error,
            'erro',
            TagValidationError.duplicate,
          ),
        ),
      );
    }
    expect(await repository.loadTags(), hasLength(1));
  });

  test('unicidade do banco protege contra criação concorrente', () async {
    final outcomes = await Future.wait([
      repository
          .createTag('Revisar')
          .then<Object>((value) => value)
          .catchError((Object error) => error),
      repository
          .createTag(' revisar ')
          .then<Object>((value) => value)
          .catchError((Object error) => error),
    ]);

    expect(outcomes.whereType<TagValidationException>(), hasLength(1));
    expect(await repository.loadTags(), hasLength(1));
  });

  test('renomeia etiqueta e atualiza o nome normalizado', () async {
    final tag = await repository.createTag('Responder');

    await Future<void>.delayed(const Duration(milliseconds: 1));
    final renamed = await repository.renameTag(tag, '  Próxima ação  ');

    expect(renamed.id, tag.id);
    expect(renamed.name, 'Próxima ação');
    expect(renamed.normalizedName, 'proxima acao');
    expect(renamed.createdAt, tag.createdAt);
    expect(renamed.updatedAt.isAfter(tag.updatedAt), isTrue);
    expect((await repository.findById(tag.id))?.name, 'Próxima ação');
  });

  test('renomeação rejeita nome pertencente a outra etiqueta', () async {
    final first = await repository.createTag('Responder');
    await repository.createTag('Importante');

    await expectLater(
      repository.renameTag(first, ' importante '),
      throwsA(
        isA<TagValidationException>().having(
          (error) => error.error,
          'erro',
          TagValidationError.duplicate,
        ),
      ),
    );
    expect((await repository.findById(first.id))?.name, 'Responder');
  });

  test('um item aceita várias etiquetas sem duplicar associações', () async {
    final urgent = await repository.createTag('Urgente');
    final reply = await repository.createTag('Responder');

    await repository.addToMedia(tagId: urgent.id, mediaItemId: firstMediaId);
    await repository.addToMedia(tagId: reply.id, mediaItemId: firstMediaId);
    await repository.addToMedia(tagId: urgent.id, mediaItemId: firstMediaId);

    expect(await repository.loadForMedia(firstMediaId), hasLength(2));
    expect(await database.select(database.mediaTags).get(), hasLength(2));
    expect(
      await repository.isAssociated(
        tagId: urgent.id,
        mediaItemId: firstMediaId,
      ),
      isTrue,
    );
  });

  test('uma etiqueta pode estar associada a vários itens', () async {
    final urgent = await repository.createTag('Urgente');
    await repository.addToMedia(tagId: urgent.id, mediaItemId: firstMediaId);
    await repository.addToMedia(tagId: urgent.id, mediaItemId: secondMediaId);

    final items = await repository.loadMediaForTag(urgent.id);

    expect(items.map((item) => item.id).toSet(), {firstMediaId, secondMediaId});
  });

  test('remove associação sem excluir etiqueta, item ou arquivo', () async {
    final tag = await repository.createTag('Temporária');
    await repository.addToMedia(tagId: tag.id, mediaItemId: firstMediaId);
    final privateFile = File(
      (await (database.select(
            database.mediaItems,
          )..where((item) => item.id.equals(firstMediaId))).getSingle())
          .privatePath,
    );

    await repository.removeFromMedia(tagId: tag.id, mediaItemId: firstMediaId);

    expect(await repository.loadForMedia(firstMediaId), isEmpty);
    expect(await repository.findById(tag.id), isNotNull);
    expect(await database.select(database.mediaItems).get(), hasLength(2));
    expect(privateFile.existsSync(), isTrue);
  });

  test('excluir etiqueta remove relações e preserva mídia e OCR', () async {
    final tag = await repository.createTag('Descartar etiqueta');
    await repository.addToMedia(tagId: tag.id, mediaItemId: firstMediaId);
    await database
        .into(database.ocrResults)
        .insert(
          OcrResultsCompanion.insert(
            mediaItemId: Value(firstMediaId),
            fullText: 'Conteúdo fictício preservado',
            engine: 'test',
            engineVersion: '1',
            processedAt: DateTime(2026),
          ),
        );

    await repository.deleteTag(tag.id);

    expect(await repository.findById(tag.id), isNull);
    expect(await database.select(database.mediaTags).get(), isEmpty);
    expect(await database.select(database.mediaItems).get(), hasLength(2));
    expect(await database.select(database.ocrResults).get(), hasLength(1));
  });

  test('etiquetas e associações persistem ao reabrir o banco', () async {
    await database.close();
    final databaseFile = File('${directory.path}/persistencia.sqlite');
    database = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    repository = LocalTagRepository(store: DriftTagStore(database));
    firstMediaId = await _insertMedia(
      database,
      directory,
      'persistente.png',
      3,
    );
    final tag = await repository.createTag('Persistente');
    await repository.addToMedia(tagId: tag.id, mediaItemId: firstMediaId);
    await database.close();

    database = ContextoDatabase.forTesting(NativeDatabase(databaseFile));
    repository = LocalTagRepository(store: DriftTagStore(database));

    expect((await repository.loadTags()).single.name, 'Persistente');
    expect((await repository.loadForMedia(firstMediaId)).single.id, tag.id);
    expect((await repository.loadMediaForTag(tag.id)).single.id, firstMediaId);
  });
}

Future<int> _insertMedia(
  ContextoDatabase database,
  Directory directory,
  String name,
  int day,
) async {
  final file = File('${directory.path}/$name')..writeAsStringSync(name);
  return database
      .into(database.mediaItems)
      .insert(
        MediaItemsCompanion.insert(
          privatePath: file.path,
          internalName: name,
          importedAt: DateTime(2026, 1, day),
          sourceMode: 'photoPicker',
          status: 'ready',
        ),
      );
}

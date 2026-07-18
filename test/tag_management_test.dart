import 'dart:async';

import 'package:contexto/core/text/text_normalizer.dart';
import 'package:contexto/core/theme/app_theme.dart';
import 'package:contexto/features/library/domain/media_item.dart';
import 'package:contexto/features/tags/data/tag_repository.dart';
import 'package:contexto/features/tags/domain/tag.dart';
import 'package:contexto/features/tags/presentation/tags_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tela sem etiquetas mostra estado vazio e ação de criação', (
    tester,
  ) async {
    final repository = FakeManagementTagRepository();

    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Etiquetas'), findsOneWidget);
    expect(find.text('Nenhuma etiqueta criada.'), findsOneWidget);
    expect(find.byKey(const Key('new-tag-button')), findsOneWidget);
  });

  testWidgets('lista uma única etiqueta', (tester) async {
    final repository = FakeManagementTagRepository();
    final tag = await repository.createTag('Única');

    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('tag-tile-${tag.id}')), findsOneWidget);
    expect(find.text('Única'), findsOneWidget);
    expect(find.text('Nenhum screenshot'), findsOneWidget);
  });

  testWidgets('lista uma e várias etiquetas em ordem com contagens corretas', (
    tester,
  ) async {
    final repository = FakeManagementTagRepository();
    final zulu = await repository.createTag('Zulu');
    final action = await repository.createTag('Ação');
    final studies = await repository.createTag('Estudos');
    repository.seedAssociation(tagId: zulu.id, mediaItemId: 1);
    repository.seedAssociation(tagId: studies.id, mediaItemId: 1);
    repository.seedAssociation(tagId: studies.id, mediaItemId: 2);

    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('tag-tile-${action.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('tag-tile-${studies.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('tag-tile-${zulu.id}')), findsOneWidget);
    expect(find.text('Nenhum screenshot'), findsOneWidget);
    expect(find.text('1 screenshot'), findsOneWidget);
    expect(find.text('2 screenshots'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(ValueKey('tag-tile-${action.id}'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(ValueKey('tag-tile-${studies.id}'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(ValueKey('tag-tile-${studies.id}'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(ValueKey('tag-tile-${zulu.id}'))).dy,
      ),
    );
  });

  testWidgets('mostra carregamento sem permanecer bloqueada', (tester) async {
    final loadGate = Completer<void>();
    final repository = FakeManagementTagRepository(loadGate: loadGate);

    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pump();

    expect(find.byKey(const Key('tags-page-loading')), findsOneWidget);
    final createButton = tester.widget<FilledButton>(
      find.byKey(const Key('new-tag-button')),
    );
    expect(createButton.onPressed, isNull);

    loadGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma etiqueta criada.'), findsOneWidget);
  });

  testWidgets('erro de carregamento permite tentar novamente', (tester) async {
    final repository = FakeManagementTagRepository(loadFailures: 1);

    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar as etiquetas.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('retry-tags-button')));
    await tester.pumpAndSettle();

    expect(repository.loadSummaryCallCount, 2);
    expect(find.text('Nenhuma etiqueta criada.'), findsOneWidget);
  });

  testWidgets('abre criação, cria nome válido e atualiza imediatamente', (
    tester,
  ) async {
    final repository = FakeManagementTagRepository();
    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();

    await openCreateDialog(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('new-tag-name-field')),
    );
    expect(field.autofocus, isTrue);
    expect(field.textInputAction, TextInputAction.done);

    await tester.enterText(
      find.byKey(const Key('new-tag-name-field')),
      '  Atenção Máxima  ',
    );
    await tester.tap(find.byKey(const Key('save-new-tag-button')));
    await tester.pumpAndSettle();

    expect(find.text('Atenção Máxima'), findsOneWidget);
    expect(find.text('Nenhum screenshot'), findsOneWidget);
    expect((await repository.loadTags()).single.name, 'Atenção Máxima');
  });

  testWidgets('criação rejeita nome vazio e equivalente', (tester) async {
    final repository = FakeManagementTagRepository();
    await repository.createTag('Urgente');
    repository.createCallCount = 0;
    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();

    await openCreateDialog(tester);
    await tester.enterText(find.byKey(const Key('new-tag-name-field')), '   ');
    await tester.tap(find.byKey(const Key('save-new-tag-button')));
    await tester.pump();
    expect(find.text('Digite um nome para a etiqueta.'), findsOneWidget);
    expect(repository.createCallCount, 0);

    await tester.enterText(
      find.byKey(const Key('new-tag-name-field')),
      ' URGÉNTE ',
    );
    await tester.tap(find.byKey(const Key('save-new-tag-button')));
    await tester.pump();
    expect(find.text('Esta etiqueta já existe.'), findsOneWidget);
    expect(await repository.loadTags(), hasLength(1));
  });

  testWidgets('erro ao criar mantém dialog aberto e restaura ação', (
    tester,
  ) async {
    final repository = FakeManagementTagRepository(failCreate: true);
    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();
    await openCreateDialog(tester);

    await tester.enterText(
      find.byKey(const Key('new-tag-name-field')),
      'Falhar',
    );
    await tester.tap(find.byKey(const Key('save-new-tag-button')));
    await tester.pump();

    expect(find.text('Não foi possível criar a etiqueta.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-new-tag-button')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('criação pendente impede envios repetidos e tolera descarte', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = FakeManagementTagRepository(createGate: gate);
    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();
    await openCreateDialog(tester);
    await tester.enterText(
      find.byKey(const Key('new-tag-name-field')),
      'Pendente',
    );

    await tester.tap(find.byKey(const Key('save-new-tag-button')));
    await tester.pump();
    expect(repository.createCallCount, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-new-tag-button')))
          .onPressed,
      isNull,
    );

    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('abre renomeação preenchida e preserva associações', (
    tester,
  ) async {
    final repository = FakeManagementTagRepository();
    final tag = await repository.createTag('Responder');
    repository.seedAssociation(tagId: tag.id, mediaItemId: 10);
    repository.createCallCount = 0;
    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();

    await openTagAction(tester, tag, 'Renomear');
    final field = tester.widget<TextField>(
      find.byKey(const Key('rename-tag-name-field')),
    );
    expect(field.controller?.text, 'Responder');
    await tester.enterText(
      find.byKey(const Key('rename-tag-name-field')),
      '  Próxima ação  ',
    );
    await tester.tap(find.byKey(const Key('save-tag-rename-button')));
    await tester.pumpAndSettle();

    expect(find.text('Próxima ação'), findsOneWidget);
    expect(find.text('1 screenshot'), findsOneWidget);
    expect(
      await repository.isAssociated(tagId: tag.id, mediaItemId: 10),
      isTrue,
    );
  });

  testWidgets('renomeação trata conflito e erro sem fechar dialog', (
    tester,
  ) async {
    final repository = FakeManagementTagRepository();
    final first = await repository.createTag('Primeira');
    await repository.createTag('Existente');
    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();

    await openTagAction(tester, first, 'Renomear');
    await tester.enterText(
      find.byKey(const Key('rename-tag-name-field')),
      ' existente ',
    );
    await tester.tap(find.byKey(const Key('save-tag-rename-button')));
    await tester.pump();
    expect(find.text('Já existe uma etiqueta com esse nome.'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    repository.failRename = true;
    await openTagAction(tester, first, 'Renomear');
    await tester.enterText(
      find.byKey(const Key('rename-tag-name-field')),
      'Outro nome',
    );
    await tester.tap(find.byKey(const Key('save-tag-rename-button')));
    await tester.pump();
    expect(find.text('Não foi possível renomear a etiqueta.'), findsOneWidget);
    expect(find.text('Renomear etiqueta'), findsOneWidget);
  });

  testWidgets('cancelar exclusão sem uso preserva etiqueta', (tester) async {
    final repository = FakeManagementTagRepository();
    final tag = await repository.createTag('Manter');
    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();

    await openTagAction(tester, tag, 'Excluir etiqueta');
    expect(
      find.textContaining('Deseja excluir a etiqueta “Manter”?'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Os screenshots não serão excluídos.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(await repository.findById(tag.id), isNotNull);
    expect(repository.deleteCallCount, 0);
  });

  testWidgets('confirma exclusão sem uso e atualiza estado vazio', (
    tester,
  ) async {
    final repository = FakeManagementTagRepository();
    final tag = await repository.createTag('Excluir');
    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();

    await openTagAction(tester, tag, 'Excluir etiqueta');
    await tester.tap(find.byKey(const Key('confirm-tag-deletion')));
    await tester.pumpAndSettle();

    expect(await repository.findById(tag.id), isNull);
    expect(find.text('Nenhuma etiqueta criada.'), findsOneWidget);
  });

  testWidgets('exclusão em uso informa quantidade e preserva screenshots', (
    tester,
  ) async {
    final repository = FakeManagementTagRepository();
    final tag = await repository.createTag('Em uso');
    repository.seedAssociation(tagId: tag.id, mediaItemId: 1);
    repository.seedAssociation(tagId: tag.id, mediaItemId: 2);
    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();

    await openTagAction(tester, tag, 'Excluir etiqueta');
    expect(
      find.textContaining('está associada a 2 screenshots'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Os screenshots não serão excluídos.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirm-tag-deletion')));
    await tester.pumpAndSettle();

    expect(repository.mediaItemIds, {1, 2});
    expect(repository.associationCount, 0);
    expect(await repository.findById(tag.id), isNull);
  });

  testWidgets('erro ao excluir mantém etiqueta e permite tentar novamente', (
    tester,
  ) async {
    final repository = FakeManagementTagRepository(failDelete: true);
    final tag = await repository.createTag('Falha');
    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();

    await openTagAction(tester, tag, 'Excluir etiqueta');
    await tester.tap(find.byKey(const Key('confirm-tag-deletion')));
    await tester.pump();

    expect(find.text('Não foi possível excluir a etiqueta.'), findsOneWidget);
    expect(await repository.findById(tag.id), isNotNull);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('confirm-tag-deletion')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('exclusão pendente impede múltiplos envios', (tester) async {
    final gate = Completer<void>();
    final repository = FakeManagementTagRepository(deleteGate: gate);
    final tag = await repository.createTag('Pendente');
    await tester.pumpWidget(buildTagsApp(repository));
    await tester.pumpAndSettle();
    await openTagAction(tester, tag, 'Excluir etiqueta');

    await tester.tap(find.byKey(const Key('confirm-tag-deletion')));
    await tester.pump();
    expect(repository.deleteCallCount, 1);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('confirm-tag-deletion')))
          .onPressed,
      isNull,
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma etiqueta criada.'), findsOneWidget);
  });
}

Widget buildTagsApp(TagRepository repository) {
  return MaterialApp(
    theme: AppTheme.light,
    home: TagsPage(repository: repository),
  );
}

Future<void> openCreateDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('new-tag-button')));
  await tester.pumpAndSettle();
}

Future<void> openTagAction(WidgetTester tester, Tag tag, String action) async {
  await tester.tap(find.byTooltip('Ações da etiqueta ${tag.name}'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

class FakeManagementTagRepository implements TagRepository {
  FakeManagementTagRepository({
    this.loadFailures = 0,
    this.failCreate = false,
    this.failDelete = false,
    this.loadGate,
    this.createGate,
    this.deleteGate,
  });

  final List<Tag> _tags = [];
  final Map<int, Set<int>> _associations = {};
  int _nextId = 1;
  int loadFailures;
  bool failCreate;
  bool failRename = false;
  bool failDelete;
  final Completer<void>? loadGate;
  final Completer<void>? createGate;
  final Completer<void>? deleteGate;
  int loadSummaryCallCount = 0;
  int createCallCount = 0;
  int renameCallCount = 0;
  int deleteCallCount = 0;
  final Set<int> mediaItemIds = {};

  int get associationCount =>
      _associations.values.fold(0, (total, tagIds) => total + tagIds.length);

  @override
  Future<Tag> createTag(String name) async {
    createCallCount++;
    final (visibleName, normalizedName) = _validate(name);
    if (_tags.any((tag) => tag.normalizedName == normalizedName)) {
      throw const TagValidationException(TagValidationError.duplicate);
    }
    if (failCreate) throw StateError('Falha privada ao criar');
    if (createGate != null) await createGate!.future;
    final now = DateTime(2026);
    final tag = Tag(
      id: _nextId++,
      name: visibleName,
      normalizedName: normalizedName,
      createdAt: now,
      updatedAt: now,
    );
    _tags.add(tag);
    return tag;
  }

  @override
  Future<List<TagSummary>> loadTagSummaries() async {
    loadSummaryCallCount++;
    if (loadFailures > 0) {
      loadFailures--;
      throw StateError('Falha privada ao carregar');
    }
    if (loadGate != null) await loadGate!.future;
    final summaries = [
      for (final tag in _tags)
        TagSummary(
          tag: tag,
          mediaCount: _associations.values
              .where((ids) => ids.contains(tag.id))
              .length,
        ),
    ];
    summaries.sort((first, second) {
      final byName = first.tag.normalizedName.compareTo(
        second.tag.normalizedName,
      );
      return byName != 0 ? byName : first.tag.id.compareTo(second.tag.id);
    });
    return summaries;
  }

  @override
  Future<List<Tag>> loadTags() async => [..._tags];

  @override
  Future<Tag?> findById(int id) async {
    final matches = _tags.where((tag) => tag.id == id);
    return matches.isEmpty ? null : matches.single;
  }

  @override
  Future<Tag?> findByNormalizedName(String normalizedName) async {
    const normalizer = TextNormalizer();
    final value = normalizer.normalize(normalizedName);
    final matches = _tags.where((tag) => tag.normalizedName == value);
    return matches.isEmpty ? null : matches.single;
  }

  @override
  Future<Tag> renameTag(Tag tag, String name) async {
    renameCallCount++;
    final (visibleName, normalizedName) = _validate(name);
    if (_tags.any(
      (item) => item.id != tag.id && item.normalizedName == normalizedName,
    )) {
      throw const TagValidationException(TagValidationError.duplicate);
    }
    if (failRename) throw StateError('Falha privada ao renomear');
    final renamed = Tag(
      id: tag.id,
      name: visibleName,
      normalizedName: normalizedName,
      createdAt: tag.createdAt,
      updatedAt: DateTime(2026, 2),
    );
    final index = _tags.indexWhere((item) => item.id == tag.id);
    _tags[index] = renamed;
    return renamed;
  }

  @override
  Future<void> deleteTag(int tagId) async {
    deleteCallCount++;
    if (failDelete) throw StateError('Falha privada ao excluir');
    if (deleteGate != null) await deleteGate!.future;
    _tags.removeWhere((tag) => tag.id == tagId);
    for (final tagIds in _associations.values) {
      tagIds.remove(tagId);
    }
  }

  @override
  Future<void> addToMedia({
    required int tagId,
    required int mediaItemId,
  }) async {
    seedAssociation(tagId: tagId, mediaItemId: mediaItemId);
  }

  @override
  Future<void> removeFromMedia({
    required int tagId,
    required int mediaItemId,
  }) async {
    _associations[mediaItemId]?.remove(tagId);
  }

  @override
  Future<bool> isAssociated({
    required int tagId,
    required int mediaItemId,
  }) async {
    return _associations[mediaItemId]?.contains(tagId) ?? false;
  }

  @override
  Future<List<Tag>> loadForMedia(int mediaItemId) async {
    final ids = _associations[mediaItemId] ?? const <int>{};
    return _tags.where((tag) => ids.contains(tag.id)).toList();
  }

  @override
  Future<List<MediaItem>> loadMediaForTag(int tagId) async => const [];

  void seedAssociation({required int tagId, required int mediaItemId}) {
    mediaItemIds.add(mediaItemId);
    (_associations[mediaItemId] ??= {}).add(tagId);
  }

  (String, String) _validate(String name) {
    final visibleName = name.trim();
    const normalizer = TextNormalizer();
    final normalizedName = normalizer.normalize(visibleName);
    if (normalizedName.isEmpty) {
      throw const TagValidationException(TagValidationError.empty);
    }
    if (visibleName.length > 40) {
      throw const TagValidationException(TagValidationError.tooLong);
    }
    return (visibleName, normalizedName);
  }
}

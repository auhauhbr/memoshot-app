import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/database/contexto_database.dart';
import 'package:memoshot/features/categories/data/category_repository.dart';
import 'package:memoshot/features/categories/data/category_store.dart';

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
            privatePath: '/tmp/hierarquia.png',
            internalName: 'hierarquia.png',
            importedAt: DateTime(2026),
            sourceMode: 'photoPicker',
            status: 'ready',
          ),
        );
  });

  tearDown(() => database.close());

  test('cria e ordena raízes e várias filhas diretas', () async {
    final books = await repository.createRootCategory('Livros');
    await repository.createRootCategory('Carreira');
    final excerpts = await repository.createSubcategory(
      parentId: books.id,
      name: 'Trechos',
    );
    final covers = await repository.createSubcategory(
      parentId: books.id,
      name: 'Capas',
    );
    final recommendations = await repository.createSubcategory(
      parentId: books.id,
      name: 'Recomendações',
    );

    expect(books.parentId, isNull);
    expect(excerpts.parentId, books.id);
    expect((await repository.loadRootCategories()).map((item) => item.name), [
      'Carreira',
      'Livros',
    ]);
    expect(
      (await repository.loadChildCategories(books.id)).map((item) => item.id),
      [covers.id, recommendations.id, excerpts.id],
    );
    expect(await repository.hasChildren(books.id), isTrue);
    expect(await repository.hasChildren(excerpts.id), isFalse);
  });

  test(
    'resumos hierárquicos contam apenas prints diretos e subpastas',
    () async {
      final books = await repository.createRootCategory('Livros');
      final career = await repository.createRootCategory('Carreira');
      final excerpts = await repository.createSubcategory(
        parentId: books.id,
        name: 'Trechos',
      );
      await repository.createSubcategory(parentId: books.id, name: 'Capas');
      await repository.createSubcategory(
        parentId: excerpts.id,
        name: 'Favoritos',
      );
      await repository.replaceForMedia(mediaItemId, {excerpts.id});

      final roots = await repository.loadRootCategorySummaries();
      expect(roots.map((item) => item.category.id), [career.id, books.id]);
      final booksSummary = roots.last;
      expect(booksSummary.mediaCount, 0);
      expect(booksSummary.childCount, 2);

      final children = await repository.loadChildCategorySummaries(books.id);
      expect(children.map((item) => item.category.name), ['Capas', 'Trechos']);
      expect(children.last.mediaCount, 1);
      expect(children.last.childCount, 1);
      expect(children.first.mediaCount, 0);
    },
  );

  test('resumo de filhas distingue pasta inexistente', () async {
    await expectLater(
      repository.loadChildCategorySummaries(999),
      _hierarchy(CategoryHierarchyError.parentNotFound),
    );
  });

  test(
    'schema aplica FK autorreferente, restrição e índices por mãe',
    () async {
      final foreignKeys = await database
          .customSelect('PRAGMA foreign_key_list(categories)')
          .get();
      final parentForeignKey = foreignKeys.singleWhere(
        (row) => row.read<String>('from') == 'parent_id',
      );
      final indexes = await database
          .customSelect('PRAGMA index_list(categories)')
          .get();

      expect(parentForeignKey.read<String>('table'), 'categories');
      expect(parentForeignKey.read<String>('on_delete'), 'RESTRICT');
      expect(
        indexes.map((row) => row.read<String>('name')),
        containsAll([
          'categories_root_name_unique',
          'categories_child_name_unique',
        ]),
      );

      final root = await repository.createRootCategory('Raiz');
      await expectLater(
        (database.update(database.categories)
              ..where((category) => category.id.equals(root.id)))
            .write(CategoriesCompanion(parentId: Value(root.id))),
        throwsA(anything),
      );
    },
  );

  test('unicidade é local à mãe e segura para raízes', () async {
    final books = await repository.createRootCategory('Livros');
    final studies = await repository.createRootCategory('Estudos');
    await repository.createSubcategory(parentId: books.id, name: 'Trechos');
    final other = await repository.createSubcategory(
      parentId: studies.id,
      name: 'Trechos',
    );

    expect(other.parentId, studies.id);
    await expectLater(
      repository.createSubcategory(parentId: books.id, name: ' TRÊCHOS '),
      _duplicate,
    );
    await expectLater(repository.createRootCategory(' livros '), _duplicate);
  });

  test(
    'criação concorrente mantém somente um nome equivalente por mãe',
    (() async {
      final root = await repository.createRootCategory('Projetos');
      final outcomes = await Future.wait([
        repository
            .createSubcategory(parentId: root.id, name: 'Referências')
            .then<Object>((value) => value)
            .catchError((Object error) => error),
        repository
            .createSubcategory(parentId: root.id, name: ' referências ')
            .then<Object>((value) => value)
            .catchError((Object error) => error),
      ]);

      expect(outcomes.whereType<CategoryValidationException>(), hasLength(1));
      expect(await repository.loadChildCategories(root.id), hasLength(1));
    }),
  );

  test('lista ancestrais, descendentes e caminhos determinísticos', () async {
    final books = await repository.createRootCategory('Livros');
    final excerpts = await repository.createSubcategory(
      parentId: books.id,
      name: 'Trechos',
    );
    final favorites = await repository.createSubcategory(
      parentId: excerpts.id,
      name: 'Favoritos',
    );
    final covers = await repository.createSubcategory(
      parentId: books.id,
      name: 'Capas',
    );

    expect(await repository.loadAncestors(books.id), isEmpty);
    expect(
      (await repository.loadAncestors(favorites.id)).map((item) => item.id),
      [books.id, excerpts.id],
    );
    expect((await repository.loadPath(books.id)).value, 'Livros');
    expect(
      (await repository.loadPath(favorites.id)).value,
      'Livros/Trechos/Favoritos',
    );
    expect(
      (await repository.loadDescendants(books.id)).map((item) => item.id),
      [covers.id, excerpts.id, favorites.id],
    );
  });

  test('move entre mães e para raiz preservando associações', () async {
    final books = await repository.createRootCategory('Livros');
    final studies = await repository.createRootCategory('Estudos');
    final excerpts = await repository.createSubcategory(
      parentId: books.id,
      name: 'Trechos',
    );
    await repository.replaceForMedia(mediaItemId, {excerpts.id});

    final moved = await repository.moveCategory(excerpts, parentId: studies.id);
    expect(moved.parentId, studies.id);
    expect((await repository.loadForMedia(mediaItemId)).single.id, excerpts.id);
    expect(await database.select(database.mediaItems).get(), hasLength(1));

    final root = await repository.moveCategory(moved, parentId: null);
    expect(root.parentId, isNull);
    expect((await repository.loadForMedia(mediaItemId)).single.id, excerpts.id);
  });

  test('rejeita autorreferência e ciclos direto e indireto', () async {
    final root = await repository.createRootCategory('Raiz');
    final child = await repository.createSubcategory(
      parentId: root.id,
      name: 'Filha',
    );
    final grandchild = await repository.createSubcategory(
      parentId: child.id,
      name: 'Neta',
    );

    expect(
      await repository.wouldCreateCycle(categoryId: root.id, parentId: root.id),
      isTrue,
    );
    await expectLater(
      repository.moveCategory(root, parentId: root.id),
      _hierarchy(CategoryHierarchyError.selfParent),
    );
    await expectLater(
      repository.moveCategory(root, parentId: child.id),
      _hierarchy(CategoryHierarchyError.cycle),
    );
    await expectLater(
      repository.moveCategory(root, parentId: grandchild.id),
      _hierarchy(CategoryHierarchyError.cycle),
    );
  });

  test('rejeita conflito de nome ao mover', () async {
    final books = await repository.createRootCategory('Livros');
    final studies = await repository.createRootCategory('Estudos');
    final first = await repository.createSubcategory(
      parentId: books.id,
      name: 'Trechos',
    );
    await repository.createSubcategory(parentId: studies.id, name: 'Trechos');

    await expectLater(
      repository.moveCategory(first, parentId: studies.id),
      _duplicate,
    );
    expect((await repository.findCategoryById(first.id))?.parentId, books.id);
  });

  test(
    'mãe inexistente é distinguida em criação, consulta e movimento',
    () async {
      final root = await repository.createRootCategory('Raiz');

      await expectLater(
        repository.createSubcategory(parentId: 99999, name: 'Órfã'),
        _hierarchy(CategoryHierarchyError.parentNotFound),
      );
      await expectLater(
        repository.loadChildCategories(99999),
        _hierarchy(CategoryHierarchyError.parentNotFound),
      );
      await expectLater(
        repository.moveCategory(root, parentId: 99999),
        _hierarchy(CategoryHierarchyError.parentNotFound),
      );
      await expectLater(
        repository.loadPath(99999),
        _hierarchy(CategoryHierarchyError.categoryNotFound),
      );
    },
  );

  test(
    'exclui folha, preserva screenshot e bloqueia pasta com filhas',
    () async {
      final root = await repository.createRootCategory('Raiz');
      final leaf = await repository.createSubcategory(
        parentId: root.id,
        name: 'Folha',
      );
      await repository.replaceForMedia(mediaItemId, {leaf.id});

      await expectLater(
        repository.deleteCategory(root.id),
        _hierarchy(CategoryHierarchyError.hasChildren),
      );
      await repository.deleteCategory(leaf.id);

      expect(await repository.findCategoryById(leaf.id), isNull);
      expect(await database.select(database.mediaCategories).get(), isEmpty);
      expect(await database.select(database.mediaItems).get(), hasLength(1));
      expect(await repository.findCategoryById(root.id), isNotNull);
    },
  );

  test(
    'árvore profunda usa iteração e dados cíclicos não entram em loop',
    () async {
      var current = await repository.createRootCategory('Nível 0');
      for (var depth = 1; depth <= 120; depth++) {
        current = await repository.createSubcategory(
          parentId: current.id,
          name: 'Nível $depth',
        );
      }
      expect(await repository.loadAncestors(current.id), hasLength(120));
      expect(
        (await repository.loadPath(current.id)).categories,
        hasLength(121),
      );

      final root = (await repository.loadRootCategories()).single;
      await (database.update(database.categories)
            ..where((category) => category.id.equals(root.id)))
          .write(CategoriesCompanion(parentId: Value(current.id)));
      await expectLater(
        repository.loadAncestors(current.id),
        _hierarchy(CategoryHierarchyError.cycle),
      );
      await expectLater(
        repository.loadDescendants(root.id),
        _hierarchy(CategoryHierarchyError.cycle),
      );
    },
  );

  test('hierarquia persiste ao fechar e reabrir o banco', () async {
    await database.close();
    final directory = Directory.systemTemp.createTempSync('memoshot_tree_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/tree.sqlite');
    final firstDatabase = ContextoDatabase.forTesting(NativeDatabase(file));
    final firstRepository = LocalCategoryRepository(
      store: DriftCategoryStore(firstDatabase),
    );
    final root = await firstRepository.createRootCategory('Livros');
    final child = await firstRepository.createSubcategory(
      parentId: root.id,
      name: 'Trechos',
    );
    await firstDatabase.close();

    final reopenedDatabase = ContextoDatabase.forTesting(NativeDatabase(file));
    final reopenedRepository = LocalCategoryRepository(
      store: DriftCategoryStore(reopenedDatabase),
    );
    expect(
      (await reopenedRepository.loadPath(child.id)).value,
      'Livros/Trechos',
    );
    await reopenedDatabase.close();
  });
}

final Matcher _duplicate = throwsA(
  isA<CategoryValidationException>().having(
    (error) => error.error,
    'error',
    CategoryValidationError.duplicate,
  ),
);

Matcher _hierarchy(CategoryHierarchyError expected) => throwsA(
  isA<CategoryHierarchyException>().having(
    (error) => error.error,
    'error',
    expected,
  ),
);

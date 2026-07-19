import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/database/contexto_database.dart';
import 'package:memoshot/features/categories/data/category_repository.dart';
import 'package:memoshot/features/categories/data/category_store.dart';
import 'package:memoshot/features/categories/data/recent_folder_repository.dart';

void main() {
  late ContextoDatabase database;
  late LocalCategoryRepository categories;
  late _MemoryRecentFolderIdStore store;
  late LocalRecentFolderRepository recents;

  setUp(() {
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    categories = LocalCategoryRepository(store: DriftCategoryStore(database));
    store = _MemoryRecentFolderIdStore();
    recents = LocalRecentFolderRepository(
      store: store,
      categoryRepository: categories,
    );
  });

  tearDown(() => database.close());

  test('começa vazio, limita a seis, ordena e não duplica', () async {
    final folders = <int>[];
    for (var index = 1; index <= 7; index++) {
      folders.add((await categories.createRootCategory('Pasta $index')).id);
    }

    for (final id in folders) {
      await recents.recordAccess(id);
    }
    expect(store.ids, folders.reversed.take(6));

    await recents.recordAccess(folders[3]);
    expect(store.ids.first, folders[3]);
    expect(store.ids.where((id) => id == folders[3]), hasLength(1));
    expect(await recents.load(), hasLength(6));
  });

  test('preserva ordem após recriar o repositório', () async {
    final first = await categories.createRootCategory('Primeira');
    final second = await categories.createRootCategory('Segunda');
    await recents.recordAccess(first.id);
    await recents.recordAccess(second.id);

    final reopened = LocalRecentFolderRepository(
      store: store,
      categoryRepository: categories,
    );
    expect((await reopened.load()).map((folder) => folder.category.id), [
      second.id,
      first.id,
    ]);
  });

  test('ignora inexistente e remove pasta excluída', () async {
    final existing = await categories.createRootCategory('Existente');
    store.ids = [999, existing.id];
    expect((await recents.load()).map((folder) => folder.category.id), [
      existing.id,
    ]);
    expect(store.ids, [existing.id]);

    await categories.deleteCategory(existing.id);
    expect(await recents.load(), isEmpty);
    expect(store.ids, isEmpty);
  });

  test('renomear atualiza nome e mover preserva ID e caminho', () async {
    final firstRoot = await categories.createRootCategory('Livros');
    final secondRoot = await categories.createRootCategory('Estudos');
    var child = await categories.createSubcategory(
      parentId: firstRoot.id,
      name: 'Trechos',
    );
    await recents.recordAccess(child.id);

    child = await categories.renameCategory(child, 'Citações');
    child = await categories.moveCategory(child, parentId: secondRoot.id);
    final recent = (await recents.load()).single;

    expect(recent.category.id, child.id);
    expect(recent.category.name, 'Citações');
    expect(recent.fullPath, 'Estudos / Citações');
  });

  test('dois acessos rápidos à mesma pasta são serializados', () async {
    final folder = await categories.createRootCategory('Concorrente');
    await Future.wait([
      recents.recordAccess(folder.id),
      recents.recordAccess(folder.id),
    ]);
    expect(store.ids, [folder.id]);
  });
}

class _MemoryRecentFolderIdStore implements RecentFolderIdStore {
  List<int> ids = [];

  @override
  Future<List<int>> loadIds() async => [...ids];

  @override
  Future<void> saveIds(List<int> ids) async => this.ids = [...ids];
}

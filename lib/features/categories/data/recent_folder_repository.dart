import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/category.dart';
import 'category_repository.dart';

const maximumRecentFolders = 6;

abstract interface class RecentFolderIdStore {
  Future<List<int>> loadIds();

  Future<void> saveIds(List<int> ids);
}

class MethodChannelRecentFolderIdStore implements RecentFolderIdStore {
  const MethodChannelRecentFolderIdStore();

  static const _channel = MethodChannel(
    'br.com.jeffersont.memoshot/preferences',
  );

  @override
  Future<List<int>> loadIds() async {
    final values = await _channel.invokeMethod<List<Object?>>(
      'recentFolderIds',
    );
    return values?.whereType<int>().toList(growable: false) ?? const [];
  }

  @override
  Future<void> saveIds(List<int> ids) =>
      _channel.invokeMethod<void>('setRecentFolderIds', {'ids': ids});
}

class RecentFolder {
  const RecentFolder({required this.category, required this.path});

  final Category category;
  final CategoryPath path;

  String get fullPath => path.categories.map((item) => item.name).join(' / ');
}

abstract interface class RecentFolderRepository {
  Future<List<RecentFolder>> load();

  Future<void> recordAccess(int categoryId);

  Future<void> remove(int categoryId);
}

class LocalRecentFolderRepository implements RecentFolderRepository {
  LocalRecentFolderRepository({
    required RecentFolderIdStore store,
    required CategoryRepository categoryRepository,
  }) : this._(store, categoryRepository);

  LocalRecentFolderRepository._(this._store, this._categoryRepository);

  final RecentFolderIdStore _store;
  final CategoryRepository _categoryRepository;
  Future<void> _pendingWrite = Future<void>.value();

  @override
  Future<List<RecentFolder>> load() async {
    await _pendingWrite;
    final storedIds = _normalized(await _store.loadIds());
    final folders = <RecentFolder>[];
    for (final id in storedIds) {
      final category = await _categoryRepository.findCategoryById(id);
      if (category == null) continue;
      final path = await _categoryRepository.loadPath(id);
      folders.add(RecentFolder(category: category, path: path));
    }
    final validIds = folders.map((folder) => folder.category.id).toList();
    if (!_sameIds(storedIds, validIds)) await _store.saveIds(validIds);
    return folders;
  }

  @override
  Future<void> recordAccess(int categoryId) => _serialize(() async {
    final ids = _normalized(await _store.loadIds());
    await _store.saveIds(
      <int>[
        categoryId,
        ...ids.where((id) => id != categoryId),
      ].take(maximumRecentFolders).toList(growable: false),
    );
  });

  @override
  Future<void> remove(int categoryId) => _serialize(() async {
    final ids = _normalized(await _store.loadIds());
    final updated = ids.where((id) => id != categoryId).toList(growable: false);
    if (!_sameIds(ids, updated)) await _store.saveIds(updated);
  });

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _pendingWrite.then((_) => operation());
    _pendingWrite = result.catchError((_) {});
    return result;
  }

  List<int> _normalized(List<int> ids) {
    final unique = <int>{};
    return ids
        .where((id) => id > 0 && unique.add(id))
        .take(maximumRecentFolders)
        .toList(growable: false);
  }

  bool _sameIds(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}

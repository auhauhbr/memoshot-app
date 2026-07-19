import 'dart:async';

import 'package:flutter/material.dart';

import '../../library/data/media_item_repository.dart';
import '../../ocr/data/ocr_repository.dart';
import '../../processing/data/ocr_queue_processor.dart';
import '../../tags/data/tag_repository.dart';
import '../data/category_repository.dart';
import '../data/recent_folder_repository.dart';
import '../domain/category.dart';
import 'category_detail_page.dart';
import 'category_tree.dart';
import 'folder_management_dialogs.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({
    required this.categoryRepository,
    required this.mediaRepository,
    required this.ocrRepository,
    required this.ocrQueue,
    required this.tagRepository,
    this.recentFolderRepository,
    super.key,
  });

  final CategoryRepository categoryRepository;
  final MediaItemRepository mediaRepository;
  final OcrRepository ocrRepository;
  final OcrQueue ocrQueue;
  final TagRepository tagRepository;
  final RecentFolderRepository? recentFolderRepository;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<CategorySummary> _categories = const [];
  bool _loading = true;
  bool _dialogOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final categories = await widget.categoryRepository.loadCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar as pastas.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _withDialog(Future<void> Function() operation) async {
    if (_dialogOpen) return;
    setState(() => _dialogOpen = true);
    try {
      await operation();
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  Future<void> _create() => _withDialog(() async {
    final created = await showCreateCategoryDialog(
      context,
      widget.categoryRepository,
      allowParentSelection: true,
    );
    if (created != null && mounted) await _load();
  });

  Future<void> _createChild(Category category) => _withDialog(() async {
    final created = await showCreateCategoryDialog(
      context,
      widget.categoryRepository,
      fixedParent: category,
    );
    if (created != null && mounted) await _load();
  });

  Future<void> _open(CategorySummary summary) async {
    try {
      await widget.recentFolderRepository?.recordAccess(summary.category.id);
    } catch (_) {
      // O gerenciamento continua disponível sem o histórico recente.
    }
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      buildCategoryDetailRoute(
        summary: summary,
        categoryRepository: widget.categoryRepository,
        mediaRepository: widget.mediaRepository,
        ocrRepository: widget.ocrRepository,
        ocrQueue: widget.ocrQueue,
        tagRepository: widget.tagRepository,
        recentFolderRepository: widget.recentFolderRepository,
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _rename(CategorySummary summary) => _withDialog(() async {
    final renamed = await showRenameCategoryDialog(
      context,
      widget.categoryRepository,
      summary.category,
    );
    if (renamed != null && mounted) await _load();
  });

  Future<void> _move(CategorySummary summary) => _withDialog(() async {
    final moved = await showMoveCategoryDialog(
      context,
      widget.categoryRepository,
      summary.category,
    );
    if (moved != null && mounted) await _load();
  });

  Future<void> _delete(CategorySummary summary) => _withDialog(() async {
    if (await confirmCategoryDeletion(
          context,
          widget.categoryRepository,
          summary,
        ) &&
        mounted) {
      try {
        await widget.recentFolderRepository?.remove(summary.category.id);
      } catch (_) {
        // O histórico não invalida a exclusão concluída.
      }
      await _load();
    }
  });

  void _handleAction(String action, CategorySummary summary) {
    switch (action) {
      case 'open':
        unawaited(_open(summary));
      case 'create-child':
        unawaited(_createChild(summary.category));
      case 'rename':
        unawaited(_rename(summary));
      case 'move':
        unawaited(_move(summary));
      case 'delete':
        unawaited(_delete(summary));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = buildCategoryTreeEntries(_categories);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pastas'),
        backgroundColor: colors.surface,
        foregroundColor: colors.primary,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Expanded(child: Center(child: Text(_error!)))
                  else if (_categories.isEmpty)
                    const Expanded(
                      child: Center(child: Text('Nenhuma pasta criada.')),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final summary = entry.summary;
                          final count = summary.mediaCount;
                          return Padding(
                            padding: EdgeInsets.only(left: entry.depth * 16.0),
                            child: Card(
                              child: ListTile(
                                key: ValueKey(
                                  'category-tile-${summary.category.id}',
                                ),
                                onTap: _dialogOpen
                                    ? null
                                    : () => _open(summary),
                                leading: Icon(
                                  entry.depth == 0
                                      ? Icons.folder_outlined
                                      : Icons.subdirectory_arrow_right,
                                ),
                                title: Text(
                                  summary.category.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (entry.depth > 0)
                                      Text(
                                        entry.path,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    Text(
                                      '$count ${count == 1 ? 'print' : 'prints'}',
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  tooltip: 'Ações da pasta',
                                  enabled: !_dialogOpen,
                                  onSelected: (action) =>
                                      _handleAction(action, summary),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'open',
                                      child: Text('Abrir'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'create-child',
                                      child: Text('Nova subpasta'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'rename',
                                      child: Text('Renomear'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'move',
                                      child: Text('Mover'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Excluir pasta',
                                        style: TextStyle(color: colors.error),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('new-category-button'),
                    onPressed: _dialogOpen ? null : _create,
                    icon: const Icon(Icons.add, size: 19),
                    label: const Text('Nova pasta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

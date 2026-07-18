import 'package:flutter/material.dart';

import '../../library/data/media_item_repository.dart';
import '../../ocr/data/ocr_repository.dart';
import '../../processing/data/ocr_queue_processor.dart';
import '../../tags/data/tag_repository.dart';
import '../data/category_repository.dart';
import '../domain/category.dart';
import 'category_detail_page.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({
    required this.categoryRepository,
    required this.mediaRepository,
    required this.ocrRepository,
    required this.ocrQueue,
    required this.tagRepository,
    super.key,
  });

  final CategoryRepository categoryRepository;
  final MediaItemRepository mediaRepository;
  final OcrRepository ocrRepository;
  final OcrQueue ocrQueue;
  final TagRepository tagRepository;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<CategorySummary> _categories = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final categories = await widget.categoryRepository.loadCategories();
      if (mounted) {
        setState(() => _categories = categories);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar as pastas.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await showCreateCategoryDialog(
      context,
      widget.categoryRepository,
    );
    if (created != null) await _load();
  }

  Future<void> _open(CategorySummary summary) async {
    await Navigator.of(context).push<bool>(
      buildCategoryDetailRoute(
        summary: summary,
        categoryRepository: widget.categoryRepository,
        mediaRepository: widget.mediaRepository,
        ocrRepository: widget.ocrRepository,
        ocrQueue: widget.ocrQueue,
        tagRepository: widget.tagRepository,
      ),
    );
    await _load();
  }

  Future<void> _rename(CategorySummary summary) async {
    final renamed = await showRenameCategoryDialog(
      context,
      widget.categoryRepository,
      summary.category,
    );
    if (renamed != null) await _load();
  }

  Future<void> _delete(CategorySummary summary) async {
    if (await confirmCategoryDeletion(
      context,
      widget.categoryRepository,
      summary,
    )) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = _hierarchyEntries(_categories);
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
                                onTap: () => _open(summary),
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
                                  onSelected: (action) {
                                    if (action == 'rename') _rename(summary);
                                    if (action == 'delete') _delete(summary);
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'rename',
                                      child: Text('Renomear'),
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
                    onPressed: _create,
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

Future<Category?> showCreateCategoryDialog(
  BuildContext context,
  CategoryRepository repository,
) {
  return showDialog<Category>(
    context: context,
    builder: (_) => _CreateCategoryDialog(repository: repository),
  );
}

class _CreateCategoryDialog extends StatefulWidget {
  const _CreateCategoryDialog({required this.repository});

  final CategoryRepository repository;

  @override
  State<_CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<_CreateCategoryDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final category = await widget.repository.createCategory(_controller.text);
      if (mounted) Navigator.pop(context, category);
    } on CategoryValidationException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = switch (error.error) {
            CategoryValidationError.empty => 'Informe um nome para a pasta.',
            CategoryValidationError.tooLong => 'Use no máximo 40 caracteres.',
            CategoryValidationError.duplicate =>
              'Já existe uma pasta com esse nome neste local.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível criar a pasta.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova pasta'),
      content: TextField(
        key: const Key('category-name-field'),
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'Nome da pasta',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('save-category-button'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Criar'),
        ),
      ],
    );
  }
}

Future<Category?> showRenameCategoryDialog(
  BuildContext context,
  CategoryRepository repository,
  Category category,
) {
  return showDialog<Category>(
    context: context,
    builder: (_) =>
        _RenameCategoryDialog(repository: repository, category: category),
  );
}

class _RenameCategoryDialog extends StatefulWidget {
  const _RenameCategoryDialog({
    required this.repository,
    required this.category,
  });

  final CategoryRepository repository;
  final Category category;

  @override
  State<_RenameCategoryDialog> createState() => _RenameCategoryDialogState();
}

class _RenameCategoryDialogState extends State<_RenameCategoryDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.category.name,
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final category = await widget.repository.renameCategory(
        widget.category,
        _controller.text,
      );
      if (mounted) Navigator.pop(context, category);
    } on CategoryValidationException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _categoryValidationMessage(error.error);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível renomear a pasta.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renomear pasta'),
      content: TextField(
        key: const Key('rename-category-field'),
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'Nome da pasta',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('save-category-rename'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

Future<bool> confirmCategoryDeletion(
  BuildContext context,
  CategoryRepository repository,
  CategorySummary summary,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Excluir “${summary.category.name}”?'),
      content: Text(
        '${summary.mediaCount} '
        '${summary.mediaCount == 1 ? 'screenshot está associado' : 'screenshots estão associados'}. '
        'Esta ação removerá a pasta e suas associações. '
        'Os screenshots continuarão na biblioteca e os arquivos originais '
        'não serão alterados.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('confirm-category-deletion'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Excluir pasta',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    await repository.deleteCategory(summary.category.id);
    return true;
  } on CategoryHierarchyException catch (error) {
    if (context.mounted) {
      final message = error.error == CategoryHierarchyError.hasChildren
          ? 'Esta pasta possui subpastas e não pode ser excluída.'
          : 'Não foi possível excluir a pasta.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return false;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível excluir a pasta.')),
      );
    }
    return false;
  }
}

String _categoryValidationMessage(CategoryValidationError error) {
  return switch (error) {
    CategoryValidationError.empty => 'Informe um nome para a pasta.',
    CategoryValidationError.tooLong => 'Use no máximo 40 caracteres.',
    CategoryValidationError.duplicate =>
      'Já existe uma pasta com esse nome neste local.',
  };
}

class _HierarchyEntry {
  const _HierarchyEntry({
    required this.summary,
    required this.depth,
    required this.path,
  });

  final CategorySummary summary;
  final int depth;
  final String path;
}

List<_HierarchyEntry> _hierarchyEntries(List<CategorySummary> summaries) {
  final byParent = <int?, List<CategorySummary>>{};
  for (final summary in summaries) {
    byParent.putIfAbsent(summary.category.parentId, () => []).add(summary);
  }
  for (final children in byParent.values) {
    children.sort((first, second) {
      final name = first.category.normalizedName.compareTo(
        second.category.normalizedName,
      );
      return name != 0 ? name : first.category.id.compareTo(second.category.id);
    });
  }

  final entries = <_HierarchyEntry>[];
  final visited = <int>{};
  final pending = <({CategorySummary summary, int depth, String parentPath})>[
    for (final root in (byParent[null] ?? const []).reversed)
      (summary: root, depth: 0, parentPath: ''),
  ];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    if (!visited.add(current.summary.category.id)) continue;
    final path = current.parentPath.isEmpty
        ? current.summary.category.name
        : '${current.parentPath}/${current.summary.category.name}';
    entries.add(
      _HierarchyEntry(
        summary: current.summary,
        depth: current.depth,
        path: path,
      ),
    );
    final children = byParent[current.summary.category.id] ?? const [];
    for (final child in children.reversed) {
      pending.add((summary: child, depth: current.depth + 1, parentPath: path));
    }
  }
  for (final summary in summaries) {
    if (visited.add(summary.category.id)) {
      entries.add(
        _HierarchyEntry(
          summary: summary,
          depth: 0,
          path: summary.category.name,
        ),
      );
    }
  }
  return entries;
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/category_repository.dart';
import '../domain/category.dart';
import 'category_tree.dart';

Future<Category?> showCreateCategoryDialog(
  BuildContext context,
  CategoryRepository repository, {
  Category? fixedParent,
  bool allowParentSelection = false,
}) {
  return showDialog<Category>(
    context: context,
    builder: (_) => _CreateCategoryDialog(
      repository: repository,
      fixedParent: fixedParent,
      allowParentSelection: allowParentSelection,
    ),
  );
}

class _CreateCategoryDialog extends StatefulWidget {
  const _CreateCategoryDialog({
    required this.repository,
    required this.fixedParent,
    required this.allowParentSelection,
  });

  final CategoryRepository repository;
  final Category? fixedParent;
  final bool allowParentSelection;

  @override
  State<_CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<_CreateCategoryDialog> {
  final _controller = TextEditingController();
  List<CategoryTreeEntry> _destinations = const [];
  int? _parentId;
  String? _error;
  bool _loadingDestinations = false;
  bool _saving = false;
  bool _selectingDestination = false;

  @override
  void initState() {
    super.initState();
    _parentId = widget.fixedParent?.id;
    if (widget.allowParentSelection) unawaited(_loadDestinations());
  }

  Future<void> _loadDestinations() async {
    setState(() => _loadingDestinations = true);
    try {
      final summaries = await widget.repository.loadCategories();
      if (!mounted) return;
      setState(() => _destinations = buildCategoryTreeEntries(summaries));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível carregar as pastas.');
    } finally {
      if (mounted) setState(() => _loadingDestinations = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _chooseDestination() async {
    if (_selectingDestination || _saving || _loadingDestinations) return;
    setState(() => _selectingDestination = true);
    final selection = await showFolderDestinationSheet(
      context,
      entries: _destinations,
      currentParentId: _parentId,
      title: 'Criar dentro de',
    );
    if (!mounted) return;
    setState(() {
      _selectingDestination = false;
      if (selection != null) _parentId = selection.parentId;
    });
  }

  Future<void> _save() async {
    if (_saving || _loadingDestinations || _selectingDestination) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final category = _parentId == null
          ? await widget.repository.createRootCategory(_controller.text)
          : await widget.repository.createSubcategory(
              parentId: _parentId!,
              name: _controller.text,
            );
      if (mounted) Navigator.pop(context, category);
    } on CategoryValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = categoryValidationMessage(error.error);
      });
    } on CategoryHierarchyException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Não foi possível criar a pasta no destino escolhido.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Não foi possível criar a pasta.';
      });
    }
  }

  String get _destinationLabel {
    if (_parentId == null) return 'Raiz';
    return _destinations
            .where((entry) => entry.summary.category.id == _parentId)
            .map((entry) => entry.path)
            .firstOrNull ??
        widget.fixedParent?.name ??
        'Pasta selecionada';
  }

  @override
  Widget build(BuildContext context) {
    final fixedParent = widget.fixedParent;
    return AlertDialog(
      title: Text(
        fixedParent == null
            ? 'Nova pasta'
            : 'Criar subpasta em ${fixedParent.name}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.allowParentSelection) ...[
              OutlinedButton.icon(
                key: const Key('choose-folder-parent'),
                onPressed: _loadingDestinations ? null : _chooseDestination,
                icon: _loadingDestinations
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.drive_file_move_outline),
                label: Text(
                  'Local: $_destinationLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const Key('category-name-field'),
              controller: _controller,
              autofocus: true,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: fixedParent == null
                    ? 'Nome da pasta'
                    : 'Nome da subpasta',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('save-category-button'),
          onPressed: _saving || _loadingDestinations ? null : _save,
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
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = categoryValidationMessage(error.error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Não foi possível renomear a pasta.';
      });
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

Future<Category?> showMoveCategoryDialog(
  BuildContext context,
  CategoryRepository repository,
  Category category,
) {
  return showDialog<Category>(
    context: context,
    builder: (_) =>
        _MoveCategoryDialog(repository: repository, category: category),
  );
}

class _MoveCategoryDialog extends StatefulWidget {
  const _MoveCategoryDialog({required this.repository, required this.category});

  final CategoryRepository repository;
  final Category category;

  @override
  State<_MoveCategoryDialog> createState() => _MoveCategoryDialogState();
}

class _MoveCategoryDialogState extends State<_MoveCategoryDialog> {
  List<CategoryTreeEntry> _destinations = const [];
  Set<int> _invalidIds = const {};
  int? _selectedParentId;
  bool _loading = true;
  bool _moving = false;
  bool _selectingDestination = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedParentId = widget.category.parentId;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        widget.repository.loadCategories(),
        widget.repository.loadDescendants(widget.category.id),
      ]);
      if (!mounted) return;
      final summaries = results[0] as List<CategorySummary>;
      final descendants = results[1] as List<Category>;
      setState(() {
        _destinations = buildCategoryTreeEntries(summaries);
        _invalidIds = {
          widget.category.id,
          ...descendants.map((item) => item.id),
        };
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar os destinos.';
      });
    }
  }

  Future<void> _chooseDestination() async {
    if (_loading || _moving || _selectingDestination) return;
    setState(() => _selectingDestination = true);
    final selection = await showFolderDestinationSheet(
      context,
      entries: _destinations,
      currentParentId: widget.category.parentId,
      selectedParentId: _selectedParentId,
      invalidIds: _invalidIds,
      title: 'Mover ${widget.category.name} para',
    );
    if (!mounted) return;
    setState(() {
      _selectingDestination = false;
      if (selection != null) _selectedParentId = selection.parentId;
    });
  }

  Future<void> _move() async {
    if (_moving || _selectedParentId == widget.category.parentId) return;
    setState(() {
      _moving = true;
      _error = null;
    });
    try {
      final moved = await widget.repository.moveCategory(
        widget.category,
        parentId: _selectedParentId,
      );
      if (mounted) Navigator.pop(context, moved);
    } on CategoryValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _moving = false;
        _error = error.error == CategoryValidationError.duplicate
            ? 'Já existe uma pasta com esse nome no destino escolhido.'
            : categoryValidationMessage(error.error);
      });
    } on CategoryHierarchyException catch (error) {
      if (!mounted) return;
      setState(() {
        _moving = false;
        _error = switch (error.error) {
          CategoryHierarchyError.selfParent =>
            'Uma pasta não pode ser movida para dentro dela mesma.',
          CategoryHierarchyError.cycle =>
            'Uma pasta não pode ser movida para uma de suas subpastas.',
          _ => 'Não foi possível mover a pasta.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _moving = false;
        _error = 'Não foi possível mover a pasta.';
      });
    }
  }

  String get _selectedLabel {
    if (_selectedParentId == null) return 'Raiz';
    return _destinations
            .where((entry) => entry.summary.category.id == _selectedParentId)
            .map((entry) => entry.path)
            .firstOrNull ??
        'Pasta selecionada';
  }

  @override
  Widget build(BuildContext context) {
    final unchanged = _selectedParentId == widget.category.parentId;
    return AlertDialog(
      title: Text(
        'Mover ${widget.category.name}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            OutlinedButton.icon(
              key: const Key('choose-move-destination'),
              onPressed: _moving ? null : _chooseDestination,
              icon: const Icon(Icons.drive_file_move_outline),
              label: Text(
                'Destino: $_selectedLabel${unchanged ? ' (atual)' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _moving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirm-category-move'),
          onPressed: _loading || _moving || unchanged ? null : _move,
          child: _moving
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Mover'),
        ),
      ],
    );
  }
}

class FolderDestinationSelection {
  const FolderDestinationSelection(this.parentId);

  final int? parentId;
}

Future<FolderDestinationSelection?> showFolderDestinationSheet(
  BuildContext context, {
  required List<CategoryTreeEntry> entries,
  required int? currentParentId,
  required String title,
  int? selectedParentId,
  Set<int> invalidIds = const {},
}) {
  return showModalBottomSheet<FolderDestinationSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView(
                key: const Key('folder-destination-list'),
                shrinkWrap: true,
                children: [
                  _DestinationTile(
                    key: const Key('destination-root'),
                    label: 'Raiz',
                    depth: 0,
                    selected: selectedParentId == null,
                    current: currentParentId == null,
                    onTap: () => Navigator.pop(
                      context,
                      const FolderDestinationSelection(null),
                    ),
                  ),
                  for (final entry in entries)
                    _DestinationTile(
                      key: Key('destination-${entry.summary.category.id}'),
                      label: entry.path,
                      depth: entry.depth,
                      selected: selectedParentId == entry.summary.category.id,
                      current: currentParentId == entry.summary.category.id,
                      enabled: !invalidIds.contains(entry.summary.category.id),
                      onTap: () => Navigator.pop(
                        context,
                        FolderDestinationSelection(entry.summary.category.id),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    super.key,
    required this.label,
    required this.depth,
    required this.selected,
    required this.current,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final int depth;
  final bool selected;
  final bool current;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: enabled,
      enabled: enabled,
      selected: selected,
      label: '$label${current ? ', destino atual' : ''}',
      child: ListTile(
        enabled: enabled,
        contentPadding: EdgeInsets.only(
          left: 16 + depth.clamp(0, 6) * 12,
          right: 16,
        ),
        onTap: enabled ? onTap : null,
        leading: Icon(
          depth == 0 ? Icons.folder_outlined : Icons.subdirectory_arrow_right,
        ),
        title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: current ? const Text('Destino atual') : null,
        trailing: !enabled
            ? const Tooltip(
                message: 'Destino inválido',
                child: Icon(Icons.block_outlined),
              )
            : selected
            ? const Icon(Icons.check)
            : null,
      ),
    );
  }
}

Future<bool> confirmCategoryDeletion(
  BuildContext context,
  CategoryRepository repository,
  CategorySummary summary,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) =>
            _DeleteCategoryDialog(repository: repository, summary: summary),
      ) ??
      false;
}

class _DeleteCategoryDialog extends StatefulWidget {
  const _DeleteCategoryDialog({
    required this.repository,
    required this.summary,
  });

  final CategoryRepository repository;
  final CategorySummary summary;

  @override
  State<_DeleteCategoryDialog> createState() => _DeleteCategoryDialogState();
}

class _DeleteCategoryDialogState extends State<_DeleteCategoryDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.repository.deleteCategory(widget.summary.category.id);
      if (mounted) Navigator.pop(context, true);
    } on CategoryHierarchyException catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = error.error == CategoryHierarchyError.hasChildren
            ? 'Esta pasta possui subpastas e não pode ser excluída.'
            : 'Não foi possível excluir a pasta.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = 'Não foi possível excluir a pasta.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    return AlertDialog(
      title: Text('Excluir “${summary.category.name}”?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${summary.mediaCount} '
            '${summary.mediaCount == 1 ? 'print está associado' : 'prints estão associados'}. '
            'A pasta e suas associações serão removidas. '
            'Os prints não serão excluídos.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('confirm-category-deletion'),
          onPressed: _deleting ? null : _delete,
          child: _deleting
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Excluir pasta',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
        ),
      ],
    );
  }
}

String categoryValidationMessage(CategoryValidationError error) {
  return switch (error) {
    CategoryValidationError.empty => 'Digite um nome para a pasta.',
    CategoryValidationError.tooLong => 'Use no máximo 40 caracteres.',
    CategoryValidationError.duplicate => 'Já existe uma pasta com esse nome.',
  };
}

import 'package:flutter/material.dart';

import '../data/category_repository.dart';
import '../domain/category.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({required this.repository, super.key});

  final CategoryRepository repository;

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
      final categories = await widget.repository.loadCategories();
      if (mounted) {
        setState(() => _categories = categories);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar as categorias.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await showCreateCategoryDialog(context, widget.repository);
    if (created != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias'),
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
                      child: Center(child: Text('Nenhuma categoria criada.')),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final summary = _categories[index];
                          final count = summary.mediaCount;
                          return Card(
                            child: ListTile(
                              title: Text(
                                summary.category.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '$count ${count == 1 ? 'screenshot' : 'screenshots'}',
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
                    label: const Text('Nova categoria'),
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
            CategoryValidationError.empty =>
              'Informe um nome para a categoria.',
            CategoryValidationError.tooLong => 'Use no máximo 40 caracteres.',
            CategoryValidationError.duplicate => 'Essa categoria já existe.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível criar a categoria.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova categoria'),
      content: TextField(
        key: const Key('category-name-field'),
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'Nome da categoria',
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

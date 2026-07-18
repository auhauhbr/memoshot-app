import 'package:flutter/material.dart';

import '../data/category_repository.dart';
import '../domain/category.dart';
import 'folder_management_dialogs.dart';

class CategorySelectionPage extends StatefulWidget {
  const CategorySelectionPage({
    required this.repository,
    required this.mediaItemId,
    super.key,
  });

  final CategoryRepository repository;
  final int mediaItemId;

  @override
  State<CategorySelectionPage> createState() => _CategorySelectionPageState();
}

class _CategorySelectionPageState extends State<CategorySelectionPage> {
  List<CategorySummary> _categories = const [];
  Set<int> _selected = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object>([
        widget.repository.loadCategories(),
        widget.repository.loadForMedia(widget.mediaItemId),
      ]);
      if (mounted) {
        setState(() {
          _categories = values[0] as List<CategorySummary>;
          _selected = {
            for (final category in values[1] as List<Category>) category.id,
          };
          _error = null;
        });
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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.replaceForMedia(widget.mediaItemId, _selected);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível atualizar as categorias.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar categorias'),
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
                  else if (_categories.isEmpty)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Nenhuma categoria criada.'),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _create,
                            child: const Text('Nova categoria'),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          for (final summary in _categories)
                            CheckboxListTile(
                              key: ValueKey(
                                'category-checkbox-${summary.category.id}',
                              ),
                              value: _selected.contains(summary.category.id),
                              onChanged: _saving
                                  ? null
                                  : (checked) => setState(() {
                                      if (checked == true) {
                                        _selected.add(summary.category.id);
                                      } else {
                                        _selected.remove(summary.category.id);
                                      }
                                    }),
                              title: Text(
                                summary.category.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                        ],
                      ),
                    ),
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: colors.error)),
                    const SizedBox(height: 8),
                  ],
                  if (!_loading && _categories.isNotEmpty)
                    FilledButton(
                      key: const Key('save-category-selection'),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Salvar'),
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

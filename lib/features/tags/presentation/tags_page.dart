import 'package:flutter/material.dart';

import '../data/tag_repository.dart';
import '../domain/tag.dart';

class TagsPage extends StatefulWidget {
  const TagsPage({required this.repository, super.key});

  final TagRepository repository;

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  List<TagSummary> _summaries = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final summaries = await widget.repository.loadTagSummaries();
      if (mounted) setState(() => _summaries = summaries);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Não foi possível carregar as etiquetas.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _create() async {
    final tag = await showCreateTagDialog(context, widget.repository);
    if (tag == null || !mounted) return;
    setState(() {
      _summaries = _sortSummaries([
        ..._summaries,
        TagSummary(tag: tag, mediaCount: 0),
      ]);
    });
  }

  Future<void> _rename(TagSummary summary) async {
    final tag = await showRenameTagDialog(
      context,
      widget.repository,
      summary.tag,
    );
    if (tag == null || !mounted) return;
    setState(() {
      _summaries = _sortSummaries([
        for (final item in _summaries)
          if (item.tag.id == tag.id)
            TagSummary(tag: tag, mediaCount: item.mediaCount)
          else
            item,
      ]);
    });
  }

  Future<void> _delete(TagSummary summary) async {
    final deleted = await showDeleteTagDialog(
      context,
      widget.repository,
      summary,
    );
    if (deleted != true || !mounted) return;
    setState(() {
      _summaries = _summaries
          .where((item) => item.tag.id != summary.tag.id)
          .toList(growable: false);
    });
  }

  List<TagSummary> _sortSummaries(List<TagSummary> summaries) {
    return summaries..sort((first, second) {
      final byName = first.tag.normalizedName.compareTo(
        second.tag.normalizedName,
      );
      return byName != 0 ? byName : first.tag.id.compareTo(second.tag.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Etiquetas'),
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
                  if (_isLoading)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          key: Key('tags-page-loading'),
                        ),
                      ),
                    )
                  else if (_errorMessage != null)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.error),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              key: const Key('retry-tags-button'),
                              onPressed: _load,
                              icon: const Icon(Icons.refresh, size: 19),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_summaries.isEmpty)
                    const Expanded(
                      child: Center(child: Text('Nenhuma etiqueta criada.')),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _summaries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final summary = _summaries[index];
                          return Card(
                            child: ListTile(
                              key: ValueKey('tag-tile-${summary.tag.id}'),
                              leading: Icon(
                                Icons.label_outline,
                                color: colors.secondary,
                              ),
                              title: Text(
                                summary.tag.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _mediaCountLabel(summary.mediaCount),
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip:
                                    'Ações da etiqueta ${summary.tag.name}',
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
                                      'Excluir etiqueta',
                                      style: TextStyle(color: colors.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('new-tag-button'),
                    onPressed: _isLoading ? null : _create,
                    icon: const Icon(Icons.add, size: 19),
                    label: const Text('Nova etiqueta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _mediaCountLabel(int count) {
    if (count == 0) return 'Nenhum screenshot';
    return '$count ${count == 1 ? 'screenshot' : 'screenshots'}';
  }
}

Future<Tag?> showCreateTagDialog(
  BuildContext context,
  TagRepository repository,
) {
  return showDialog<Tag>(
    context: context,
    builder: (_) => _TagNameDialog(
      title: 'Nova etiqueta',
      actionLabel: 'Criar',
      fieldKey: const Key('new-tag-name-field'),
      actionKey: const Key('save-new-tag-button'),
      onSave: repository.createTag,
      genericErrorMessage: 'Não foi possível criar a etiqueta.',
      duplicateErrorMessage: 'Esta etiqueta já existe.',
    ),
  );
}

Future<Tag?> showRenameTagDialog(
  BuildContext context,
  TagRepository repository,
  Tag tag,
) {
  return showDialog<Tag>(
    context: context,
    builder: (_) => _TagNameDialog(
      title: 'Renomear etiqueta',
      actionLabel: 'Salvar',
      initialName: tag.name,
      fieldKey: const Key('rename-tag-name-field'),
      actionKey: const Key('save-tag-rename-button'),
      onSave: (name) => repository.renameTag(tag, name),
      genericErrorMessage: 'Não foi possível renomear a etiqueta.',
      duplicateErrorMessage: 'Já existe uma etiqueta com esse nome.',
    ),
  );
}

class _TagNameDialog extends StatefulWidget {
  const _TagNameDialog({
    required this.title,
    required this.actionLabel,
    required this.fieldKey,
    required this.actionKey,
    required this.onSave,
    required this.genericErrorMessage,
    required this.duplicateErrorMessage,
    this.initialName = '',
  });

  final String title;
  final String actionLabel;
  final String initialName;
  final Key fieldKey;
  final Key actionKey;
  final Future<Tag> Function(String name) onSave;
  final String genericErrorMessage;
  final String duplicateErrorMessage;

  @override
  State<_TagNameDialog> createState() => _TagNameDialogState();
}

class _TagNameDialogState extends State<_TagNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_controller.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Digite um nome para a etiqueta.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final tag = await widget.onSave(_controller.text);
      if (mounted) Navigator.pop(context, tag);
    } on TagValidationException catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = switch (error.error) {
            TagValidationError.empty => 'Digite um nome para a etiqueta.',
            TagValidationError.tooLong => 'Use no máximo 40 caracteres.',
            TagValidationError.duplicate => widget.duplicateErrorMessage,
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = widget.genericErrorMessage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'Nome da etiqueta',
          errorText: _errorMessage,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: widget.actionKey,
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.actionLabel),
        ),
      ],
    );
  }
}

Future<bool?> showDeleteTagDialog(
  BuildContext context,
  TagRepository repository,
  TagSummary summary,
) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _DeleteTagDialog(repository: repository, summary: summary),
  );
}

class _DeleteTagDialog extends StatefulWidget {
  const _DeleteTagDialog({required this.repository, required this.summary});

  final TagRepository repository;
  final TagSummary summary;

  @override
  State<_DeleteTagDialog> createState() => _DeleteTagDialogState();
}

class _DeleteTagDialogState extends State<_DeleteTagDialog> {
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _delete() async {
    if (_isDeleting) return;
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });
    try {
      await widget.repository.deleteTag(widget.summary.tag.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _errorMessage = 'Não foi possível excluir a etiqueta.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final summary = widget.summary;
    return AlertDialog(
      title: const Text('Excluir etiqueta?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.mediaCount == 0
                ? 'Deseja excluir a etiqueta “${summary.tag.name}”? '
                      'Os screenshots não serão excluídos.'
                : 'A etiqueta “${summary.tag.name}” está associada a '
                      '${summary.mediaCount} '
                      '${summary.mediaCount == 1 ? 'screenshot' : 'screenshots'}. '
                      'Os screenshots não serão excluídos. Deseja continuar?',
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(_errorMessage!, style: TextStyle(color: colors.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('confirm-tag-deletion'),
          onPressed: _isDeleting ? null : _delete,
          child: _isDeleting
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Excluir', style: TextStyle(color: colors.error)),
        ),
      ],
    );
  }
}

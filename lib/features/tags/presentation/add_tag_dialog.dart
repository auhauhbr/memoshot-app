import 'package:flutter/material.dart';

import '../../../core/text/text_normalizer.dart';
import '../data/tag_repository.dart';
import '../domain/tag.dart';

Future<Tag?> showAddTagDialog(
  BuildContext context, {
  required TagRepository repository,
  required Set<int> associatedTagIds,
}) {
  return showDialog<Tag>(
    context: context,
    builder: (_) => _AddTagDialog(
      repository: repository,
      associatedTagIds: associatedTagIds,
    ),
  );
}

class _AddTagDialog extends StatefulWidget {
  const _AddTagDialog({
    required this.repository,
    required this.associatedTagIds,
  });

  final TagRepository repository;
  final Set<int> associatedTagIds;

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  final TextEditingController _controller = TextEditingController();
  final TextNormalizer _normalizer = const TextNormalizer();
  List<Tag> _tags = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleQueryChanged);
    _loadTags();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    if (mounted) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _loadTags() async {
    try {
      final tags = await widget.repository.loadTags();
      tags.sort((first, second) {
        final byName = first.normalizedName.compareTo(second.normalizedName);
        return byName != 0 ? byName : first.id.compareTo(second.id);
      });
      if (mounted) {
        setState(() {
          _tags = tags;
          _errorMessage = null;
        });
      }
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

  Future<void> _createOrReuse() async {
    if (_isSaving) return;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Digite um nome para a etiqueta.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      Tag tag;
      try {
        tag = await widget.repository.createTag(name);
      } on TagValidationException catch (error) {
        if (error.error == TagValidationError.duplicate) {
          final existing = await widget.repository.findByNormalizedName(name);
          if (existing == null) rethrow;
          tag = existing;
        } else {
          rethrow;
        }
      }
      if (!mounted) return;
      if (widget.associatedTagIds.contains(tag.id)) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Esta etiqueta já está associada.';
        });
        return;
      }
      Navigator.pop(context, tag);
    } on TagValidationException catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = switch (error.error) {
            TagValidationError.empty => 'Digite um nome para a etiqueta.',
            TagValidationError.tooLong => 'Use no máximo 40 caracteres.',
            TagValidationError.duplicate =>
              'Não foi possível adicionar a etiqueta.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Não foi possível adicionar a etiqueta.';
        });
      }
    }
  }

  void _select(Tag tag) {
    if (_isSaving || widget.associatedTagIds.contains(tag.id)) return;
    Navigator.pop(context, tag);
  }

  List<Tag> get _availableTags {
    final query = _normalizer.normalize(_controller.text);
    return _tags
        .where((tag) => !widget.associatedTagIds.contains(tag.id))
        .where((tag) => query.isEmpty || tag.normalizedName.contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final availableTags = _availableTags;
    return AlertDialog(
      scrollable: true,
      title: const Text('Adicionar etiqueta'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('tag-search-field'),
              controller: _controller,
              autofocus: true,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _createOrReuse(),
              decoration: InputDecoration(
                labelText: 'Pesquisar ou criar etiqueta',
                hintText: 'Digite o nome',
                errorText: _errorMessage,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Etiquetas existentes',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 190,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : availableTags.isEmpty
                  ? Center(
                      child: Text(
                        _tags.isEmpty
                            ? 'Nenhuma etiqueta criada.'
                            : 'Nenhuma etiqueta disponível.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: availableTags.length,
                      itemBuilder: (context, index) {
                        final tag = availableTags[index];
                        return ListTile(
                          key: ValueKey('available-tag-${tag.id}'),
                          enabled: !_isSaving,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.label_outline),
                          title: Text(
                            tag.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _select(tag),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          key: const Key('create-and-add-tag-button'),
          onPressed: _isSaving ? null : _createOrReuse,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add, size: 19),
          label: const Text('Criar e adicionar'),
        ),
      ],
    );
  }
}

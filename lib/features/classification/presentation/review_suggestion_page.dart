import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/text/text_normalizer.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_tree.dart';
import '../../categories/presentation/folder_management_dialogs.dart';
import '../../library/data/media_item_repository.dart';
import '../../library/presentation/media_item_thumbnail.dart';
import '../../library/presentation/screenshot_detail_page.dart';
import '../../ocr/data/ocr_repository.dart';
import '../../processing/data/ocr_queue_processor.dart';
import '../../tags/data/tag_repository.dart';
import '../../tags/domain/tag.dart';
import '../application/review_decision.dart';
import '../application/review_queue.dart';

enum ReviewPageResult { accepted, rejected, removed }

class ReviewSuggestionPage extends StatefulWidget {
  const ReviewSuggestionPage({
    required this.item,
    required this.decisionProcessor,
    required this.mediaRepository,
    required this.ocrRepository,
    required this.ocrQueue,
    required this.categoryRepository,
    required this.tagRepository,
    super.key,
  });

  final ReviewQueueItem item;
  final ReviewDecisionProcessor decisionProcessor;
  final MediaItemRepository mediaRepository;
  final OcrRepository ocrRepository;
  final OcrQueue ocrQueue;
  final CategoryRepository categoryRepository;
  final TagRepository tagRepository;

  @override
  State<ReviewSuggestionPage> createState() => _ReviewSuggestionPageState();
}

class _ReviewSuggestionPageState extends State<ReviewSuggestionPage> {
  Category? _selectedCategory;
  List<Tag> _selectedTags = const [];
  List<String> _newTagNames = const [];
  List<CategorySummary> _categorySummaries = const [];
  bool _loading = true;
  bool _editing = false;
  bool _resolving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSelection());
  }

  Future<void> _loadSelection() async {
    try {
      final values = await Future.wait<Object>([
        ReviewSelectionLoader(
          categoryRepository: widget.categoryRepository,
          tagRepository: widget.tagRepository,
        ).load(widget.item.suggestion),
        widget.categoryRepository.loadCategories(),
      ]);
      if (!mounted) return;
      final selection = values[0] as ReviewSelection;
      setState(() {
        _selectedCategory = selection.selectedCategory;
        _selectedTags = selection.selectedTags;
        _newTagNames = selection.newTagNames;
        _categorySummaries = values[1] as List<CategorySummary>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar as opções de organização.';
      });
    }
  }

  Future<void> _chooseCategory() async {
    final category = await showCategoryPickerSheet(
      context,
      entries: buildCategoryTreeEntries(_categorySummaries),
      selectedCategoryId: _selectedCategory?.id,
    );
    if (category != null && mounted) {
      setState(() => _selectedCategory = category);
    }
  }

  Future<void> _createCategory() async {
    final category = await showCreateCategoryDialog(
      context,
      widget.categoryRepository,
      allowParentSelection: true,
    );
    if (category == null || !mounted) return;
    try {
      final summaries = await widget.categoryRepository.loadCategories();
      if (!mounted) return;
      setState(() {
        _categorySummaries = summaries;
        _selectedCategory = category;
      });
    } catch (_) {
      if (mounted) setState(() => _selectedCategory = category);
    }
  }

  Future<void> _editTags() async {
    final result = await showDialog<_TagSelection>(
      context: context,
      builder: (_) => _ReviewTagDialog(
        repository: widget.tagRepository,
        selectedTags: _selectedTags,
        newTagNames: _newTagNames,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedTags = result.tags;
        _newTagNames = result.newNames;
      });
    }
  }

  Future<bool> _confirmWithoutCategory() async {
    if (_selectedCategory != null) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar sem pasta?'),
            content: const Text(
              'Escolha uma pasta ou confirme que o print ficará sem pasta. '
              'As etiquetas selecionadas ainda serão aplicadas.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Escolher pasta'),
              ),
              FilledButton(
                key: const Key('confirm-without-folder'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continuar sem pasta'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _confirm() async {
    if (_resolving || !await _confirmWithoutCategory() || !mounted) return;
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      await widget.decisionProcessor.resolve(
        ReviewDecision.confirm(
          mediaItemId: widget.item.mediaItem.id,
          selectedCategoryId: _selectedCategory?.id,
          selectedTagIds: _selectedTags.map((tag) => tag.id),
          newTagNames: _newTagNames,
        ),
      );
      if (mounted) Navigator.pop(context, ReviewPageResult.accepted);
    } on ReviewDecisionException catch (error) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _error = _decisionError(error.failure, rejecting: false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _error = 'Não foi possível aplicar a organização.';
      });
    }
  }

  Future<void> _reject() async {
    if (_resolving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeitar sugestão?'),
        content: const Text(
          'Deseja rejeitar esta sugestão? O print e sua organização atual '
          'serão preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('confirm-review-rejection'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      await widget.decisionProcessor.resolve(
        ReviewDecision.reject(mediaItemId: widget.item.mediaItem.id),
      );
      if (mounted) Navigator.pop(context, ReviewPageResult.rejected);
    } on ReviewDecisionException catch (error) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _error = _decisionError(error.failure, rejecting: true);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _error = 'Não foi possível rejeitar a sugestão.';
      });
    }
  }

  Future<void> _openScreenshotDetails() async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScreenshotDetailPage(
          mediaItem: widget.item.mediaItem,
          mediaRepository: widget.mediaRepository,
          ocrRepository: widget.ocrRepository,
          ocrQueue: widget.ocrQueue,
          categoryRepository: widget.categoryRepository,
          tagRepository: widget.tagRepository,
        ),
      ),
    );
    if (removed == true && mounted) {
      Navigator.pop(context, ReviewPageResult.removed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar sugestão')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: MediaItemThumbnail(
                            mediaItem: widget.item.mediaItem,
                            key: const Key('review-suggestion-image'),
                            fit: BoxFit.contain,
                            showMessage: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _OriginalSuggestion(item: widget.item),
                        const SizedBox(height: 12),
                        _SelectionCard(
                          selectedCategory: _selectedCategory,
                          categoryWasSuggested:
                              widget.item.suggestion.suggestedCategoryName !=
                              null,
                          selectedTags: _selectedTags,
                          newTagNames: _newTagNames,
                          editing: _editing,
                          disabled: _resolving,
                          onChooseCategory: _chooseCategory,
                          onClearCategory: () =>
                              setState(() => _selectedCategory = null),
                          onCreateCategory: _createCategory,
                          onEditTags: _editTags,
                        ),
                        const SizedBox(height: 12),
                        _EvidenceCard(item: widget.item),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            key: const Key('review-decision-error'),
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          key: const Key('confirm-organization'),
                          onPressed: _resolving ? null : _confirm,
                          icon: _resolving
                              ? const SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('Confirmar organização'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('adjust-organization'),
                          onPressed: _resolving
                              ? null
                              : () => setState(() => _editing = true),
                          icon: const Icon(Icons.tune),
                          label: const Text('Ajustar'),
                        ),
                        TextButton(
                          key: const Key('reject-suggestion'),
                          onPressed: _resolving ? null : _reject,
                          child: const Text('Rejeitar sugestão'),
                        ),
                        TextButton(
                          key: const Key('review-later'),
                          onPressed: _resolving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Revisar depois'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('open-screenshot-details-from-review'),
                          onPressed: _resolving ? null : _openScreenshotDetails,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Abrir detalhes do screenshot'),
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

String _decisionError(
  ReviewDecisionFailure failure, {
  required bool rejecting,
}) {
  return switch (failure) {
    ReviewDecisionFailure.alreadyResolved => 'Esta sugestão já foi resolvida.',
    ReviewDecisionFailure.mediaNotFound => 'Este print não existe mais.',
    ReviewDecisionFailure.categoryNotFound =>
      'A pasta escolhida não está mais disponível.',
    ReviewDecisionFailure.tagNotFound =>
      'Uma etiqueta escolhida não está mais disponível.',
    ReviewDecisionFailure.suggestionNotFound =>
      'Esta sugestão não está mais disponível.',
    ReviewDecisionFailure.invalidTag => 'Uma etiqueta escolhida é inválida.',
  };
}

class _OriginalSuggestion extends StatelessWidget {
  const _OriginalSuggestion({required this.item});

  final ReviewQueueItem item;

  @override
  Widget build(BuildContext context) {
    return _InformationCard(
      children: [
        Text(
          'Sugestão original',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(item.categoryLabel),
        const SizedBox(height: 5),
        Text(item.reviewReasonLabel),
        const SizedBox(height: 5),
        Text(item.confidenceLabel),
        if (item.tagNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Etiquetas sugeridas'),
          const SizedBox(height: 3),
          Text(item.tagNames.join(', ')),
        ],
      ],
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.selectedCategory,
    required this.categoryWasSuggested,
    required this.selectedTags,
    required this.newTagNames,
    required this.editing,
    required this.disabled,
    required this.onChooseCategory,
    required this.onClearCategory,
    required this.onCreateCategory,
    required this.onEditTags,
  });

  final Category? selectedCategory;
  final bool categoryWasSuggested;
  final List<Tag> selectedTags;
  final List<String> newTagNames;
  final bool editing;
  final bool disabled;
  final VoidCallback onChooseCategory;
  final VoidCallback onClearCategory;
  final VoidCallback onCreateCategory;
  final VoidCallback onEditTags;

  @override
  Widget build(BuildContext context) {
    final tagNames = [...selectedTags.map((tag) => tag.name), ...newTagNames];
    return _InformationCard(
      children: [
        Text(
          'Organização escolhida',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          selectedCategory == null
              ? categoryWasSuggested
                    ? 'Pasta sugerida ainda não criada'
                    : 'Nenhuma pasta selecionada'
              : 'Pasta: ${selectedCategory!.name}',
          key: const Key('selected-review-folder'),
        ),
        if (selectedCategory == null) ...[
          const SizedBox(height: 4),
          Text(
            'Este print continuará sem pasta.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 7),
        Text(
          tagNames.isEmpty
              ? 'Nenhuma etiqueta selecionada'
              : 'Etiquetas: ${tagNames.join(', ')}',
          key: const Key('selected-review-tags'),
        ),
        if (editing) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('choose-review-folder'),
                onPressed: disabled ? null : onChooseCategory,
                child: const Text('Escolher pasta'),
              ),
              OutlinedButton(
                key: const Key('create-review-folder'),
                onPressed: disabled ? null : onCreateCategory,
                child: const Text('Criar pasta'),
              ),
              if (selectedCategory != null)
                TextButton(
                  onPressed: disabled ? null : onClearCategory,
                  child: const Text('Deixar sem pasta'),
                ),
              OutlinedButton(
                key: const Key('edit-review-tags'),
                onPressed: disabled ? null : onEditTags,
                child: const Text('Editar etiquetas'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.item});

  final ReviewQueueItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _InformationCard(
      children: [
        Text('Evidências', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (item.suggestion.evidence.isEmpty)
          const Text('Nenhuma evidência adicional disponível.')
        else
          for (final evidence in item.suggestion.evidence) ...[
            Text('• ${evidence.description}'),
            if (evidence.safeMatch != null)
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 2),
                child: Text(
                  'Termo identificado: ${evidence.safeMatch}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 7),
          ],
      ],
    );
  }
}

class _TagSelection {
  const _TagSelection(this.tags, this.newNames);

  final List<Tag> tags;
  final List<String> newNames;
}

class _ReviewTagDialog extends StatefulWidget {
  const _ReviewTagDialog({
    required this.repository,
    required this.selectedTags,
    required this.newTagNames,
  });

  final TagRepository repository;
  final List<Tag> selectedTags;
  final List<String> newTagNames;

  @override
  State<_ReviewTagDialog> createState() => _ReviewTagDialogState();
}

class _ReviewTagDialogState extends State<_ReviewTagDialog> {
  final _controller = TextEditingController();
  final _normalizer = const TextNormalizer();
  List<Tag> _tags = const [];
  late final Set<int> _selectedIds = {
    for (final tag in widget.selectedTags) tag.id,
  };
  late final List<String> _newNames = [...widget.newTagNames];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final tags = await widget.repository.loadTags();
      if (mounted) setState(() => _tags = tags);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar as etiquetas.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addName() {
    final name = _controller.text.trim();
    final normalized = _normalizer.normalize(name);
    if (normalized.isEmpty) {
      setState(() => _error = 'Digite um nome para a etiqueta.');
      return;
    }
    if (name.length > 40) {
      setState(() => _error = 'Use no máximo 40 caracteres.');
      return;
    }
    final existing = _tags.where((tag) => tag.normalizedName == normalized);
    setState(() {
      if (existing.isNotEmpty) {
        _selectedIds.add(existing.first.id);
      } else if (!_newNames.any(
        (item) => _normalizer.normalize(item) == normalized,
      )) {
        _newNames.add(name);
      }
      _controller.clear();
      _error = null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar etiquetas'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loading) const LinearProgressIndicator(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final tag in _tags)
                    CheckboxListTile(
                      key: ValueKey('review-tag-${tag.id}'),
                      value: _selectedIds.contains(tag.id),
                      title: Text(tag.name),
                      onChanged: (selected) => setState(() {
                        selected == true
                            ? _selectedIds.add(tag.id)
                            : _selectedIds.remove(tag.id);
                      }),
                    ),
                  for (final name in _newNames)
                    CheckboxListTile(
                      key: ValueKey('review-new-tag-$name'),
                      value: true,
                      title: Text(name),
                      subtitle: const Text('Nova etiqueta'),
                      onChanged: (selected) {
                        if (selected == false) {
                          setState(() => _newNames.remove(name));
                        }
                      },
                    ),
                ],
              ),
            ),
            TextField(
              key: const Key('review-new-tag-field'),
              controller: _controller,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: 'Adicionar etiqueta',
                errorText: _error,
              ),
              onSubmitted: (_) => _addName(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('add-review-tag-name'),
                onPressed: _addName,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('save-review-tags'),
          onPressed: () => Navigator.pop(
            context,
            _TagSelection(
              _tags.where((tag) => _selectedIds.contains(tag.id)).toList(),
              List.unmodifiable(_newNames),
            ),
          ),
          child: const Text('Concluir'),
        ),
      ],
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

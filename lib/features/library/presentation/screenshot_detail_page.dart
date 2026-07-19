import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/media_store/media_store_content.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_selection_page.dart';
import '../data/media_item_repository.dart';
import '../domain/media_item.dart';
import 'media_item_thumbnail.dart';
import '../../ocr/data/ocr_repository.dart';
import '../../ocr/domain/ocr_result.dart';
import '../../processing/data/ocr_queue_processor.dart';
import '../../processing/domain/processing_job.dart';
import '../../tags/data/tag_repository.dart';
import '../../tags/domain/tag.dart';
import '../../tags/presentation/add_tag_dialog.dart';

class ScreenshotDetailPage extends StatefulWidget {
  const ScreenshotDetailPage({
    required this.mediaItem,
    required this.mediaRepository,
    required this.ocrRepository,
    required this.ocrQueue,
    required this.categoryRepository,
    required this.tagRepository,
    this.thumbnailGateway = const MethodChannelMediaStoreContentGateway(),
    super.key,
  });

  final MediaItem mediaItem;
  final MediaItemRepository mediaRepository;
  final OcrRepository ocrRepository;
  final OcrQueue ocrQueue;
  final CategoryRepository categoryRepository;
  final TagRepository tagRepository;
  final MediaStoreContentGateway thumbnailGateway;

  @override
  State<ScreenshotDetailPage> createState() => _ScreenshotDetailPageState();
}

class _ScreenshotDetailPageState extends State<ScreenshotDetailPage> {
  bool _isRemoving = false;
  bool _isLoadingOcr = true;
  OcrItemState _ocrState = OcrItemState.notScheduled;
  StreamSubscription<int>? _queueSubscription;
  String? _errorMessage;
  String? _ocrErrorMessage;
  OcrResult? _ocrResult;
  late final bool _fileExists;
  List<Category> _categories = const [];
  bool _isLoadingCategories = true;
  String? _categoryError;
  List<Tag> _tags = const [];
  bool _isLoadingTags = true;
  bool _isChangingTags = false;
  String? _tagError;

  @override
  void initState() {
    super.initState();
    final privatePath = widget.mediaItem.privatePath;
    _fileExists = privatePath != null && File(privatePath).existsSync();
    _queueSubscription = widget.ocrQueue.changes.listen((mediaItemId) {
      if (mediaItemId == widget.mediaItem.id) {
        _refreshOcrState();
      }
    });
    _loadOcrResult();
    _loadCategories();
    _loadTags();
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadOcrResult() async {
    try {
      final values = await Future.wait<Object?>([
        widget.ocrRepository.loadFor(widget.mediaItem.id),
        widget.ocrQueue.loadState(widget.mediaItem.id),
      ]);
      if (mounted) {
        setState(() {
          _ocrResult = values[0] as OcrResult?;
          _ocrState = values[1]! as OcrItemState;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ocrErrorMessage = 'Não foi possível carregar o texto reconhecido.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOcr = false;
        });
      }
    }
  }

  Future<void> _processOcr() async {
    if (!_fileExists || _ocrIsActive) {
      return;
    }
    setState(() {
      _ocrState = OcrItemState.pending;
      _ocrErrorMessage = null;
    });
    try {
      await widget.ocrQueue.retry(widget.mediaItem);
      await _refreshOcrState();
    } catch (_) {
      if (mounted) {
        setState(() {
          _ocrErrorMessage = 'Não foi possível extrair o texto da imagem.';
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.categoryRepository.loadForMedia(
        widget.mediaItem.id,
      );
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      if (mounted) {
        setState(
          () => _categoryError = 'Não foi possível carregar as categorias.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _editCategories() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CategorySelectionPage(
          repository: widget.categoryRepository,
          mediaItemId: widget.mediaItem.id,
        ),
      ),
    );
    if (changed == true) await _loadCategories();
  }

  Future<void> _loadTags() async {
    try {
      final tags = await widget.tagRepository.loadForMedia(widget.mediaItem.id);
      if (mounted) {
        setState(() {
          _tags = tags;
          _tagError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _tagError = 'Não foi possível carregar as etiquetas.');
      }
    } finally {
      if (mounted) setState(() => _isLoadingTags = false);
    }
  }

  Future<void> _addTag() async {
    if (_isLoadingTags || _isChangingTags) return;
    final tag = await showAddTagDialog(
      context,
      repository: widget.tagRepository,
      associatedTagIds: _tags.map((tag) => tag.id).toSet(),
    );
    if (tag == null || !mounted || _isChangingTags) return;

    setState(() {
      _isChangingTags = true;
      _tagError = null;
    });
    try {
      final alreadyAssociated =
          _tags.any((item) => item.id == tag.id) ||
          await widget.tagRepository.isAssociated(
            tagId: tag.id,
            mediaItemId: widget.mediaItem.id,
          );
      if (alreadyAssociated) {
        if (mounted) {
          setState(() => _tagError = 'Esta etiqueta já está associada.');
        }
        return;
      }
      await widget.tagRepository.addToMedia(
        tagId: tag.id,
        mediaItemId: widget.mediaItem.id,
      );
      if (mounted) {
        setState(() {
          _tags = [..._tags, tag]
            ..sort((first, second) {
              final byName = first.normalizedName.compareTo(
                second.normalizedName,
              );
              return byName != 0 ? byName : first.id.compareTo(second.id);
            });
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _tagError = 'Não foi possível adicionar a etiqueta.');
      }
    } finally {
      if (mounted) setState(() => _isChangingTags = false);
    }
  }

  Future<void> _removeTag(Tag tag) async {
    if (_isChangingTags) return;
    setState(() {
      _isChangingTags = true;
      _tagError = null;
    });
    try {
      await widget.tagRepository.removeFromMedia(
        tagId: tag.id,
        mediaItemId: widget.mediaItem.id,
      );
      if (mounted) {
        setState(
          () => _tags = _tags.where((item) => item.id != tag.id).toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _tagError = 'Não foi possível remover a etiqueta.');
      }
    } finally {
      if (mounted) setState(() => _isChangingTags = false);
    }
  }

  bool get _ocrIsActive =>
      _ocrState == OcrItemState.pending || _ocrState == OcrItemState.processing;

  Future<void> _refreshOcrState() async {
    try {
      final state = await widget.ocrQueue.loadState(widget.mediaItem.id);
      OcrResult? result = _ocrResult;
      if (state == OcrItemState.completedWithText ||
          state == OcrItemState.completedWithoutText) {
        result = await widget.ocrRepository.loadFor(widget.mediaItem.id);
      }
      if (mounted) {
        setState(() {
          _ocrState = state;
          _ocrResult = result;
          _ocrErrorMessage = state == OcrItemState.failed
              ? 'Não foi possível extrair o texto da imagem.'
              : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ocrErrorMessage = 'Não foi possível carregar o estado do OCR.';
        });
      }
    }
  }

  Future<void> _requestRemoval() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover do MemoShot?'),
        content: Text(
          widget.mediaItem.isMediaStoreReference
              ? 'O item será removido somente do MemoShot. '
                    'A imagem original continuará na galeria.'
              : 'A cópia salva pelo MemoShot será removida. '
                    'O arquivo original da galeria será preservado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isRemoving = true;
      _errorMessage = null;
    });
    try {
      await widget.mediaRepository.removeItem(widget.mediaItem);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRemoving = false;
          _errorMessage = 'Não foi possível remover este screenshot.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do screenshot'),
        backgroundColor: colors.surface,
        foregroundColor: colors.primary,
        surfaceTintColor: colors.surface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 220),
                    height: 390,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: widget.mediaItem.isMediaStoreReference || _fileExists
                        ? MediaItemThumbnail(
                            key: const Key('detail-screenshot-image'),
                            mediaItem: widget.mediaItem,
                            fit: BoxFit.contain,
                            gateway: widget.thumbnailGateway,
                            showMessage: true,
                          )
                        : const _MissingImageState(),
                  ),
                  const SizedBox(height: 14),
                  _MetadataCard(
                    capturedAt: _formatImportedAt(
                      widget.mediaItem.effectiveCapturedAt,
                    ),
                    importOrigin: widget.mediaItem.importOrigin,
                  ),
                  const SizedBox(height: 12),
                  _OcrSection(
                    result: _ocrResult,
                    isLoading: _isLoadingOcr,
                    state: _ocrState,
                    fileAvailable: _fileExists,
                    errorMessage: _ocrErrorMessage,
                    onProcess: _processOcr,
                  ),
                  const SizedBox(height: 12),
                  _CategoriesSection(
                    categories: _categories,
                    isLoading: _isLoadingCategories,
                    errorMessage: _categoryError,
                    onEdit: _editCategories,
                  ),
                  const SizedBox(height: 12),
                  _TagsSection(
                    tags: _tags,
                    isLoading: _isLoadingTags,
                    isChanging: _isChangingTags,
                    errorMessage: _tagError,
                    onAdd: _addTag,
                    onRemove: _removeTag,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 19),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'O arquivo original da galeria não será alterado.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isRemoving ? null : _requestRemoval,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error),
                    ),
                    icon: _isRemoving
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline, size: 19),
                    label: const Text('Remover do MemoShot'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatImportedAt(DateTime date) {
    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day de ${months[date.month - 1]} de ${date.year}, às $hour:$minute';
  }
}

class _TagsSection extends StatelessWidget {
  const _TagsSection({
    required this.tags,
    required this.isLoading,
    required this.isChanging,
    required this.errorMessage,
    required this.onAdd,
    required this.onRemove,
  });

  final List<Tag> tags;
  final bool isLoading;
  final bool isChanging;
  final String? errorMessage;
  final VoidCallback onAdd;
  final ValueChanged<Tag> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      key: const Key('tags-section'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etiquetas',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const SizedBox.square(
              key: Key('tags-loading-indicator'),
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (tags.isEmpty && errorMessage == null)
            const Text('Nenhuma etiqueta adicionada.')
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in tags)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: InputChip(
                      key: ValueKey('tag-chip-${tag.id}'),
                      label: Text(
                        tag.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      deleteButtonTooltipMessage:
                          'Remover etiqueta ${tag.name}',
                      onDeleted: isChanging ? null : () => onRemove(tag),
                    ),
                  ),
              ],
            ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('add-tag-button'),
            onPressed: isLoading || isChanging ? null : onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Adicionar etiqueta'),
          ),
        ],
      ),
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({
    required this.categories,
    required this.isLoading,
    required this.errorMessage,
    required this.onEdit,
  });

  final List<Category> categories;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categorias',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (errorMessage != null)
            Text(errorMessage!, style: TextStyle(color: colors.error))
          else if (categories.isEmpty)
            const Text('Nenhuma categoria atribuída.')
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final category in categories)
                  Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('edit-categories-button'),
            onPressed: isLoading ? null : onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar categorias'),
          ),
        ],
      ),
    );
  }
}

class _MissingImageState extends StatelessWidget {
  const _MissingImageState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'A imagem salva não está disponível.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OcrSection extends StatelessWidget {
  const _OcrSection({
    required this.result,
    required this.isLoading,
    required this.state,
    required this.fileAvailable,
    required this.errorMessage,
    required this.onProcess,
  });

  final OcrResult? result;
  final bool isLoading;
  final OcrItemState state;
  final bool fileAvailable;
  final String? errorMessage;
  final VoidCallback onProcess;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isProcessing =
        state == OcrItemState.pending || state == OcrItemState.processing;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Texto reconhecido',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (state != OcrItemState.notScheduled) ...[
            _DetailOcrStatus(state: state),
            const SizedBox(height: 8),
          ],
          if (isLoading)
            const Align(
              alignment: Alignment.centerLeft,
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (result == null) ...[
            Text(
              fileAvailable
                  ? 'Extraia o texto desta imagem quando desejar.'
                  : 'A imagem precisa estar disponível para extrair texto.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (fileAvailable) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: isProcessing ? null : onProcess,
                icon: isProcessing
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner_outlined, size: 19),
                label: Text(_actionLabel(result: null)),
              ),
            ],
          ] else ...[
            if (result!.fullText.isEmpty)
              Text(
                'Nenhum texto foi encontrado nesta imagem.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              )
            else
              SelectableText(
                result!.fullText,
                key: const Key('recognized-text'),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            if (fileAvailable) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: isProcessing ? null : onProcess,
                  icon: isProcessing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_actionLabel(result: result)),
                ),
              ),
            ],
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }

  String _actionLabel({required OcrResult? result}) {
    if (state == OcrItemState.pending) {
      return 'Aguardando...';
    }
    if (state == OcrItemState.processing) {
      return result == null ? 'Extraindo texto...' : 'Processando novamente...';
    }
    if (state == OcrItemState.failed) {
      return 'Tentar novamente';
    }
    return result == null ? 'Extrair texto' : 'Processar novamente';
  }
}

class _DetailOcrStatus extends StatelessWidget {
  const _DetailOcrStatus({required this.state});

  final OcrItemState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, icon) = switch (state) {
      OcrItemState.pending => ('Aguardando', Icons.schedule_outlined),
      OcrItemState.processing => ('Processando', null),
      OcrItemState.completedWithText => (
        'Texto extraído',
        Icons.check_circle_outline,
      ),
      OcrItemState.completedWithoutText => (
        'Sem texto',
        Icons.check_circle_outline,
      ),
      OcrItemState.failed => ('Falha', Icons.error_outline),
      OcrItemState.notScheduled => ('', null),
    };
    return Row(
      children: [
        if (state == OcrItemState.processing)
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 1.7),
          )
        else
          Icon(
            icon,
            size: 17,
            color: state == OcrItemState.failed
                ? colors.error
                : colors.secondary,
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: state == OcrItemState.failed
                ? colors.error
                : colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.capturedAt, required this.importOrigin});

  final String capturedAt;
  final ImportOrigin importOrigin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _MetadataRow(label: 'Capturado em', value: capturedAt),
          const Divider(height: 20),
          _MetadataRow(
            label: 'Origem',
            value: switch (importOrigin) {
              ImportOrigin.picker => 'Selecionado no dispositivo',
              ImportOrigin.shared => 'Compartilhado com o MemoShot',
              ImportOrigin.automatic => 'Importado automaticamente',
            },
          ),
          const Divider(height: 20),
          const _MetadataRow(label: 'Estado', value: 'Salvo neste dispositivo'),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

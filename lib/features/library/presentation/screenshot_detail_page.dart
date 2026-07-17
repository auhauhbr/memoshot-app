import 'dart:io';

import 'package:flutter/material.dart';

import '../data/media_item_repository.dart';
import '../domain/media_item.dart';

class ScreenshotDetailPage extends StatefulWidget {
  const ScreenshotDetailPage({
    required this.mediaItem,
    required this.mediaRepository,
    super.key,
  });

  final MediaItem mediaItem;
  final MediaItemRepository mediaRepository;

  @override
  State<ScreenshotDetailPage> createState() => _ScreenshotDetailPageState();
}

class _ScreenshotDetailPageState extends State<ScreenshotDetailPage> {
  bool _isRemoving = false;
  String? _errorMessage;

  Future<void> _requestRemoval() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover do Contexto?'),
        content: const Text(
          'A cópia salva pelo Contexto será removida. '
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
                    child: File(widget.mediaItem.privatePath).existsSync()
                        ? Image.file(
                            File(widget.mediaItem.privatePath),
                            key: const Key('detail-screenshot-image'),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const _MissingImageState(),
                          )
                        : const _MissingImageState(),
                  ),
                  const SizedBox(height: 14),
                  _MetadataCard(
                    importedAt: _formatImportedAt(widget.mediaItem.importedAt),
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
                    label: const Text('Remover do Contexto'),
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

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.importedAt});

  final String importedAt;

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
          _MetadataRow(label: 'Importado em', value: importedAt),
          const Divider(height: 20),
          const _MetadataRow(
            label: 'Origem',
            value: 'Selecionado no dispositivo',
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

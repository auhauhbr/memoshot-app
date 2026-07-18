import 'dart:io';

import 'package:flutter/material.dart';

import '../../categories/data/category_repository.dart';
import '../../library/data/media_item_repository.dart';
import '../../library/presentation/screenshot_detail_page.dart';
import '../../ocr/data/ocr_repository.dart';
import '../../processing/data/ocr_queue_processor.dart';
import '../../tags/data/tag_repository.dart';
import '../application/review_queue.dart';

class ReviewSuggestionPage extends StatelessWidget {
  const ReviewSuggestionPage({
    required this.item,
    required this.mediaRepository,
    required this.ocrRepository,
    required this.ocrQueue,
    required this.categoryRepository,
    required this.tagRepository,
    super.key,
  });

  final ReviewQueueItem item;
  final MediaItemRepository mediaRepository;
  final OcrRepository ocrRepository;
  final OcrQueue ocrQueue;
  final CategoryRepository categoryRepository;
  final TagRepository tagRepository;

  Future<void> _openScreenshotDetails(BuildContext context) async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScreenshotDetailPage(
          mediaItem: item.mediaItem,
          mediaRepository: mediaRepository,
          ocrRepository: ocrRepository,
          ocrQueue: ocrQueue,
          categoryRepository: categoryRepository,
          tagRepository: tagRepository,
        ),
      ),
    );
    if (removed == true && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar sugestão')),
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
                    height: 320,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.file(
                      File(item.mediaItem.privatePath),
                      key: const Key('review-suggestion-image'),
                      fit: BoxFit.contain,
                      semanticLabel: 'Print em revisão',
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined, size: 38),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InformationCard(
                    children: [
                      Text(
                        item.categoryLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(item.reviewReasonLabel),
                      const SizedBox(height: 6),
                      Text(item.confidenceLabel),
                    ],
                  ),
                  if (item.tagNames.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InformationCard(
                      children: [
                        Text(
                          'Etiquetas sugeridas',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final tag in item.tagNames)
                              Chip(
                                label: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 240,
                                  ),
                                  child: Text(
                                    tag,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  _InformationCard(
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
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    key: const Key('open-screenshot-details-from-review'),
                    onPressed: () => _openScreenshotDetails(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir detalhes do screenshot'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'As ações de confirmação serão adicionadas em uma próxima etapa.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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

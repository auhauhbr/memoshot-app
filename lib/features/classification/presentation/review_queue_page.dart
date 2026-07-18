import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../categories/data/category_repository.dart';
import '../../library/data/media_item_repository.dart';
import '../../ocr/data/ocr_repository.dart';
import '../../processing/data/ocr_queue_processor.dart';
import '../../tags/data/tag_repository.dart';
import '../application/review_queue.dart';
import '../application/review_decision.dart';
import 'review_suggestion_page.dart';

class ReviewQueuePage extends StatefulWidget {
  const ReviewQueuePage({
    required this.loader,
    required this.decisionProcessor,
    required this.mediaRepository,
    required this.ocrRepository,
    required this.ocrQueue,
    required this.categoryRepository,
    required this.tagRepository,
    super.key,
  });

  final ReviewQueueLoader loader;
  final ReviewDecisionProcessor decisionProcessor;
  final MediaItemRepository mediaRepository;
  final OcrRepository ocrRepository;
  final OcrQueue ocrQueue;
  final CategoryRepository categoryRepository;
  final TagRepository tagRepository;

  @override
  ReviewQueuePageState createState() => ReviewQueuePageState();
}

class ReviewQueuePageState extends State<ReviewQueuePage> {
  List<ReviewQueueItem> _items = const [];
  bool _isLoading = true;
  String? _errorMessage;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  Future<void> reload({bool showLoading = true}) async {
    final generation = ++_loadGeneration;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final items = await widget.loader.loadPending();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items = items;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items = const [];
        _isLoading = false;
        _errorMessage = 'Não foi possível carregar os prints para revisão.';
      });
    }
  }

  Future<void> _openSuggestion(ReviewQueueItem item) async {
    final result = await Navigator.of(context).push<ReviewPageResult>(
      MaterialPageRoute(
        builder: (_) => ReviewSuggestionPage(
          item: item,
          decisionProcessor: widget.decisionProcessor,
          mediaRepository: widget.mediaRepository,
          ocrRepository: widget.ocrRepository,
          ocrQueue: widget.ocrQueue,
          categoryRepository: widget.categoryRepository,
          tagRepository: widget.tagRepository,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _items = _items
            .where((candidate) => candidate.mediaItem.id != item.mediaItem.id)
            .toList(growable: false);
      });
      if (result == ReviewPageResult.accepted ||
          result == ReviewPageResult.rejected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result == ReviewPageResult.accepted
                  ? 'Organização aplicada.'
                  : 'Sugestão rejeitada.',
            ),
          ),
        );
      }
    }
    await reload(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Para revisar')),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: SizedBox.square(
                  key: Key('review-queue-loading'),
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : _errorMessage != null
            ? _ReviewQueueMessage(
                icon: Icons.error_outline,
                title: _errorMessage!,
                actionLabel: 'Tentar novamente',
                onAction: reload,
              )
            : _items.isEmpty
            ? _ReviewQueueMessage(
                icon: Icons.check_circle_outline,
                title: 'Tudo organizado',
                message: 'Não há prints aguardando revisão.',
                actionLabel: 'Voltar',
                onAction: () => Navigator.of(context).maybePop(),
              )
            : ListView.separated(
                key: const PageStorageKey('review-queue-list'),
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _ReviewQueueCard(
                  item: _items[index],
                  onTap: () => _openSuggestion(_items[index]),
                ),
              ),
      ),
    );
  }
}

class _ReviewQueueCard extends StatelessWidget {
  const _ReviewQueueCard({required this.item, required this.onTap});

  static const visibleTagLimit = 3;

  final ReviewQueueItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleTags = item.tagNames.take(visibleTagLimit).toList();
    final hiddenTagCount = item.tagNames.length - visibleTags.length;
    return Semantics(
      button: true,
      label: 'Abrir revisão. ${item.categoryLabel}. ${item.reviewReasonLabel}',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('review-item-${item.mediaItem.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.file(
                    File(item.mediaItem.privatePath),
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    semanticLabel: 'Miniatura do print para revisão',
                    errorBuilder: (_, _, _) => Container(
                      width: 88,
                      height: 88,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.categoryLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(item.reviewReasonLabel),
                      const SizedBox(height: 4),
                      Text(
                        item.confidenceLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (visibleTags.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [
                            for (final tag in visibleTags)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 110,
                                  ),
                                  child: Text(
                                    tag,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            if (hiddenTagCount > 0)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text('+$hiddenTagCount'),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 5),
                      Text(
                        _formatDate(item.mediaItem.effectiveCapturedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 28),
                  child: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewQueueMessage extends StatelessWidget {
  const _ReviewQueueMessage({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year}, $hour:$minute';
}

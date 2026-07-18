import 'dart:io';

import 'package:flutter/material.dart';

import '../../processing/domain/processing_job.dart';
import '../domain/media_item.dart';

class ScreenshotGrid extends StatelessWidget {
  const ScreenshotGrid({
    required this.mediaItems,
    required this.ocrStates,
    required this.onItemTap,
    this.snippets = const {},
    this.showStorageNote = true,
    super.key,
  });

  final List<MediaItem> mediaItems;
  final Map<int, OcrItemState> ocrStates;
  final Map<int, String> snippets;
  final ValueChanged<MediaItem> onItemTap;
  final bool showStorageNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showStorageNote) ...[
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: colors.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Salvo neste dispositivo.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        GridView.builder(
          key: const Key('persisted-screenshot-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: mediaItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: snippets.isEmpty ? 0.82 : 0.62,
          ),
          itemBuilder: (context, index) {
            final item = mediaItems[index];
            return Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('screenshot-tile-${item.id}'),
                onTap: () => onItemTap(item),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(item.privatePath),
                            key: ValueKey(item.id),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                ColoredBox(
                                  color: colors.surfaceContainerLow,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colors.surface.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.open_in_full,
                                size: 14,
                                color: colors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (snippets[item.id] case final snippet?)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(5, 4, 5, 2),
                        child: Text(
                          snippet,
                          key: ValueKey('search-snippet-${item.id}'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.2,
                          ),
                        ),
                      ),
                    _OcrStatusLabel(
                      state: ocrStates[item.id] ?? OcrItemState.notScheduled,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _OcrStatusLabel extends StatelessWidget {
  const _OcrStatusLabel({required this.state});

  final OcrItemState state;

  @override
  Widget build(BuildContext context) {
    if (state == OcrItemState.notScheduled) {
      return const SizedBox(height: 24);
    }
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
    return SizedBox(
      height: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state == OcrItemState.processing)
              const SizedBox.square(
                dimension: 11,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            else
              Icon(icon, size: 13, color: colors.secondary),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: state == OcrItemState.failed
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

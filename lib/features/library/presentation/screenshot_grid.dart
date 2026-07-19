import 'package:flutter/material.dart';

import '../../../core/media_store/media_store_content.dart';
import '../../processing/domain/processing_job.dart';
import '../domain/media_item.dart';
import 'media_item_thumbnail.dart';

class ScreenshotGridLayout {
  const ScreenshotGridLayout._();

  static const spacing = 8.0;

  static int columnCount({
    required double availableWidth,
    required double textScaleFactor,
  }) {
    if (availableWidth < 340 || textScaleFactor >= 1.3) return 2;
    if (availableWidth >= 480) return 4;
    return 3;
  }

  static SliverGridDelegate delegate({
    required double availableWidth,
    required double textScaleFactor,
  }) => SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columnCount(
      availableWidth: availableWidth,
      textScaleFactor: textScaleFactor,
    ),
    crossAxisSpacing: spacing,
    mainAxisSpacing: spacing,
    childAspectRatio: 1,
  );
}

class ScreenshotGrid extends StatelessWidget {
  const ScreenshotGrid({
    required this.mediaItems,
    required this.ocrStates,
    required this.onItemTap,
    this.snippets = const {},
    this.showStorageNote = true,
    this.thumbnailGateway = const MethodChannelMediaStoreContentGateway(),
    super.key,
  });

  final List<MediaItem> mediaItems;
  final Map<int, OcrItemState> ocrStates;
  final Map<int, String> snippets;
  final ValueChanged<MediaItem> onItemTap;
  final bool showStorageNote;
  final MediaStoreContentGateway thumbnailGateway;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
            key: const Key('persisted-screenshot-grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: mediaItems.length,
            gridDelegate: ScreenshotGridLayout.delegate(
              availableWidth: constraints.maxWidth,
              textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
            ),
            itemBuilder: (context, index) => _ScreenshotTile(
              item: mediaItems[index],
              state:
                  ocrStates[mediaItems[index].id] ?? OcrItemState.notScheduled,
              snippet: snippets[mediaItems[index].id],
              onTap: onItemTap,
              thumbnailGateway: thumbnailGateway,
            ),
          ),
        ),
      ],
    );
  }
}

class ScreenshotSliverGrid extends StatelessWidget {
  const ScreenshotSliverGrid({
    required this.mediaItems,
    required this.ocrStates,
    required this.onItemTap,
    this.snippets = const {},
    this.thumbnailGateway = const MethodChannelMediaStoreContentGateway(),
    super.key,
  });

  final List<MediaItem> mediaItems;
  final Map<int, OcrItemState> ocrStates;
  final Map<int, String> snippets;
  final ValueChanged<MediaItem> onItemTap;
  final MediaStoreContentGateway thumbnailGateway;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid(
        key: const Key('persisted-screenshot-grid'),
        gridDelegate: ScreenshotGridLayout.delegate(
          availableWidth: constraints.crossAxisExtent,
          textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = mediaItems[index];
          return _ScreenshotTile(
            item: item,
            state: ocrStates[item.id] ?? OcrItemState.notScheduled,
            snippet: snippets[item.id],
            onTap: onItemTap,
            thumbnailGateway: thumbnailGateway,
          );
        }, childCount: mediaItems.length),
      ),
    );
  }
}

class _ScreenshotTile extends StatelessWidget {
  const _ScreenshotTile({
    required this.item,
    required this.state,
    required this.snippet,
    required this.onTap,
    required this.thumbnailGateway,
  });

  final MediaItem item;
  final OcrItemState state;
  final String? snippet;
  final ValueChanged<MediaItem> onTap;
  final MediaStoreContentGateway thumbnailGateway;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      image: true,
      label: 'Miniatura do print. Toque para abrir.',
      child: Material(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('screenshot-tile-${item.id}'),
          onTap: () => onTap(item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: colors.surfaceContainerLow,
                child: MediaItemThumbnail(
                  mediaItem: item,
                  key: ValueKey(item.id),
                  fit: BoxFit.contain,
                  cacheWidth: compactThumbnailDecodeSize,
                  cacheHeight: compactThumbnailDecodeSize,
                  gateway: thumbnailGateway,
                ),
              ),
              if (snippet case final value?)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          colors.scrim.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                    child: Text(
                      value,
                      key: ValueKey('search-snippet-${item.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: colors.surface),
                    ),
                  ),
                ),
              if (state == OcrItemState.processing)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

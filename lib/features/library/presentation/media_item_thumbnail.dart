import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/media_store/media_store_content.dart';
import '../domain/media_item.dart';

const compactThumbnailDecodeSize = 192;
const regularThumbnailDecodeSize = 512;

class MediaItemThumbnail extends StatefulWidget {
  const MediaItemThumbnail({
    required this.mediaItem,
    this.fit = BoxFit.cover,
    this.gateway = const MethodChannelMediaStoreContentGateway(),
    this.showMessage = false,
    this.cacheWidth = regularThumbnailDecodeSize,
    this.cacheHeight = regularThumbnailDecodeSize,
    super.key,
  });

  final MediaItem mediaItem;
  final BoxFit fit;
  final MediaStoreContentGateway gateway;
  final bool showMessage;
  final int cacheWidth;
  final int cacheHeight;

  @override
  State<MediaItemThumbnail> createState() => _MediaItemThumbnailState();
}

class _MediaItemThumbnailState extends State<MediaItemThumbnail> {
  ReferencedMediaThumbnail? _referencedResult;
  bool _referencedLoading = false;
  int _generation = 0;
  int _privateRetry = 0;

  @override
  void initState() {
    super.initState();
    _startReferencedLoadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MediaItemThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItem.id != widget.mediaItem.id ||
        oldWidget.mediaItem.location != widget.mediaItem.location ||
        oldWidget.gateway != widget.gateway) {
      _generation++;
      _referencedResult = null;
      _referencedLoading = false;
      _privateRetry = 0;
      _startReferencedLoadIfNeeded();
    }
  }

  void _startReferencedLoadIfNeeded({bool notify = false}) {
    final location = widget.mediaItem.location;
    if (location is! MediaStoreReferenceLocation) return;
    final generation = ++_generation;
    void update() {
      _referencedResult = null;
      _referencedLoading = true;
    }

    if (notify) {
      setState(update);
    } else {
      update();
    }
    _completeReferencedLoad(location, generation);
  }

  Future<void> _completeReferencedLoad(
    MediaStoreReferenceLocation location,
    int generation,
  ) async {
    ReferencedMediaThumbnail result;
    try {
      result = await widget.gateway.loadThumbnail(location);
    } catch (_) {
      result = const ReferencedMediaThumbnail(
        availability: ReferencedMediaAvailability.temporaryFailure,
      );
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _referencedLoading = false;
      _referencedResult = result;
    });
  }

  void _retryPrivate(String path) {
    FileImage(File(path)).evict();
    setState(() => _privateRetry++);
  }

  @override
  void dispose() {
    _generation++;
    _referencedResult = null;
    _referencedLoading = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (widget.mediaItem.location) {
    PrivateFileLocation(:final privatePath) => _buildPrivate(privatePath),
    MediaStoreReferenceLocation() => _buildReferenced(),
  };

  Widget _buildPrivate(String privatePath) {
    return KeyedSubtree(
      key: ValueKey(
        'private-thumbnail-load-${widget.mediaItem.id}-$_privateRetry',
      ),
      child: Image.file(
        File(privatePath),
        key: ValueKey('private-thumbnail-${widget.mediaItem.id}'),
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        gaplessPlayback: false,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return const _ThumbnailLoadingPlaceholder();
        },
        errorBuilder: (_, _, _) => _ThumbnailFailurePlaceholder(
          showMessage: widget.showMessage,
          availability: ReferencedMediaAvailability.temporaryFailure,
          onRetry: () => _retryPrivate(privatePath),
        ),
      ),
    );
  }

  Widget _buildReferenced() {
    if (_referencedLoading) {
      return const _ThumbnailLoadingPlaceholder();
    }
    final result = _referencedResult;
    if (result?.availability == ReferencedMediaAvailability.available &&
        result?.bytes != null) {
      return Image.memory(
        result!.bytes!,
        key: ValueKey('referenced-thumbnail-image-${widget.mediaItem.id}'),
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        gaplessPlayback: false,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => _ThumbnailFailurePlaceholder(
          showMessage: widget.showMessage,
          availability: ReferencedMediaAvailability.temporaryFailure,
          onRetry: () => _startReferencedLoadIfNeeded(notify: true),
        ),
      );
    }
    return _ThumbnailFailurePlaceholder(
      showMessage: widget.showMessage,
      availability:
          result?.availability ?? ReferencedMediaAvailability.temporaryFailure,
      onRetry: () => _startReferencedLoadIfNeeded(notify: true),
    );
  }
}

class _ThumbnailLoadingPlaceholder extends StatelessWidget {
  const _ThumbnailLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      key: const Key('media-thumbnail-loading'),
      color: colors.surfaceContainerLow,
      child: Center(
        child: Semantics(
          label: 'Carregando miniatura',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_outlined,
                size: 30,
                color: colors.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 7),
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailFailurePlaceholder extends StatelessWidget {
  const _ThumbnailFailurePlaceholder({
    required this.showMessage,
    required this.availability,
    required this.onRetry,
  });

  final bool showMessage;
  final ReferencedMediaAvailability availability;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final message = switch (availability) {
      ReferencedMediaAvailability.permissionDenied =>
        'Revise o acesso às imagens.',
      ReferencedMediaAvailability.unavailable => 'Imagem indisponível.',
      _ => 'Não foi possível carregar',
    };
    return ColoredBox(
      key: Key('media-thumbnail-${availability.name}'),
      color: colors.surfaceContainerLow,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
              if (showMessage) ...[
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (availability ==
                    ReferencedMediaAvailability.temporaryFailure) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

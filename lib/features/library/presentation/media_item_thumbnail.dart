import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/media_store/media_store_content.dart';
import '../domain/media_item.dart';

class MediaItemThumbnail extends StatelessWidget {
  const MediaItemThumbnail({
    required this.mediaItem,
    this.fit = BoxFit.cover,
    this.gateway = const MethodChannelMediaStoreContentGateway(),
    this.showMessage = false,
    super.key,
  });

  final MediaItem mediaItem;
  final BoxFit fit;
  final MediaStoreContentGateway gateway;
  final bool showMessage;

  @override
  Widget build(BuildContext context) => switch (mediaItem.location) {
    PrivateFileLocation(:final privatePath) => Image.file(
      File(privatePath),
      key: ValueKey('private-thumbnail-${mediaItem.id}'),
      fit: fit,
      errorBuilder: (_, _, _) => _ThumbnailPlaceholder(
        message: showMessage ? 'Imagem indisponível.' : null,
      ),
    ),
    MediaStoreReferenceLocation() => _ReferencedThumbnail(
      key: ValueKey('referenced-thumbnail-${mediaItem.id}'),
      location: mediaItem.location as MediaStoreReferenceLocation,
      fit: fit,
      gateway: gateway,
      showMessage: showMessage,
    ),
  };
}

class _ReferencedThumbnail extends StatefulWidget {
  const _ReferencedThumbnail({
    required this.location,
    required this.fit,
    required this.gateway,
    required this.showMessage,
    super.key,
  });

  final MediaStoreReferenceLocation location;
  final BoxFit fit;
  final MediaStoreContentGateway gateway;
  final bool showMessage;

  @override
  State<_ReferencedThumbnail> createState() => _ReferencedThumbnailState();
}

class _ReferencedThumbnailState extends State<_ReferencedThumbnail> {
  late Future<ReferencedMediaThumbnail> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.gateway.loadThumbnail(widget.location);
  }

  @override
  void didUpdateWidget(covariant _ReferencedThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location ||
        oldWidget.gateway != widget.gateway) {
      _future = widget.gateway.loadThumbnail(widget.location);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReferencedMediaThumbnail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Color(0xFFF1F0F5),
            child: Center(
              child: SizedBox.square(
                key: Key('referenced-thumbnail-loading'),
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final result = snapshot.data;
        if (result?.availability == ReferencedMediaAvailability.available &&
            result?.bytes != null) {
          return Image.memory(
            result!.bytes!,
            key: const Key('referenced-thumbnail-image'),
            fit: widget.fit,
            cacheWidth: 512,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, _, _) => const _ThumbnailPlaceholder(),
          );
        }
        final message = widget.showMessage
            ? switch (result?.availability) {
                ReferencedMediaAvailability.unavailable =>
                  'Esta imagem não está mais disponível no dispositivo.',
                ReferencedMediaAvailability.permissionDenied =>
                  'O MemoShot não tem acesso a esta imagem.',
                _ => 'Não foi possível carregar esta imagem agora.',
              }
            : null;
        return _ThumbnailPlaceholder(message: message);
      },
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
              if (message case final value?) ...[
                const SizedBox(height: 8),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

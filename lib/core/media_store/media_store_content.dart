import 'package:flutter/services.dart';

import '../../features/library/domain/media_item.dart';

const mediaStoreContentChannelName =
    'br.com.jeffersont.memoshot/media_store_content';
const maximumMediaStoreThumbnailPayloadBytes = 384 * 1024;

enum ReferencedMediaAvailability {
  available,
  unavailable,
  permissionDenied,
  temporaryFailure,
}

class ReferencedMediaThumbnail {
  const ReferencedMediaThumbnail({required this.availability, this.bytes});

  final ReferencedMediaAvailability availability;
  final Uint8List? bytes;
}

abstract interface class MediaStoreContentGateway {
  Future<ReferencedMediaAvailability> checkAvailability(
    MediaStoreReferenceLocation location,
  );

  Future<ReferencedMediaThumbnail> loadThumbnail(
    MediaStoreReferenceLocation location,
  );
}

class MethodChannelMediaStoreContentGateway
    implements MediaStoreContentGateway {
  const MethodChannelMediaStoreContentGateway([
    this._channel = const MethodChannel(mediaStoreContentChannelName),
  ]);

  final MethodChannel _channel;

  @override
  Future<ReferencedMediaAvailability> checkAvailability(
    MediaStoreReferenceLocation location,
  ) async {
    final value = await _invoke('checkAvailability', location);
    return _availability(value['status']);
  }

  @override
  Future<ReferencedMediaThumbnail> loadThumbnail(
    MediaStoreReferenceLocation location,
  ) async {
    final value = await _invoke('loadThumbnail', location);
    final availability = _availability(value['status']);
    final bytes = value['bytes'] as Uint8List?;
    if (bytes != null &&
        bytes.length > maximumMediaStoreThumbnailPayloadBytes) {
      return const ReferencedMediaThumbnail(
        availability: ReferencedMediaAvailability.temporaryFailure,
      );
    }
    return ReferencedMediaThumbnail(
      availability: availability,
      bytes: availability == ReferencedMediaAvailability.available
          ? bytes
          : null,
    );
  }

  Future<Map<Object?, Object?>> _invoke(
    String method,
    MediaStoreReferenceLocation location,
  ) async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(method, {
      'volumeName': location.volumeName,
      'mediaStoreId': location.mediaStoreId,
      'contentUri': location.contentUri,
    });
    return value ?? const {};
  }

  ReferencedMediaAvailability _availability(Object? value) => switch (value) {
    'available' => ReferencedMediaAvailability.available,
    'unavailable' => ReferencedMediaAvailability.unavailable,
    'permissionDenied' => ReferencedMediaAvailability.permissionDenied,
    _ => ReferencedMediaAvailability.temporaryFailure,
  };
}

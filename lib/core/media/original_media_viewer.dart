import 'package:flutter/services.dart';

import '../../features/library/domain/media_item.dart';

const originalMediaViewerChannelName =
    'br.com.jeffersont.memoshot/original_media_viewer';

enum OriginalMediaOpenResult {
  opened,
  unavailable,
  permissionDenied,
  noCompatibleApp,
  invalidReference,
  invalidPrivateFile,
  temporaryFailure,
}

abstract interface class OriginalMediaViewer {
  Future<OriginalMediaOpenResult> open(MediaItem mediaItem);
}

class MethodChannelOriginalMediaViewer implements OriginalMediaViewer {
  const MethodChannelOriginalMediaViewer([
    this._channel = const MethodChannel(originalMediaViewerChannelName),
  ]);

  final MethodChannel _channel;

  @override
  Future<OriginalMediaOpenResult> open(MediaItem mediaItem) async {
    final arguments = switch (mediaItem.location) {
      PrivateFileLocation(:final internalName) => <String, Object?>{
        'storageKind': 'privateFile',
        'internalName': internalName,
        'mimeType': mediaItem.mimeType,
      },
      MediaStoreReferenceLocation(:final volumeName, :final mediaStoreId) =>
        <String, Object?>{
          'storageKind': 'mediaStoreReference',
          'volumeName': volumeName,
          'mediaStoreId': mediaStoreId,
          'mimeType': mediaItem.mimeType,
        },
    };
    try {
      final value = await _channel.invokeMethod<String>(
        'openOriginalMedia',
        arguments,
      );
      return OriginalMediaOpenResult.values.firstWhere(
        (result) => result.name == value,
        orElse: () => OriginalMediaOpenResult.temporaryFailure,
      );
    } on PlatformException catch (error) {
      return OriginalMediaOpenResult.values.firstWhere(
        (result) => result.name == error.code,
        orElse: () => OriginalMediaOpenResult.temporaryFailure,
      );
    } catch (_) {
      return OriginalMediaOpenResult.temporaryFailure;
    }
  }
}

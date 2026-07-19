import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../features/library/domain/media_item.dart';

const mediaStoreOcrInputChannelName =
    'br.com.jeffersont.memoshot/media_store_ocr_input';

abstract final class MediaOcrInputFailureCode {
  static const referencedSourceUnavailable = 'referencedSourceUnavailable';
  static const referencedSourcePermissionDenied =
      'referencedSourcePermissionDenied';
  static const referencedSourceTooLarge = 'referencedSourceTooLarge';
  static const referencedSourceInvalid = 'referencedSourceInvalid';
  static const referencedSourceTemporaryFailure =
      'referencedSourceTemporaryFailure';
  static const temporaryFileFailure = 'temporaryFileFailure';
  static const unsupportedReferencedMimeType = 'unsupportedReferencedMimeType';
  static const privateSourceUnavailable = 'file_unavailable';
}

class MediaOcrInputException implements Exception {
  const MediaOcrInputException(this.code);

  final String code;

  @override
  String toString() => 'MediaOcrInputException($code)';
}

class ReferencedOcrInput {
  const ReferencedOcrInput({required this.localPath, required this.token});

  final String localPath;
  final String token;
}

abstract interface class MediaStoreOcrInputBridge {
  Future<ReferencedOcrInput> prepare(MediaStoreReferenceLocation location);

  Future<void> release(String token);
}

class MethodChannelMediaStoreOcrInputBridge
    implements MediaStoreOcrInputBridge {
  const MethodChannelMediaStoreOcrInputBridge([
    this._channel = const MethodChannel(mediaStoreOcrInputChannelName),
  ]);

  final MethodChannel _channel;

  @override
  Future<ReferencedOcrInput> prepare(
    MediaStoreReferenceLocation location,
  ) async {
    try {
      final value = await _channel.invokeMapMethod<Object?, Object?>(
        'prepare',
        <String, Object>{
          'volumeName': location.volumeName,
          'mediaStoreId': location.mediaStoreId,
        },
      );
      final localPath = value?['localPath'];
      final token = value?['token'];
      if (localPath is! String ||
          localPath.isEmpty ||
          token is! String ||
          token.isEmpty) {
        throw const MediaOcrInputException(
          MediaOcrInputFailureCode.referencedSourceTemporaryFailure,
        );
      }
      return ReferencedOcrInput(localPath: localPath, token: token);
    } on PlatformException catch (error) {
      throw MediaOcrInputException(_controlledCode(error.code));
    }
  }

  @override
  Future<void> release(String token) =>
      _channel.invokeMethod<void>('release', <String, Object>{'token': token});

  String _controlledCode(String code) => switch (code) {
    MediaOcrInputFailureCode.referencedSourceUnavailable => code,
    MediaOcrInputFailureCode.referencedSourcePermissionDenied => code,
    MediaOcrInputFailureCode.referencedSourceTooLarge => code,
    MediaOcrInputFailureCode.referencedSourceInvalid => code,
    MediaOcrInputFailureCode.temporaryFileFailure => code,
    MediaOcrInputFailureCode.unsupportedReferencedMimeType => code,
    _ => MediaOcrInputFailureCode.referencedSourceTemporaryFailure,
  };
}

abstract interface class MediaOcrInputResolver {
  Future<OcrInputLease> resolve(MediaItem mediaItem);

  Future<void> close();
}

class OcrInputLease {
  OcrInputLease._(this._localPath, this.isTemporary, this._onRelease);

  final String _localPath;
  final bool isTemporary;
  final Future<void> Function() _onRelease;
  bool _released = false;

  String get localPath {
    if (_released) throw StateError('Lease de OCR já liberado.');
    return _localPath;
  }

  bool get isReleased => _released;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _onRelease();
  }

  Future<void> close() => release();
}

class LocalMediaOcrInputResolver implements MediaOcrInputResolver {
  LocalMediaOcrInputResolver(this._bridge);

  final MediaStoreOcrInputBridge _bridge;
  final Set<OcrInputLease> _activeLeases = <OcrInputLease>{};
  bool _closed = false;

  @override
  Future<OcrInputLease> resolve(MediaItem mediaItem) async {
    if (_closed) throw StateError('Resolver de OCR encerrado.');
    switch (mediaItem.location) {
      case PrivateFileLocation(:final privatePath):
        if (!await File(privatePath).exists()) {
          throw const MediaOcrInputException(
            MediaOcrInputFailureCode.privateSourceUnavailable,
          );
        }
        if (_closed) throw StateError('Resolver de OCR encerrado.');
        return _track(localPath: privatePath, isTemporary: false);
      case final MediaStoreReferenceLocation location:
        final prepared = await _bridge.prepare(location);
        if (_closed) {
          await _releaseIgnoringErrors(prepared.token);
          throw StateError('Resolver de OCR encerrado.');
        }
        return _track(
          localPath: prepared.localPath,
          isTemporary: true,
          token: prepared.token,
        );
    }
  }

  OcrInputLease _track({
    required String localPath,
    required bool isTemporary,
    String? token,
  }) {
    late final OcrInputLease lease;
    lease = OcrInputLease._(localPath, isTemporary, () async {
      _activeLeases.remove(lease);
      if (token != null) await _bridge.release(token);
    });
    _activeLeases.add(lease);
    return lease;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final leases = _activeLeases.toList(growable: false);
    for (final lease in leases) {
      try {
        await lease.release();
      } catch (_) {
        // O fechamento continua liberando os demais temporários.
      }
    }
  }

  Future<void> _releaseIgnoringErrors(String token) async {
    try {
      await _bridge.release(token);
    } catch (_) {
      // O resultado tardio nunca deve reabrir o resolver encerrado.
    }
  }
}

MediaOcrInputResolver createMediaOcrInputResolver() =>
    LocalMediaOcrInputResolver(const MethodChannelMediaStoreOcrInputBridge());

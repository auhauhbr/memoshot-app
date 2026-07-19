import 'package:flutter/services.dart';

import '../../features/existing_screenshots/domain/existing_screenshot_candidate.dart';
import '../../features/existing_screenshots/domain/existing_screenshot_scan.dart';

const existingScreenshotInventoryChannelName =
    'br.com.jeffersont.memoshot/existing_screenshot_inventory';

abstract interface class ExistingScreenshotScanner {
  Future<String> beginScan();

  Future<ExistingScreenshotScanPage> scanPage({
    required String sessionId,
    ExistingScreenshotScanCursor? cursor,
  });

  Future<void> cancelScan();
}

class MethodChannelExistingScreenshotScanner
    implements ExistingScreenshotScanner {
  const MethodChannelExistingScreenshotScanner([
    this._channel = const MethodChannel(existingScreenshotInventoryChannelName),
  ]);

  final MethodChannel _channel;

  @override
  Future<String> beginScan() async {
    final value = await _channel.invokeMapMethod<String, Object?>('beginScan');
    final sessionId = value?['sessionId'] as String?;
    if (sessionId == null || sessionId.isEmpty) {
      throw StateError('scan_session_unavailable');
    }
    return sessionId;
  }

  @override
  Future<ExistingScreenshotScanPage> scanPage({
    required String sessionId,
    ExistingScreenshotScanCursor? cursor,
  }) async {
    final value = await _channel.invokeMapMethod<String, Object?>('scanPage', {
      'sessionId': sessionId,
      'cursor': cursor == null
          ? null
          : <String, Object>{
              'volumeName': cursor.volumeName,
              'mediaStoreId': cursor.mediaStoreId,
            },
    });
    final rawItems = value?['items'] as List<Object?>? ?? const [];
    final now = DateTime.now();
    final rawCursor = value?['nextCursor'];
    return ExistingScreenshotScanPage(
      examinedCount: value?['examinedCount'] as int? ?? 0,
      recognizedCount: value?['recognizedCount'] as int? ?? rawItems.length,
      hasNext: value?['hasNext'] as bool? ?? false,
      nextCursor: rawCursor is Map
          ? ExistingScreenshotScanCursor(
              volumeName: rawCursor['volumeName']! as String,
              mediaStoreId: rawCursor['mediaStoreId']! as int,
            )
          : null,
      items: rawItems
          .map((raw) {
            final item = Map<Object?, Object?>.from(raw! as Map);
            return ExistingScreenshotCandidate(
              sourceKey: item['sourceKey']! as String,
              mediaStoreId: item['mediaStoreId']! as int,
              volumeName: item['volumeName']! as String,
              contentUri: item['contentUri']! as String,
              mimeType: item['mimeType'] as String?,
              capturedAt: _date(item['capturedAt']),
              dateModified: _date(item['dateModified']),
              sizeBytes: item['sizeBytes'] as int?,
              width: item['width'] as int?,
              height: item['height'] as int?,
              discoveredAt: now,
              lastSeenAt: now,
              availability: ExistingScreenshotAvailability.available,
            );
          })
          .toList(growable: false),
    );
  }

  @override
  Future<void> cancelScan() => _channel.invokeMethod<void>('cancelScan');

  DateTime? _date(Object? value) {
    final milliseconds = value as int?;
    return milliseconds == null || milliseconds <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}

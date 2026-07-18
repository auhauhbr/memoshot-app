import 'package:flutter/services.dart';

import 'automatic_screenshot_source.dart';

class MethodChannelAutomaticScreenshotSource
    implements AutomaticScreenshotSource {
  const MethodChannelAutomaticScreenshotSource();

  static const _methods = MethodChannel(
    'br.com.jeffersont.contexto/automatic_screenshots/methods',
  );
  static const _events = EventChannel(
    'br.com.jeffersont.contexto/automatic_screenshots/events',
  );

  @override
  Stream<void> get changes => _events.receiveBroadcastStream().map((_) {});

  @override
  Future<MediaPermissionStatus> permissionStatus() async =>
      _permissionFrom(await _methods.invokeMethod<String>('permissionStatus'));

  @override
  Future<MediaPermissionStatus> requestPermission() async =>
      _permissionFrom(await _methods.invokeMethod<String>('requestPermission'));

  @override
  Future<void> openAppSettings() =>
      _methods.invokeMethod<void>('openAppSettings');

  @override
  Future<int> currentMaxMediaId() async =>
      await _methods.invokeMethod<int>('currentMaxMediaId') ?? 0;

  @override
  Future<AutomaticScreenshotBatch> scanAfter(int lastMediaId) async {
    final value = await _methods.invokeMapMethod<String, Object?>(
      'scanAfter',
      <String, Object?>{'lastMediaId': lastMediaId},
    );
    final rawItems = value?['items'] as List<Object?>? ?? const [];
    return AutomaticScreenshotBatch(
      lastExaminedMediaId: value?['lastExaminedMediaId'] as int? ?? lastMediaId,
      rejectedCount: value?['rejectedCount'] as int? ?? 0,
      items: rawItems
          .map((raw) {
            final item = Map<Object?, Object?>.from(raw! as Map);
            return AutomaticScreenshotCandidate(
              mediaId: item['mediaId']! as int,
              temporaryPath: item['temporaryPath']! as String,
              mimeType: item['mimeType'] as String?,
              capturedAt: _dateFromMilliseconds(item['capturedAt'] as int?),
            );
          })
          .toList(growable: false),
    );
  }

  @override
  Future<void> startObserving() =>
      _methods.invokeMethod<void>('startObserving');

  @override
  Future<void> stopObserving() => _methods.invokeMethod<void>('stopObserving');

  @override
  Future<void> deleteTemporary(String path) => _methods.invokeMethod<void>(
    'deleteTemporary',
    <String, Object?>{'path': path},
  );

  @override
  Future<BackgroundMonitorStatus> configureBackgroundMonitoring({
    required bool enabled,
    required int lastMediaId,
    bool resetBaseline = false,
  }) async {
    final value = await _methods.invokeMapMethod<String, Object?>(
      'configureBackgroundMonitoring',
      <String, Object?>{
        'enabled': enabled,
        'lastMediaId': lastMediaId,
        'resetBaseline': resetBaseline,
      },
    );
    return BackgroundMonitorStatus(
      available: value?['available'] as bool? ?? false,
      enabled: value?['enabled'] as bool? ?? false,
      lastMediaId: value?['lastMediaId'] as int? ?? lastMediaId,
    );
  }

  @override
  Future<List<BackgroundScreenshotEntry>> loadBackgroundInbox() async {
    final values =
        await _methods.invokeListMethod<Object?>('listBackgroundInbox') ??
        const [];
    return values
        .map((raw) {
          final value = Map<Object?, Object?>.from(raw! as Map);
          return BackgroundScreenshotEntry(
            entryId: value['entryId']! as String,
            mediaId: value['mediaId']! as int,
            privatePath: value['privatePath']! as String,
            mimeType: value['mimeType'] as String?,
            capturedAt: _dateFromMilliseconds(value['capturedAt'] as int?),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<int> backgroundInboxPendingCount() async =>
      await _methods.invokeMethod<int>('backgroundInboxPendingCount') ?? 0;

  @override
  Future<void> acknowledgeBackgroundEntry(String entryId) =>
      _methods.invokeMethod<void>(
        'acknowledgeBackgroundInbox',
        <String, Object?>{'entryId': entryId},
      );

  @override
  Future<void> rejectBackgroundEntry(String entryId) =>
      _methods.invokeMethod<void>('rejectBackgroundInbox', <String, Object?>{
        'entryId': entryId,
      });

  MediaPermissionStatus _permissionFrom(String? value) {
    return MediaPermissionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => MediaPermissionStatus.unsupported,
    );
  }

  DateTime? _dateFromMilliseconds(int? value) {
    if (value == null || value <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
}

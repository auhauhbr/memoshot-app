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

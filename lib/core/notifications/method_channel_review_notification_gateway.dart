import 'package:flutter/services.dart';

import '../../features/review_notifications/application/review_notification_coordinator.dart';
import '../../features/review_notifications/domain/review_notification.dart';

const reviewNotificationChannelName =
    'br.com.jeffersont.memoshot/review_notifications';

class MethodChannelReviewNotificationGateway
    implements ReviewNotificationGateway {
  const MethodChannelReviewNotificationGateway([
    this._channel = const MethodChannel(reviewNotificationChannelName),
  ]);

  final MethodChannel _channel;

  @override
  Future<ReviewNotificationState> loadState() async {
    try {
      final value = await _channel.invokeMapMethod<String, Object?>('getState');
      return _decodeState(value);
    } on MissingPluginException {
      return const ReviewNotificationState.disabled();
    }
  }

  @override
  Future<ReviewNotificationState> requestPermissionAndEnable() async {
    final value = await _channel.invokeMapMethod<String, Object?>(
      'requestPermissionAndEnable',
    );
    return _decodeState(value);
  }

  @override
  Future<void> disable() => _channel.invokeMethod<void>('disable');

  @override
  Future<void> dismissPrompt() => _channel.invokeMethod<void>('dismissPrompt');

  @override
  Future<void> openAndroidSettings() =>
      _channel.invokeMethod<void>('openAndroidSettings');

  @override
  Future<void> synchronize(ReviewNotificationSnapshot snapshot) {
    return _channel.invokeMethod<void>('synchronize', <String, Object>{
      'pendingCount': snapshot.pendingCount,
      'marker': snapshot.marker ?? '',
    });
  }

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');

  ReviewNotificationState _decodeState(Map<String, Object?>? value) {
    final permissionName = value?['permission'] as String? ?? 'unsupported';
    final permission = ReviewNotificationPermission.values
        .where((item) => item.name == permissionName)
        .firstOrNull;
    return ReviewNotificationState(
      enabled: value?['enabled'] == true,
      promptHandled: value?['promptHandled'] == true,
      permission: permission ?? ReviewNotificationPermission.unsupported,
    );
  }
}

import 'package:flutter/services.dart';

abstract interface class OnboardingRepository {
  bool? get cachedCompletion;

  Future<bool> isCompleted();

  Future<void> complete();
}

class MethodChannelOnboardingRepository implements OnboardingRepository {
  const MethodChannelOnboardingRepository();

  static const _channel = MethodChannel(
    'br.com.jeffersont.memoshot/preferences',
  );

  @override
  bool? get cachedCompletion => null;

  @override
  Future<bool> isCompleted() async =>
      await _channel.invokeMethod<bool>('isOnboardingCompleted') ?? false;

  @override
  Future<void> complete() => _channel.invokeMethod<void>('completeOnboarding');
}

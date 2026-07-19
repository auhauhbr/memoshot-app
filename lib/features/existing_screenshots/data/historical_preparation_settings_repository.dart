import 'package:flutter/services.dart';

import '../domain/historical_media_import_job.dart';

abstract interface class HistoricalPreparationSettingsRepository {
  Future<HistoricalPreparationState> load();

  Future<void> start();

  Future<void> pause();

  Future<void> resume();

  Future<void> complete();
}

abstract interface class HistoricalPreparationScheduler {
  Future<void> schedule();
}

class MethodChannelHistoricalPreparationSettingsRepository
    implements
        HistoricalPreparationSettingsRepository,
        HistoricalPreparationScheduler {
  const MethodChannelHistoricalPreparationSettingsRepository();

  static const _channel = MethodChannel(
    'br.com.jeffersont.memoshot/preferences',
  );

  @override
  Future<HistoricalPreparationState> load() async {
    final value = await _channel.invokeMethod<String>(
      'historicalPreparationState',
    );
    return HistoricalPreparationState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => HistoricalPreparationState.notStarted,
    );
  }

  @override
  Future<void> start() => _setState(HistoricalPreparationState.active);

  @override
  Future<void> pause() => _setState(HistoricalPreparationState.paused);

  @override
  Future<void> resume() => _setState(HistoricalPreparationState.active);

  @override
  Future<void> complete() => _setState(HistoricalPreparationState.completed);

  Future<void> _setState(HistoricalPreparationState state) =>
      _channel.invokeMethod<void>('setHistoricalPreparationState', {
        'state': state.name,
      });

  @override
  Future<void> schedule() =>
      _channel.invokeMethod<void>('scheduleHistoricalPreparation');
}

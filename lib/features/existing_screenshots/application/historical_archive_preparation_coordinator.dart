import 'dart:async';

import '../data/historical_media_import_job_store.dart';
import '../data/historical_preparation_settings_repository.dart';
import '../domain/historical_media_import_job.dart';
import 'historical_media_import_processor.dart';

class HistoricalArchivePreparationCoordinator {
  const HistoricalArchivePreparationCoordinator({
    required HistoricalMediaImportJobStore jobStore,
    required HistoricalPreparationSettingsRepository settingsRepository,
    required HistoricalPreparationScheduler scheduler,
    HistoricalMediaImportQueue? queue,
  }) : this._(jobStore, settingsRepository, scheduler, queue);

  const HistoricalArchivePreparationCoordinator._(
    this._jobStore,
    this._settingsRepository,
    this._scheduler,
    this._queue,
  );

  final HistoricalMediaImportJobStore _jobStore;
  final HistoricalPreparationSettingsRepository _settingsRepository;
  final HistoricalPreparationScheduler _scheduler;
  final HistoricalMediaImportQueue? _queue;

  Stream<void> get changes => _queue?.changes ?? const Stream.empty();

  Future<HistoricalPreparationProgress> loadProgress() async {
    final state = await _settingsRepository.load();
    return _jobStore.loadProgress(state: state);
  }

  Future<void> start() async {
    await _settingsRepository.start();
    await _jobStore.enqueueAvailableBatch(now: DateTime.now());
    _queue?.signal();
    await _scheduler.schedule();
  }

  Future<void> pause() => _settingsRepository.pause();

  Future<void> resume() async {
    await _settingsRepository.resume();
    await _jobStore.recoverExpired(
      expiredBefore: DateTime.now().subtract(
        historicalMediaProcessingExpiration,
      ),
      now: DateTime.now(),
    );
    _queue?.signal();
    await _scheduler.schedule();
  }

  Future<void> onAppResumed() async {
    if (await _settingsRepository.load() != HistoricalPreparationState.active) {
      return;
    }
    final now = DateTime.now();
    await _jobStore.recoverExpired(
      expiredBefore: now.subtract(historicalMediaProcessingExpiration),
      now: now,
    );
    _queue?.signal();
    await _scheduler.schedule();
  }

  Future<bool> canClearInventory() async => !await _jobStore.hasJobs();
}

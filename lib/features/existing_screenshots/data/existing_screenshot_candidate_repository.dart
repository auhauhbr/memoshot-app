import '../domain/existing_screenshot_candidate.dart';
import 'existing_screenshot_candidate_store.dart';

abstract interface class ExistingScreenshotCandidateRepository {
  Future<void> upsertBatch(List<ExistingScreenshotCandidate> candidates);

  Future<int> countAvailable();

  Future<int> countUnavailable();

  Future<ExistingScreenshotInventorySummary> loadSummary();

  Future<void> markUnavailableNotSeenInCompletedScan(DateTime scanStartedAt);

  Future<void> recordCompletedScan({
    required DateTime completedAt,
    required bool partialAccess,
  });

  Future<void> completeScan({
    required DateTime scanStartedAt,
    required DateTime completedAt,
    required bool partialAccess,
  });

  Future<void> clearInventory();

  Future<List<ExistingScreenshotCandidate>> loadCandidatesPage({
    int limit = 200,
    String? afterSourceKey,
  });

  Future<ExistingScreenshotCandidate?> findBySourceKey(String sourceKey);
}

class LocalExistingScreenshotCandidateRepository
    implements ExistingScreenshotCandidateRepository {
  const LocalExistingScreenshotCandidateRepository(this._store);

  final ExistingScreenshotCandidateStore _store;

  @override
  Future<void> upsertBatch(List<ExistingScreenshotCandidate> candidates) =>
      _store.upsertBatch(candidates);

  @override
  Future<int> countAvailable() => _store.countAvailable();

  @override
  Future<int> countUnavailable() => _store.countUnavailable();

  @override
  Future<ExistingScreenshotInventorySummary> loadSummary() =>
      _store.loadSummary();

  @override
  Future<void> markUnavailableNotSeenInCompletedScan(DateTime scanStartedAt) =>
      _store.markUnavailableNotSeenInCompletedScan(scanStartedAt);

  @override
  Future<void> recordCompletedScan({
    required DateTime completedAt,
    required bool partialAccess,
  }) => _store.recordCompletedScan(
    completedAt: completedAt,
    partialAccess: partialAccess,
  );

  @override
  Future<void> completeScan({
    required DateTime scanStartedAt,
    required DateTime completedAt,
    required bool partialAccess,
  }) => _store.completeScan(
    scanStartedAt: scanStartedAt,
    completedAt: completedAt,
    partialAccess: partialAccess,
  );

  @override
  Future<void> clearInventory() => _store.clearInventory();

  @override
  Future<List<ExistingScreenshotCandidate>> loadCandidatesPage({
    int limit = 200,
    String? afterSourceKey,
  }) => _store.loadCandidatesPage(limit: limit, afterSourceKey: afterSourceKey);

  @override
  Future<ExistingScreenshotCandidate?> findBySourceKey(String sourceKey) =>
      _store.findBySourceKey(sourceKey);
}

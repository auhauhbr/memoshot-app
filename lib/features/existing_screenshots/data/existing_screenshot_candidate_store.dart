import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../domain/existing_screenshot_candidate.dart' as domain;

abstract interface class ExistingScreenshotCandidateStore {
  Future<void> upsertBatch(List<domain.ExistingScreenshotCandidate> candidates);

  Future<int> countAvailable();

  Future<int> countUnavailable();

  Future<domain.ExistingScreenshotInventorySummary> loadSummary();

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

  Future<List<domain.ExistingScreenshotCandidate>> loadCandidatesPage({
    required int limit,
    String? afterSourceKey,
  });

  Future<domain.ExistingScreenshotCandidate?> findBySourceKey(String sourceKey);
}

class DriftExistingScreenshotCandidateStore
    implements ExistingScreenshotCandidateStore {
  DriftExistingScreenshotCandidateStore(this._database);

  final ContextoDatabase _database;

  @override
  Future<void> upsertBatch(
    List<domain.ExistingScreenshotCandidate> candidates,
  ) async {
    if (candidates.isEmpty) return;
    await _database.transaction(() async {
      for (final candidate in candidates) {
        await _database.customStatement(
          '''
          INSERT INTO existing_screenshot_candidates (
            source_key, media_store_id, volume_name, content_uri, mime_type,
            captured_at, date_modified, size_bytes, width, height,
            discovered_at, last_seen_at, availability_state
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'available')
          ON CONFLICT(source_key) DO UPDATE SET
            media_store_id = excluded.media_store_id,
            volume_name = excluded.volume_name,
            content_uri = excluded.content_uri,
            mime_type = excluded.mime_type,
            captured_at = excluded.captured_at,
            date_modified = excluded.date_modified,
            size_bytes = excluded.size_bytes,
            width = excluded.width,
            height = excluded.height,
            last_seen_at = excluded.last_seen_at,
            availability_state = 'available'
          ''',
          [
            candidate.sourceKey,
            candidate.mediaStoreId,
            candidate.volumeName,
            candidate.contentUri,
            candidate.mimeType,
            _seconds(candidate.capturedAt),
            _seconds(candidate.dateModified),
            candidate.sizeBytes,
            candidate.width,
            candidate.height,
            _seconds(candidate.discoveredAt),
            _seconds(candidate.lastSeenAt),
          ],
        );
      }
    });
  }

  @override
  Future<int> countAvailable() =>
      _count(domain.ExistingScreenshotAvailability.available);

  @override
  Future<int> countUnavailable() =>
      _count(domain.ExistingScreenshotAvailability.unavailable);

  Future<int> _count(domain.ExistingScreenshotAvailability availability) async {
    final table = _database.existingScreenshotCandidates;
    final count = table.sourceKey.count();
    final query = _database.selectOnly(table)
      ..addColumns([count])
      ..where(table.availabilityState.equals(availability.name));
    return (await query.getSingle()).read(count) ?? 0;
  }

  @override
  Future<domain.ExistingScreenshotInventorySummary> loadSummary() async {
    final state = await (_database.select(
      _database.existingScreenshotInventoryStates,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
    return domain.ExistingScreenshotInventorySummary(
      availableCount: await countAvailable(),
      unavailableCount: await countUnavailable(),
      lastCompletedScanAt: state?.lastCompletedScanAt,
      lastScanWasPartial: state?.lastScanWasPartial ?? false,
    );
  }

  @override
  Future<void> markUnavailableNotSeenInCompletedScan(
    DateTime scanStartedAt,
  ) async {
    await (_database.update(
      _database.existingScreenshotCandidates,
    )..where((row) => row.lastSeenAt.isSmallerThanValue(scanStartedAt))).write(
      ExistingScreenshotCandidatesCompanion(
        availabilityState: Value(
          domain.ExistingScreenshotAvailability.unavailable.name,
        ),
      ),
    );
  }

  @override
  Future<void> recordCompletedScan({
    required DateTime completedAt,
    required bool partialAccess,
  }) {
    return _recordCompletedScan(
      completedAt: completedAt,
      partialAccess: partialAccess,
    );
  }

  @override
  Future<void> completeScan({
    required DateTime scanStartedAt,
    required DateTime completedAt,
    required bool partialAccess,
  }) {
    return _database.transaction(() async {
      if (!partialAccess) {
        await markUnavailableNotSeenInCompletedScan(scanStartedAt);
      }
      await _recordCompletedScan(
        completedAt: completedAt,
        partialAccess: partialAccess,
      );
    });
  }

  Future<void> _recordCompletedScan({
    required DateTime completedAt,
    required bool partialAccess,
  }) {
    return _database
        .into(_database.existingScreenshotInventoryStates)
        .insertOnConflictUpdate(
          ExistingScreenshotInventoryStatesCompanion.insert(
            id: const Value(1),
            lastCompletedScanAt: Value(completedAt),
            lastScanWasPartial: Value(partialAccess),
          ),
        );
  }

  @override
  Future<void> clearInventory() async {
    await _database.transaction(() async {
      await _database.delete(_database.existingScreenshotCandidates).go();
      await _database.delete(_database.existingScreenshotInventoryStates).go();
    });
  }

  @override
  Future<List<domain.ExistingScreenshotCandidate>> loadCandidatesPage({
    required int limit,
    String? afterSourceKey,
  }) async {
    final query = _database.select(_database.existingScreenshotCandidates)
      ..orderBy([(row) => OrderingTerm.asc(row.sourceKey)])
      ..limit(limit.clamp(1, 250));
    if (afterSourceKey != null) {
      query.where((row) => row.sourceKey.isBiggerThanValue(afterSourceKey));
    }
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<domain.ExistingScreenshotCandidate?> findBySourceKey(
    String sourceKey,
  ) async {
    final row = await (_database.select(
      _database.existingScreenshotCandidates,
    )..where((item) => item.sourceKey.equals(sourceKey))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  domain.ExistingScreenshotCandidate _toDomain(
    ExistingScreenshotCandidate row,
  ) {
    return domain.ExistingScreenshotCandidate(
      sourceKey: row.sourceKey,
      mediaStoreId: row.mediaStoreId,
      volumeName: row.volumeName,
      contentUri: row.contentUri,
      mimeType: row.mimeType,
      capturedAt: row.capturedAt,
      dateModified: row.dateModified,
      sizeBytes: row.sizeBytes,
      width: row.width,
      height: row.height,
      discoveredAt: row.discoveredAt,
      lastSeenAt: row.lastSeenAt,
      availability: domain.ExistingScreenshotAvailability.values.firstWhere(
        (value) => value.name == row.availabilityState,
        orElse: () => domain.ExistingScreenshotAvailability.unavailable,
      ),
    );
  }

  int? _seconds(DateTime? value) =>
      value == null ? null : value.millisecondsSinceEpoch ~/ 1000;
}

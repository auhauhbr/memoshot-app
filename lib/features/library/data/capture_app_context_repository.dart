import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../domain/capture_app_context.dart';

abstract interface class CaptureAppContextRepository {
  Future<CaptureAppContext?> loadFor(int mediaItemId);

  Future<void> save(int mediaItemId, CaptureAppContext context);
}

class DriftCaptureAppContextRepository implements CaptureAppContextRepository {
  DriftCaptureAppContextRepository(this._database);

  final ContextoDatabase _database;

  @override
  Future<CaptureAppContext?> loadFor(int mediaItemId) async {
    final row =
        await (_database.select(_database.mediaCaptureContexts)
              ..where((context) => context.mediaItemId.equals(mediaItemId)))
            .getSingleOrNull();
    if (row == null) return null;
    final confidence = CaptureAppConfidence.fromDatabase(row.confidenceLevel);
    if (confidence == null) return null;
    return CaptureAppContext(
      packageName: row.packageName,
      normalizedAppKey: NormalizedCaptureAppKey.fromDatabase(
        row.normalizedAppKey,
      ),
      eventTimestamp: row.eventTimestamp,
      captureTimestamp: row.captureTimestamp,
      deltaMilliseconds: row.deltaMilliseconds,
      confidenceLevel: confidence,
      createdAt: row.createdAt,
    );
  }

  @override
  Future<void> save(int mediaItemId, CaptureAppContext context) {
    return _database
        .into(_database.mediaCaptureContexts)
        .insertOnConflictUpdate(
          MediaCaptureContextsCompanion.insert(
            mediaItemId: Value(mediaItemId),
            packageName: context.packageName,
            normalizedAppKey: Value(context.normalizedAppKey?.name),
            eventTimestamp: context.eventTimestamp,
            captureTimestamp: context.captureTimestamp,
            deltaMilliseconds: context.deltaMilliseconds,
            confidenceLevel: context.confidenceLevel.databaseValue,
            createdAt: context.createdAt,
          ),
        );
  }
}

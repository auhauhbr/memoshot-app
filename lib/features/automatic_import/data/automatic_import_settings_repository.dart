import 'package:drift/drift.dart';

import '../../../core/database/contexto_database.dart';
import '../domain/automatic_import_settings.dart' as domain;

abstract interface class AutomaticImportSettingsRepository {
  Future<domain.AutomaticImportSettings> load();

  Future<void> enable({required int baselineMediaId});

  Future<void> disable();

  Future<void> updateMarker(int lastMediaId);
}

class DriftAutomaticImportSettingsRepository
    implements AutomaticImportSettingsRepository {
  DriftAutomaticImportSettingsRepository(this._database);

  static const _singletonId = 1;
  final ContextoDatabase _database;

  @override
  Future<domain.AutomaticImportSettings> load() async {
    final row = await (_database.select(
      _database.automaticImportSettings,
    )..where((entry) => entry.id.equals(_singletonId))).getSingleOrNull();
    if (row == null) return domain.AutomaticImportSettings.disabled();
    return domain.AutomaticImportSettings(
      enabled: row.enabled,
      lastMediaId: row.lastMediaId,
      enabledAt: row.enabledAt,
      lastScanAt: row.lastScanAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> enable({required int baselineMediaId}) async {
    final now = DateTime.now();
    await _database
        .into(_database.automaticImportSettings)
        .insertOnConflictUpdate(
          AutomaticImportSettingsCompanion.insert(
            id: const Value(_singletonId),
            enabled: const Value(true),
            lastMediaId: Value(baselineMediaId),
            enabledAt: Value(now),
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> disable() async {
    final current = await load();
    final now = DateTime.now();
    await _database
        .into(_database.automaticImportSettings)
        .insertOnConflictUpdate(
          AutomaticImportSettingsCompanion.insert(
            id: const Value(_singletonId),
            enabled: const Value(false),
            lastMediaId: Value(current.lastMediaId),
            enabledAt: Value(current.enabledAt),
            lastScanAt: Value(current.lastScanAt),
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> updateMarker(int lastMediaId) async {
    final current = await load();
    if (!current.enabled) return;
    final now = DateTime.now();
    await _database
        .into(_database.automaticImportSettings)
        .insertOnConflictUpdate(
          AutomaticImportSettingsCompanion.insert(
            id: const Value(_singletonId),
            enabled: const Value(true),
            lastMediaId: Value(lastMediaId),
            enabledAt: Value(current.enabledAt),
            lastScanAt: Value(now),
            updatedAt: now,
          ),
        );
  }
}

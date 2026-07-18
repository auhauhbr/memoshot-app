import 'package:memoshot/core/database/contexto_database.dart';
import 'package:memoshot/features/automatic_import/data/automatic_import_settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ContextoDatabase database;
  late DriftAutomaticImportSettingsRepository repository;

  setUp(() {
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    repository = DriftAutomaticImportSettingsRepository(database);
  });

  tearDown(() => database.close());

  test('configuração começa desativada', () async {
    final settings = await repository.load();

    expect(settings.enabled, isFalse);
    expect(settings.lastMediaId, isNull);
  });

  test('persiste ativação e linha de base', () async {
    await repository.enable(baselineMediaId: 42);

    final settings = await repository.load();
    expect(settings.enabled, isTrue);
    expect(settings.lastMediaId, 42);
    expect(settings.enabledAt, isNotNull);
  });

  test('persiste marcador e desativação', () async {
    await repository.enable(baselineMediaId: 42);
    await repository.updateMarker(57);
    await repository.disable();

    final settings = await repository.load();
    expect(settings.enabled, isFalse);
    expect(settings.lastMediaId, 57);
    expect(settings.lastScanAt, isNotNull);
  });

  test('configuração persiste ao recriar repositório', () async {
    await repository.enable(baselineMediaId: 91);

    final recreated = DriftAutomaticImportSettingsRepository(database);
    expect((await recreated.load()).lastMediaId, 91);
  });
}

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/database/contexto_database.dart'
    hide ExistingScreenshotCandidate;
import 'package:memoshot/features/existing_screenshots/data/existing_screenshot_candidate_repository.dart';
import 'package:memoshot/features/existing_screenshots/data/existing_screenshot_candidate_store.dart';
import 'package:memoshot/features/existing_screenshots/domain/existing_screenshot_candidate.dart';

void main() {
  late ContextoDatabase database;
  late ExistingScreenshotCandidateRepository repository;

  setUp(() {
    database = ContextoDatabase.forTesting(NativeDatabase.memory());
    repository = LocalExistingScreenshotCandidateRepository(
      DriftExistingScreenshotCandidateStore(database),
    );
  });

  tearDown(() => database.close());

  test('salva candidato e lote com chave única por volume', () async {
    final first = candidate('external_primary', 7);
    final otherVolume = candidate('0123-4567', 7);

    await repository.upsertBatch([first, otherVolume]);
    await repository.upsertBatch([first]);

    expect(await repository.countAvailable(), 2);
    expect(
      (await repository.findBySourceKey(first.sourceKey))?.mediaStoreId,
      7,
    );
    expect(
      (await repository.loadCandidatesPage()).map((item) => item.volumeName),
      containsAll(['external_primary', '0123-4567']),
    );
  });

  test(
    'preserva discoveredAt, atualiza lastSeenAt e restaura disponível',
    () async {
      final discovered = DateTime.utc(2026, 1, 1);
      final first = candidate(
        'external_primary',
        1,
        discoveredAt: discovered,
        lastSeenAt: discovered,
      );
      await repository.upsertBatch([first]);
      await repository.markUnavailableNotSeenInCompletedScan(
        discovered.add(const Duration(days: 1)),
      );
      expect(
        (await repository.findBySourceKey(first.sourceKey))?.availability,
        ExistingScreenshotAvailability.unavailable,
      );

      final seenAgain = first.seenAt(discovered.add(const Duration(days: 2)));
      await repository.upsertBatch([seenAgain]);
      final stored = await repository.findBySourceKey(first.sourceKey);

      expect(stored?.discoveredAt.isAtSameMomentAs(discovered), isTrue);
      expect(stored?.lastSeenAt.isAtSameMomentAs(seenAgain.lastSeenAt), isTrue);
      expect(stored?.availability, ExistingScreenshotAvailability.available);
      expect(await repository.countUnavailable(), 0);
    },
  );

  test('reconcilia somente conclusão com acesso completo', () async {
    final old = DateTime.utc(2026, 1, 1);
    final scanStart = old.add(const Duration(days: 1));
    await repository.upsertBatch([
      candidate('external', 1, lastSeenAt: old),
      candidate('external', 2, lastSeenAt: old),
    ]);
    await repository.upsertBatch([
      candidate('external', 1, lastSeenAt: scanStart),
    ]);

    await repository.completeScan(
      scanStartedAt: scanStart,
      completedAt: scanStart.add(const Duration(minutes: 1)),
      partialAccess: true,
    );
    expect(await repository.countUnavailable(), 0);

    await repository.completeScan(
      scanStartedAt: scanStart,
      completedAt: scanStart.add(const Duration(minutes: 2)),
      partialAccess: false,
    );
    expect(await repository.countAvailable(), 1);
    expect(await repository.countUnavailable(), 1);
  });

  test('persiste inventário e resumo após reabrir banco', () async {
    final directory = Directory.systemTemp.createTempSync('inventory_reopen_');
    final file = File('${directory.path}/contexto.sqlite');
    await database.close();
    database = ContextoDatabase.forTesting(NativeDatabase(file));
    repository = LocalExistingScreenshotCandidateRepository(
      DriftExistingScreenshotCandidateStore(database),
    );
    final completedAt = DateTime.utc(2026, 7, 20);
    await repository.upsertBatch([candidate('external', 11)]);
    await repository.recordCompletedScan(
      completedAt: completedAt,
      partialAccess: false,
    );
    await database.close();

    database = ContextoDatabase.forTesting(NativeDatabase(file));
    repository = LocalExistingScreenshotCandidateRepository(
      DriftExistingScreenshotCandidateStore(database),
    );
    final summary = await repository.loadSummary();

    expect(summary.availableCount, 1);
    expect(summary.lastCompletedScanAt?.isAtSameMomentAs(completedAt), isTrue);
    expect(summary.lastScanWasPartial, isFalse);
    directory.deleteSync(recursive: true);
  });

  test(
    'processa 10.000 metadados em lotes sem lista completa na leitura',
    () async {
      for (var offset = 0; offset < 10000; offset += 200) {
        await repository.upsertBatch([
          for (var index = offset; index < offset + 200; index++)
            candidate('external', index),
        ]);
      }

      expect(await repository.countAvailable(), 10000);
      final firstPage = await repository.loadCandidatesPage(limit: 200);
      final secondPage = await repository.loadCandidatesPage(
        limit: 200,
        afterSourceKey: firstPage.last.sourceKey,
      );
      expect(firstPage, hasLength(200));
      expect(secondPage, hasLength(200));
      expect(secondPage.first.sourceKey, isNot(firstPage.first.sourceKey));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('limpeza remove somente as tabelas do inventário', () async {
    final mediaId = await database
        .into(database.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            privatePath: Value('/privado/item.png'),
            internalName: Value('item.png'),
            importedAt: DateTime.utc(2026),
            sourceMode: 'photoPicker',
            status: 'ready',
          ),
        );
    await repository.upsertBatch([candidate('external', 3)]);

    await repository.clearInventory();

    expect(await repository.countAvailable(), 0);
    expect(
      (await database.select(database.mediaItems).getSingle()).id,
      mediaId,
    );
  });

  test(
    'schema do inventário não armazena imagem, nome, caminho ou OCR',
    () async {
      final columns = await database
          .customSelect('PRAGMA table_info(existing_screenshot_candidates)')
          .get();
      final names = columns.map((row) => row.read<String>('name')).toSet();

      expect(
        names,
        containsAll(['source_key', 'media_store_id', 'volume_name']),
      );
      for (final forbidden in [
        'private_path',
        'display_name',
        'relative_path',
        'ocr_text',
        'image_bytes',
      ]) {
        expect(names, isNot(contains(forbidden)));
      }
    },
  );
}

ExistingScreenshotCandidate candidate(
  String volume,
  int id, {
  DateTime? discoveredAt,
  DateTime? lastSeenAt,
}) {
  final discovered = discoveredAt ?? DateTime.utc(2026, 7, 19);
  return ExistingScreenshotCandidate(
    sourceKey: '$volume:$id',
    mediaStoreId: id,
    volumeName: volume,
    contentUri: 'content://media/$volume/images/media/$id',
    mimeType: 'image/png',
    capturedAt: DateTime.utc(2025),
    dateModified: DateTime.utc(2025, 2),
    sizeBytes: 2048,
    width: 1080,
    height: 2400,
    discoveredAt: discovered,
    lastSeenAt: lastSeenAt ?? discovered,
    availability: ExistingScreenshotAvailability.available,
  );
}

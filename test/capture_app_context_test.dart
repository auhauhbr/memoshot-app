import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/database/contexto_database.dart';
import 'package:memoshot/features/classification/domain/contextual_classification.dart';
import 'package:memoshot/features/library/data/capture_app_context_repository.dart';
import 'package:memoshot/features/library/domain/capture_app_context.dart';

void main() {
  test(
    'persiste um contexto por item e substitui de forma idempotente',
    () async {
      final database = ContextoDatabase.forTesting(NativeDatabase.memory());
      final itemId = await database
          .into(database.mediaItems)
          .insert(
            MediaItemsCompanion.insert(
              privatePath: const Value('/private/new.png'),
              internalName: const Value('new.png'),
              importedAt: DateTime.utc(2026, 7, 19),
              sourceMode: 'photoPicker',
              status: 'ready',
            ),
          );
      final repository = DriftCaptureAppContextRepository(database);
      await repository.save(itemId, _context(NormalizedCaptureAppKey.brave));
      await repository.save(itemId, _context(NormalizedCaptureAppKey.chrome));

      final loaded = await repository.loadFor(itemId);
      expect(loaded?.normalizedAppKey, NormalizedCaptureAppKey.chrome);
      expect(
        await database.select(database.mediaCaptureContexts).get(),
        hasLength(1),
      );

      await (database.delete(
        database.mediaItems,
      )..where((row) => row.id.equals(itemId))).go();
      expect(
        await database.select(database.mediaCaptureContexts).get(),
        isEmpty,
      );
      await database.close();
    },
  );

  test('captureApp permanece separado da origem visual e não muda destino', () {
    const engine = ContextualClassificationEngine();
    final amazonInBrave = engine.classify(
      ocrText: 'amazon.com.br comprar carrinho preço R\$ 99,00',
      captureAppContext: _context(NormalizedCaptureAppKey.brave),
    );
    expect(
      amazonInBrave.captureAppContext?.normalizedAppKey,
      NormalizedCaptureAppKey.brave,
    );
    expect(amazonInBrave.origin.value, ProbableOrigin.amazon);
    expect(amazonInBrave.destination.root, 'Produtos');

    final whatsappWeb = engine.classify(
      ocrText: 'WhatsApp conversa mensagem',
      captureAppContext: _context(NormalizedCaptureAppKey.chrome),
    );
    expect(
      whatsappWeb.captureAppContext?.normalizedAppKey,
      NormalizedCaptureAppKey.chrome,
    );
    expect(whatsappWeb.origin.value, ProbableOrigin.whatsapp);
  });
}

CaptureAppContext _context(NormalizedCaptureAppKey key) => CaptureAppContext(
  packageName: 'technical.package',
  normalizedAppKey: key,
  eventTimestamp: DateTime.utc(2026, 7, 19, 12),
  captureTimestamp: DateTime.utc(2026, 7, 19, 12, 0, 1),
  deltaMilliseconds: 1000,
  confidenceLevel: CaptureAppConfidence.high,
  createdAt: DateTime.utc(2026, 7, 19, 12, 0, 1),
);

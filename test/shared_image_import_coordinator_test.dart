import 'dart:async';

import 'package:contexto/core/sharing/incoming_share_source.dart';
import 'package:contexto/features/library/data/media_item_repository.dart';
import 'package:contexto/features/library/domain/media_item.dart';
import 'package:contexto/features/library/domain/selected_screenshot.dart';
import 'package:contexto/features/library/domain/screenshot_search_result.dart';
import 'package:contexto/features/sharing/shared_image_import_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('processa compartilhamento inicial e reseta somente depois', () async {
    final source = FakeIncomingShareSource(
      initial: const [
        IncomingSharedMedia(
          path: '/tmp/inicial.png',
          type: IncomingMediaType.image,
          mimeType: 'image/png',
        ),
      ],
    );
    final repository = RecordingMediaRepository();
    final completed = Completer<void>();
    final coordinator = SharedImageImportCoordinator(
      source: source,
      repository: repository,
      onCompleted: (_) => completed.complete(),
      onError: () {},
    );

    await coordinator.start();
    await completed.future;
    await Future<void>.delayed(Duration.zero);

    expect(repository.origins.single, ImportOrigin.shared);
    expect(repository.batches.single.single.path, '/tmp/inicial.png');
    expect(source.resetCount, 1);
    await coordinator.dispose();
    await source.close();
  });

  test(
    'processa lotes do app aberto sequencialmente e aceita várias imagens',
    () async {
      final source = FakeIncomingShareSource();
      final repository = RecordingMediaRepository();
      final completed = Completer<void>();
      var count = 0;
      final coordinator = SharedImageImportCoordinator(
        source: source,
        repository: repository,
        onCompleted: (_) {
          count++;
          if (count == 2) completed.complete();
        },
        onError: () {},
      );
      await coordinator.start();

      source.emit(const [
        IncomingSharedMedia(path: '/tmp/a.png', type: IncomingMediaType.image),
        IncomingSharedMedia(path: '/tmp/b.png', type: IncomingMediaType.image),
      ]);
      source.emit(const [
        IncomingSharedMedia(path: '/tmp/c.png', type: IncomingMediaType.image),
      ]);
      await completed.future;
      await coordinator.dispose();

      expect(repository.batches.map((batch) => batch.length), [2, 1]);
      expect(repository.maxConcurrentImports, 1);
      expect(source.resetCount, 2);
      await source.close();
    },
  );

  test('ignora lote vazio e mídia que não seja imagem', () async {
    final source = FakeIncomingShareSource();
    final repository = RecordingMediaRepository();
    final coordinator = SharedImageImportCoordinator(
      source: source,
      repository: repository,
      onCompleted: (_) {},
      onError: () {},
    );
    await coordinator.start();

    source.emit(const []);
    source.emit(const [
      IncomingSharedMedia(
        path: '/tmp/video.mp4',
        type: IncomingMediaType.other,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    await coordinator.dispose();

    expect(repository.batches, isEmpty);
    expect(source.resetCount, 1);
    await source.close();
  });

  test('não processa duas vezes o mesmo evento e cancela assinatura', () async {
    final source = FakeIncomingShareSource();
    final repository = RecordingMediaRepository();
    final completed = Completer<void>();
    final coordinator = SharedImageImportCoordinator(
      source: source,
      repository: repository,
      onCompleted: (_) => completed.complete(),
      onError: () {},
    );
    await coordinator.start();
    const batch = [
      IncomingSharedMedia(
        path: '/tmp/repetida.png',
        type: IncomingMediaType.image,
      ),
    ];
    source.emit(batch);
    source.emit(batch);
    await completed.future;
    await Future<void>.delayed(Duration.zero);
    await coordinator.dispose();

    expect(repository.batches, hasLength(1));
    expect(source.cancelled, isTrue);
    await source.close();
  });

  test('erro da fonte não impede inicialização', () async {
    final source = FakeIncomingShareSource(failInitial: true);
    var errors = 0;
    final coordinator = SharedImageImportCoordinator(
      source: source,
      repository: RecordingMediaRepository(),
      onCompleted: (_) {},
      onError: () => errors++,
    );

    await expectLater(coordinator.start(), completes);
    expect(errors, 1);
    await coordinator.dispose();
    await source.close();
  });
}

class FakeIncomingShareSource implements IncomingShareSource {
  FakeIncomingShareSource({this.initial = const [], this.failInitial = false}) {
    _controller = StreamController<List<IncomingSharedMedia>>.broadcast(
      onCancel: () => cancelled = true,
    );
  }

  final List<IncomingSharedMedia> initial;
  final bool failInitial;
  late final StreamController<List<IncomingSharedMedia>> _controller;
  int resetCount = 0;
  bool cancelled = false;

  @override
  Future<List<IncomingSharedMedia>> getInitialMedia() async {
    if (failInitial) throw StateError('falha simulada');
    return initial;
  }

  @override
  Stream<List<IncomingSharedMedia>> get mediaStream => _controller.stream;

  @override
  Future<void> reset() async => resetCount++;

  void emit(List<IncomingSharedMedia> media) => _controller.add(media);

  Future<void> close() => _controller.close();
}

class RecordingMediaRepository implements MediaItemRepository {
  final List<List<SelectedScreenshot>> batches = [];
  final List<ImportOrigin> origins = [];
  int _activeImports = 0;
  int maxConcurrentImports = 0;

  @override
  Future<ImportResult> importScreenshots(
    List<SelectedScreenshot> screenshots, {
    ImportOrigin origin = ImportOrigin.picker,
  }) async {
    _activeImports++;
    if (_activeImports > maxConcurrentImports) {
      maxConcurrentImports = _activeImports;
    }
    batches.add(screenshots);
    origins.add(origin);
    await Future<void>.delayed(Duration.zero);
    _activeImports--;
    return const ImportResult(importedItems: [], duplicateCount: 0);
  }

  @override
  Future<List<MediaItem>> loadAvailableItems({int? tagId}) async => const [];

  @override
  Future<void> removeItem(MediaItem item) async {}

  @override
  Future<List<ScreenshotSearchResult>> searchRecognizedText(
    String query, {
    int? tagId,
    int limit = 100,
  }) async => const [];

  @override
  Future<void> close() async {}
}

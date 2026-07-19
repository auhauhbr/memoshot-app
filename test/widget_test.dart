import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:memoshot/app/memoshot_app.dart';
import 'package:memoshot/core/automatic_import/automatic_screenshot_source.dart';
import 'package:memoshot/core/media/screenshot_picker.dart';
import 'package:memoshot/core/media/original_media_viewer.dart';
import 'package:memoshot/core/media_store/existing_screenshot_scanner.dart';
import 'package:memoshot/core/media_store/media_store_content.dart';
import 'package:memoshot/core/sharing/incoming_share_source.dart';
import 'package:memoshot/core/theme/app_theme.dart';
import 'package:memoshot/core/text/search_snippet_builder.dart';
import 'package:memoshot/core/text/text_normalizer.dart';
import 'package:memoshot/features/categories/data/category_repository.dart';
import 'package:memoshot/features/categories/data/recent_folder_repository.dart';
import 'package:memoshot/features/categories/domain/category.dart';
import 'package:memoshot/features/categories/presentation/category_detail_page.dart';
import 'package:memoshot/features/classification/data/classification_suggestion_repository.dart';
import 'package:memoshot/features/classification/application/classification_queue_processor.dart';
import 'package:memoshot/features/classification/application/classification_processor.dart';
import 'package:memoshot/features/classification/domain/stored_classification_suggestion.dart';
import 'package:memoshot/features/classification/presentation/review_queue_page.dart';
import 'package:memoshot/features/existing_screenshots/application/existing_screenshot_inventory_coordinator.dart';
import 'package:memoshot/features/existing_screenshots/data/existing_screenshot_candidate_repository.dart';
import 'package:memoshot/features/existing_screenshots/domain/existing_screenshot_candidate.dart';
import 'package:memoshot/features/existing_screenshots/domain/existing_screenshot_scan.dart';
import 'package:memoshot/features/review_notifications/domain/review_notification.dart';
import 'package:memoshot/features/automatic_import/data/automatic_import_settings_repository.dart';
import 'package:memoshot/features/automatic_import/domain/automatic_import_settings.dart';
import 'package:memoshot/features/library/data/media_item_repository.dart';
import 'package:memoshot/features/library/domain/media_item.dart';
import 'package:memoshot/features/library/domain/media_page.dart';
import 'package:memoshot/features/library/domain/selected_screenshot.dart';
import 'package:memoshot/features/library/domain/screenshot_search_result.dart';
import 'package:memoshot/features/library/presentation/screenshot_grid.dart';
import 'package:memoshot/features/library/presentation/media_item_thumbnail.dart';
import 'package:memoshot/features/ocr/data/ocr_repository.dart';
import 'package:memoshot/features/ocr/domain/ocr_result.dart';
import 'package:memoshot/features/onboarding/data/onboarding_repository.dart';
import 'package:memoshot/features/processing/data/ocr_queue_processor.dart';
import 'package:memoshot/features/processing/domain/processing_job.dart';
import 'package:memoshot/features/tags/data/tag_repository.dart';
import 'package:memoshot/features/tags/domain/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'memoshot_widget_test_',
    );
  });

  tearDown(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    temporaryDirectory.deleteSync(recursive: true);
  });

  testWidgets('exibe a tela inicial funcional do MemoShot', (tester) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'MemoShot');
    expect(find.text('MemoShot'), findsOneWidget);
    expect(find.textContaining('Contexto'), findsNothing);
    expect(find.text('Organização inteligente'), findsOneWidget);
    expect(find.text('Pesquisar nos seus prints...'), findsOneWidget);
    expect(find.text('Pastas'), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Últimos prints'), findsOneWidget);
    expect(find.text('Ver todos'), findsOneWidget);
    expect(find.text('Nenhuma pasta criada.'), findsOneWidget);
    expect(find.text('Criar pasta'), findsOneWidget);
    expect(find.text('Nenhum print salvo.'), findsOneWidget);
    expect(find.text('Etiquetas'), findsNothing);
    expect(find.text('Importação automática'), findsNothing);
    expect(find.text('Processamento local'), findsNothing);
    expect(find.text('Recentes'), findsNothing);
    expect(find.byKey(const Key('add-print-button')), findsOneWidget);
  });

  testWidgets('habilita importação e pesquisa local', (tester) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pump();

    final searchField = tester.widget<TextField>(find.byType(TextField));
    final importButton = tester.widget<FloatingActionButton>(
      find.byKey(const Key('add-print-button')),
    );

    expect(searchField.enabled, isTrue);
    expect(searchField.textInputAction, TextInputAction.search);
    expect(importButton.onPressed, isNotNull);
  });

  testWidgets('Home oculta Para revisar quando não há pendências', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pump();

    expect(find.byKey(const Key('pending-review-summary')), findsNothing);
  });

  testWidgets('Home preserva sugestões pendentes sem expor revisão', (
    tester,
  ) async {
    final suggestions = FakeClassificationSuggestionRepository(
      pending: [createSuggestion(1)],
      counts: const [1],
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        classificationRepository: suggestions,
      ),
    );
    await tester.pump();

    expect(find.text('Para revisar'), findsNothing);
    expect(find.byKey(const Key('open-review-queue')), findsNothing);
    expect(find.byKey(const Key('pending-review-summary')), findsNothing);
    expect(await suggestions.loadPendingReview(), hasLength(1));
    expect(suggestions.countCallCount, 0);
  });

  testWidgets('Pastas recentes começa ausente e registra pasta e subpasta', (
    tester,
  ) async {
    final categories = FakeCategoryRepository();
    final root = await categories.createRootCategory('Livros');
    final child = await categories.createSubcategory(
      parentId: root.id,
      name: 'Trechos',
    );
    final store = MemoryRecentFolderIdStore();
    final recents = LocalRecentFolderRepository(
      store: store,
      categoryRepository: categories,
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        categoryRepository: categories,
        recentFolderRepository: recents,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recent-folders-title')), findsNothing);

    await tester.tap(find.byKey(Key('folder-${root.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('subfolder-${child.id}')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recent-folders-title')), findsOneWidget);
    expect(find.byKey(Key('recent-folder-${child.id}')), findsOneWidget);
    expect(find.byKey(Key('recent-folder-${root.id}')), findsOneWidget);
    expect(store.ids, [child.id, root.id]);
    final recentCard = find.byKey(Key('recent-folder-${child.id}'));
    final rootCard = find.byKey(Key('folder-${root.id}'));
    expect(tester.getSize(recentCard), const Size(112, 52));
    expect(tester.getSize(rootCard), const Size(112, 52));
    expect(
      find.descendant(of: recentCard, matching: find.byType(Icon)),
      findsNothing,
    );
    expect(
      find.descendant(of: rootCard, matching: find.byType(Icon)),
      findsNothing,
    );
    final recentMaterialCard = tester.widget<Card>(
      find.descendant(of: recentCard, matching: find.byType(Card)),
    );
    final shape = recentMaterialCard.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.zero);
    final searchY = tester
        .getTopLeft(find.byKey(const Key('home-search-field')))
        .dy;
    final recentY = tester
        .getTopLeft(find.byKey(const Key('recent-folders-title')))
        .dy;
    final foldersY = tester
        .getTopLeft(find.byKey(const Key('folders-title')))
        .dy;
    final printsY = tester
        .getTopLeft(find.byKey(const Key('all-prints-title')))
        .dy;
    expect(searchY, lessThan(recentY));
    expect(recentY, lessThan(foldersY));
    expect(foldersY, lessThan(printsY));
  });

  testWidgets('falha de preferências recentes não bloqueia a Home', (
    tester,
  ) async {
    final categories = FakeCategoryRepository();
    final store = MemoryRecentFolderIdStore()
      ..loadError = StateError('preferência indisponível');
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        categoryRepository: categories,
        recentFolderRepository: LocalRecentFolderRepository(
          store: store,
          categoryRepository: categories,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MemoShot'), findsOneWidget);
    expect(find.text('Pastas'), findsOneWidget);
    expect(find.text('Últimos prints'), findsOneWidget);
    expect(find.byKey(const Key('recent-folders-title')), findsNothing);
  });

  testWidgets('cancelar seleção não altera a biblioteca', (tester) async {
    final picker = FakeScreenshotPicker();
    await tester.pumpWidget(buildTestApp(picker));
    await tester.pump();

    await tester.tap(find.text('Adicionar print').last);
    await tester.pump();

    expect(picker.pickCallCount, 1);
    expect(find.text('0 itens'), findsOneWidget);
    expect(find.byKey(const Key('persisted-screenshot-grid')), findsNothing);
  });

  testWidgets('mostra uma imagem selecionada e atualiza o contador', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'uma.png');
    final picker = FakeScreenshotPicker(
      selections: [SelectedScreenshot(path: image.path)],
    );
    await tester.pumpWidget(buildTestApp(picker));
    await tester.pump();

    await tester.tap(find.text('Adicionar print').last);
    await tester.pump();

    expect(find.text('1 item'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Salvo neste dispositivo.'), findsOneWidget);
    expect(find.text('Nenhuma pasta criada.'), findsOneWidget);
  });

  testWidgets('mostra múltiplas imagens selecionadas', (tester) async {
    final first = createTestImage(temporaryDirectory, 'primeira.png');
    final second = createTestImage(temporaryDirectory, 'segunda.png');
    final picker = FakeScreenshotPicker(
      selections: [
        SelectedScreenshot(path: first.path),
        SelectedScreenshot(path: second.path),
      ],
    );
    await tester.pumpWidget(buildTestApp(picker));
    await tester.pump();

    await tester.tap(find.text('Adicionar print').last);
    await tester.pump();

    expect(find.text('2 itens'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('não adiciona novamente caminhos repetidos na sessão', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'repetida.png');
    final selected = SelectedScreenshot(path: image.path);
    final picker = FakeScreenshotPicker(selections: [selected, selected]);
    await tester.pumpWidget(buildTestApp(picker));
    await tester.pump();

    await tester.tap(find.text('Adicionar print').last);
    await tester.pump();
    expect(find.text('Este screenshot já está na biblioteca.'), findsOneWidget);
    await tester.tap(find.text('Adicionar print').last);
    await tester.pump();

    expect(find.text('1 item'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.text('2 screenshots já estavam na biblioteca.'),
      findsOneWidget,
    );
  });

  testWidgets('exibe carregamento enquanto o seletor processa', (tester) async {
    final completer = Completer<List<SelectedScreenshot>>();
    final picker = FakeScreenshotPicker(pickCompleter: completer);
    await tester.pumpWidget(buildTestApp(picker));
    await tester.pump();

    await tester.tap(find.text('Adicionar print').last);
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('add-print-button')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    final button = tester.widget<FloatingActionButton>(
      find.byKey(const Key('add-print-button')),
    );
    expect(button.onPressed, isNull);

    completer.complete(const []);
    await tester.pump();
    expect(find.text('Adicionar print'), findsWidgets);
  });

  testWidgets('exibe mensagem discreta quando a seleção falha', (tester) async {
    final picker = FakeScreenshotPicker(error: Exception('falha privada'));
    await tester.pumpWidget(buildTestApp(picker));
    await tester.pump();

    await tester.tap(find.text('Adicionar print').last);
    await tester.pump();

    expect(find.text('Não foi possível importar as imagens.'), findsOneWidget);
    expect(find.textContaining('falha privada'), findsNothing);
  });

  testWidgets('recupera imagens perdidas na inicialização', (tester) async {
    final image = createTestImage(temporaryDirectory, 'recuperada.png');
    final picker = FakeScreenshotPicker(
      lostSelections: [SelectedScreenshot(path: image.path)],
    );

    await tester.pumpWidget(buildTestApp(picker));
    await tester.pump();

    expect(picker.retrieveCallCount, 1);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('carrega itens persistidos ao abrir a HomePage', (tester) async {
    final image = createTestImage(temporaryDirectory, 'persistida.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );

    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();

    expect(repository.loadCallCount, 1);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('tocar na miniatura abre os detalhes e voltar funciona', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'detalhe.png');
    final repository = FakeMediaItemRepository(
      initialItems: [
        createMediaItem(
          1,
          image.path,
          importedAt: DateTime(2026, 1, 2, 3, 4),
          capturedAt: DateTime(2025, 12, 31, 23, 59),
        ),
      ],
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();

    await openFirstScreenshot(tester);

    expect(find.text('Detalhes do screenshot'), findsOneWidget);
    expect(find.text('Capturado em'), findsOneWidget);
    expect(find.text('31 de dezembro de 2025, às 23:59'), findsOneWidget);
    expect(find.text('02 de janeiro de 2026, às 03:04'), findsNothing);
    expect(find.text('Selecionado no dispositivo'), findsOneWidget);
    expect(find.text('Salvo neste dispositivo'), findsOneWidget);
    expect(
      find.text('O arquivo original da galeria não será alterado.'),
      findsOneWidget,
    );
    expect(find.textContaining(image.path), findsNothing);
    expect(find.textContaining('hash-secreto'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Últimos prints'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets('detalhes carregam e exibem estado vazio de etiquetas', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'sem-etiquetas.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final tagRepository = FakeTagRepository();
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        tagRepository: tagRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await tester.ensureVisible(find.byKey(const Key('tags-section')));

    expect(find.text('Etiquetas'), findsOneWidget);
    expect(find.text('Nenhuma etiqueta adicionada.'), findsOneWidget);
    expect(find.text('Texto reconhecido'), findsOneWidget);
    expect(tagRepository.loadForMediaCallCount, 1);
  });

  testWidgets('reorganiza somente o item e mostra mensagem sem porcentagem', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'reorganizar.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final classification = FakeReprocessingClassificationQueue();
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        classificationQueue: classification,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await tester.ensureVisible(
      find.byKey(const Key('reorganize-automatically-button')),
    );

    await tester.tap(find.text('Reorganizar automaticamente'));
    await tester.pumpAndSettle();

    expect(classification.reprocessedIds, [1]);
    expect(find.text('Organização atualizada.'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('aceitar', findRichText: true), findsNothing);
    expect(find.textContaining('rejeitar', findRichText: true), findsNothing);
  });

  testWidgets('reprocessamento incerto mostra mensagem simples', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'incerto.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final classification = FakeReprocessingClassificationQueue(
      status: IndividualReprocessStatus.uncertain,
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        classificationQueue: classification,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await tester.ensureVisible(
      find.byKey(const Key('reorganize-automatically-button')),
    );

    await tester.tap(find.text('Reorganizar automaticamente'));
    await tester.pumpAndSettle();

    expect(
      find.text('O MemoShot não encontrou uma organização segura.'),
      findsOneWidget,
    );
  });

  testWidgets('detalhes exibem uma e várias etiquetas preservando os nomes', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'com-etiquetas.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final tagRepository = FakeTagRepository();
    final first = await tagRepository.createTag('Atenção Máxima');
    final second = await tagRepository.createTag('Precisa responder');
    await tagRepository.addToMedia(tagId: first.id, mediaItemId: 1);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        tagRepository: tagRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await tester.ensureVisible(find.byKey(const Key('tags-section')));

    expect(find.text('Atenção Máxima'), findsOneWidget);
    expect(find.byKey(ValueKey('tag-chip-${first.id}')), findsOneWidget);

    await tagRepository.addToMedia(tagId: second.id, mediaItemId: 1);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await openFirstScreenshot(tester);
    await tester.ensureVisible(find.byKey(const Key('tags-section')));

    expect(find.byKey(ValueKey('tag-chip-${first.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('tag-chip-${second.id}')), findsOneWidget);
  });

  testWidgets('carregamento de etiquetas não bloqueia o restante do detalhe', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'tags-loading.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final completer = Completer<List<Tag>>();
    final tagRepository = FakeTagRepository(loadForMediaCompleter: completer);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        tagRepository: tagRepository,
      ),
    );
    await tester.pump();
    final tile = find.byKey(const ValueKey('screenshot-tile-1'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Detalhes do screenshot'), findsOneWidget);
    expect(find.text('Texto reconhecido'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('tags-section')));
    expect(find.byKey(const Key('tags-loading-indicator')), findsOneWidget);

    completer.complete(const []);
    await tester.pump();
    expect(find.text('Nenhuma etiqueta adicionada.'), findsOneWidget);
  });

  testWidgets('interface de adição pesquisa e lista etiquetas disponíveis', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'listar-tags.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final tagRepository = FakeTagRepository();
    final associated = await tagRepository.createTag('Associada');
    final studies = await tagRepository.createTag('Estudos');
    final work = await tagRepository.createTag('Trabalho');
    await tagRepository.addToMedia(tagId: associated.id, mediaItemId: 1);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        tagRepository: tagRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await openAddTagDialog(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.byKey(ValueKey('available-tag-${associated.id}')),
      findsNothing,
    );
    expect(find.byKey(ValueKey('available-tag-${studies.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('available-tag-${work.id}')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('tag-search-field')), 'estu');
    await tester.pump();
    expect(find.byKey(ValueKey('available-tag-${studies.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('available-tag-${work.id}')), findsNothing);
  });

  testWidgets('associa etiqueta existente e atualiza a tela imediatamente', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'associar-tag.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final tagRepository = FakeTagRepository();
    final tag = await tagRepository.createTag('Importante');
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        tagRepository: tagRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await openAddTagDialog(tester);
    await tester.tap(find.byKey(ValueKey('available-tag-${tag.id}')));
    await tester.pump();

    expect(find.byKey(ValueKey('tag-chip-${tag.id}')), findsOneWidget);
    expect(
      await tagRepository.isAssociated(tagId: tag.id, mediaItemId: 1),
      isTrue,
    );
    expect(tagRepository.addCallCount, 1);
  });

  testWidgets('cria e associa nova etiqueta removendo espaços externos', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'criar-tag.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final tagRepository = FakeTagRepository();
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        tagRepository: tagRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await openAddTagDialog(tester);
    await tester.enterText(
      find.byKey(const Key('tag-search-field')),
      '  Próxima ação  ',
    );
    await tester.tap(find.byKey(const Key('create-and-add-tag-button')));
    await tester.pump();

    expect(find.text('Próxima ação'), findsOneWidget);
    expect((await tagRepository.loadTags()).single.name, 'Próxima ação');
    expect(tagRepository.createCallCount, 1);
    expect(tagRepository.addCallCount, 1);
  });

  testWidgets('reutiliza etiqueta equivalente sem criar duplicata', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'reusar-tag.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final tagRepository = FakeTagRepository();
    final existing = await tagRepository.createTag('Urgente');
    tagRepository.createCallCount = 0;
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        tagRepository: tagRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await openAddTagDialog(tester);
    await tester.enterText(
      find.byKey(const Key('tag-search-field')),
      ' URGÉNTE ',
    );
    await tester.tap(find.byKey(const Key('create-and-add-tag-button')));
    await tester.pump();

    expect(await tagRepository.loadTags(), hasLength(1));
    expect(find.byKey(ValueKey('tag-chip-${existing.id}')), findsOneWidget);
    expect(tagRepository.addCallCount, 1);
  });

  testWidgets('rejeita nome vazio sem fechar a interface de adição', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'tag-vazia.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final tagRepository = FakeTagRepository();
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        tagRepository: tagRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await openAddTagDialog(tester);
    await tester.enterText(find.byKey(const Key('tag-search-field')), '   ');
    await tester.tap(find.byKey(const Key('create-and-add-tag-button')));
    await tester.pump();

    expect(find.text('Digite um nome para a etiqueta.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tagRepository.createCallCount, 0);
  });

  testWidgets('remove apenas associação e preserva etiqueta e screenshot', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'remover-tag.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final tagRepository = FakeTagRepository();
    final tag = await tagRepository.createTag('Manter cadastro');
    await tagRepository.addToMedia(tagId: tag.id, mediaItemId: 1);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        tagRepository: tagRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await tester.ensureVisible(find.byKey(ValueKey('tag-chip-${tag.id}')));
    await tester.tap(find.byTooltip('Remover etiqueta Manter cadastro'));
    await tester.pump();

    expect(find.text('Nenhuma etiqueta adicionada.'), findsOneWidget);
    expect(await tagRepository.findById(tag.id), isNotNull);
    expect(tagRepository.deleteCallCount, 0);
    expect(mediaRepository.itemCount, 1);
    expect(mediaRepository.removeCallCount, 0);
    expect(image.existsSync(), isTrue);
  });

  testWidgets('exibe erros ao carregar, associar e remover etiquetas', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'erros-tags.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final loadFailure = FakeTagRepository(failLoadForMedia: true);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        tagRepository: loadFailure,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await tester.ensureVisible(find.byKey(const Key('tags-section')));
    expect(
      find.text('Não foi possível carregar as etiquetas.'),
      findsOneWidget,
    );

    final operationFailure = FakeTagRepository(failAdd: true, failRemove: true);
    final available = await operationFailure.createTag('Falha ao adicionar');
    final associated = await operationFailure.createTag('Falha ao remover');
    operationFailure.seedAssociation(tagId: associated.id, mediaItemId: 1);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        tagRepository: operationFailure,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await openAddTagDialog(tester);
    await tester.tap(find.byKey(ValueKey('available-tag-${available.id}')));
    await tester.pump();
    expect(find.text('Não foi possível adicionar a etiqueta.'), findsOneWidget);

    await tester.tap(find.byTooltip('Remover etiqueta Falha ao remover'));
    await tester.pump();
    expect(find.text('Não foi possível remover a etiqueta.'), findsOneWidget);
    expect(find.byKey(ValueKey('tag-chip-${associated.id}')), findsOneWidget);
  });

  testWidgets(
    'descarte durante associação pendente não atualiza tela fechada',
    (tester) async {
      final image = createTestImage(temporaryDirectory, 'tag-pendente.png');
      final mediaRepository = FakeMediaItemRepository(
        initialItems: [createMediaItem(1, image.path)],
      );
      final addCompleter = Completer<void>();
      final tagRepository = FakeTagRepository(addCompleter: addCompleter);
      final tag = await tagRepository.createTag('Pendente');
      await tester.pumpWidget(
        buildTestApp(
          FakeScreenshotPicker(),
          repository: mediaRepository,
          tagRepository: tagRepository,
        ),
      );
      await tester.pump();
      await openFirstScreenshot(tester);
      await openAddTagDialog(tester);
      await tester.tap(find.byKey(ValueKey('available-tag-${tag.id}')));
      await tester.pump();
      expect(tagRepository.addCallCount, 1);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      addCompleter.complete();
      await tester.pump();

      expect(find.text('Últimos prints'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelar remoção mantém item, registro e arquivo', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'cancelar.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();
    await openFirstScreenshot(tester);

    await tapRemoveFromMemoShot(tester);
    expect(find.text('Remover do MemoShot?'), findsOneWidget);
    expect(
      find.textContaining('O arquivo original da galeria será preservado.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.removeCallCount, 0);
    expect(repository.itemCount, 1);
    expect(image.existsSync(), isTrue);
    expect(find.text('Detalhes do screenshot'), findsOneWidget);
  });

  testWidgets('confirmar remoção atualiza grade, contador e estado vazio', (
    tester,
  ) async {
    final original = createTestImage(temporaryDirectory, 'original.png');
    final privateCopy = createTestImage(temporaryDirectory, 'copia.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, privateCopy.path)],
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();
    await openFirstScreenshot(tester);

    await tapRemoveFromMemoShot(tester);
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(repository.removeCallCount, 1);
    expect(repository.itemCount, 0);
    expect(privateCopy.existsSync(), isFalse);
    expect(original.existsSync(), isTrue);
    expect(find.text('0 itens'), findsOneWidget);
    expect(find.byKey(const Key('persisted-screenshot-grid')), findsNothing);
  });

  testWidgets('arquivo ausente mostra erro e permite voltar', (tester) async {
    final missingPath = '${temporaryDirectory.path}/ausente.png';
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, missingPath)],
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('A imagem salva não está disponível.'), findsOneWidget);
    expect(find.text('Extrair texto'), findsNothing);
    expect(
      find.text('A imagem precisa estar disponível para extrair texto.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Últimos prints'), findsOneWidget);
  });

  testWidgets('falha ao excluir cópia mantém detalhe e item coerentes', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'falha.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
      failRemoval: true,
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await tapRemoveFromMemoShot(tester);
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível remover este screenshot.'),
      findsOneWidget,
    );
    expect(repository.itemCount, 1);
    expect(image.existsSync(), isTrue);
    expect(find.text('Detalhes do screenshot'), findsOneWidget);
  });

  testWidgets('carrega texto OCR persistido como conteúdo selecionável', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'ocr-persistido.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final ocrRepository = FakeOcrRepository(
      initialResults: {1: createOcrResult(1, 'Texto persistido fictício')},
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        ocrRepository: ocrRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);

    expect(find.text('Texto reconhecido'), findsOneWidget);
    expect(find.text('Texto persistido fictício'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(ocrRepository.processCallCount, 0);
    expect(find.text('Processar novamente'), findsOneWidget);
  });

  testWidgets('extrai texto manualmente e atualiza a seção', (tester) async {
    final image = createTestImage(temporaryDirectory, 'ocr-manual.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final ocrRepository = FakeOcrRepository(
      texts: ['Resultado local fictício'],
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        ocrRepository: ocrRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await tapDetailAction(tester, 'Extrair texto');

    expect(ocrRepository.processCallCount, 1);
    expect(find.text('Resultado local fictício'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('resultado OCR vazio apresenta estado correto', (tester) async {
    final image = createTestImage(temporaryDirectory, 'ocr-vazio.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final ocrRepository = FakeOcrRepository(texts: ['']);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        ocrRepository: ocrRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await tapDetailAction(tester, 'Extrair texto');

    expect(
      find.text('Nenhum texto foi encontrado nesta imagem.'),
      findsOneWidget,
    );
    expect(find.text('Processar novamente'), findsOneWidget);
  });

  testWidgets('erro de OCR não cria resultado falso e permite nova tentativa', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'ocr-erro.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final ocrRepository = FakeOcrRepository(error: StateError('texto privado'));
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        ocrRepository: ocrRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await tapDetailAction(tester, 'Extrair texto');

    expect(
      find.text('Não foi possível extrair o texto da imagem.'),
      findsOneWidget,
    );
    expect(find.textContaining('texto privado'), findsNothing);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('reprocessamento substitui o texto exibido', (tester) async {
    final image = createTestImage(temporaryDirectory, 'ocr-reprocessar.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final ocrRepository = FakeOcrRepository(
      initialResults: {1: createOcrResult(1, 'Texto anterior')},
      texts: ['Texto atualizado'],
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        ocrRepository: ocrRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    await tapDetailAction(tester, 'Processar novamente');

    expect(find.text('Texto anterior'), findsNothing);
    expect(find.text('Texto atualizado'), findsOneWidget);
  });

  testWidgets('carregamento impede processamentos OCR simultâneos', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'ocr-carregando.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final completer = Completer<OcrResult>();
    final ocrRepository = FakeOcrRepository(processCompleter: completer);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        ocrRepository: ocrRepository,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);

    final action = find.text('Extrair texto');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();

    final processingButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Extraindo texto...'),
    );
    expect(processingButton.onPressed, isNull);
    expect(ocrRepository.processCallCount, 1);

    completer.complete(createOcrResult(1, 'Concluído'));
    await tester.pump();
    expect(find.text('Concluído'), findsOneWidget);
  });

  testWidgets('Home não ocupa cards com textos persistentes de OCR', (
    tester,
  ) async {
    final items = <MediaItem>[];
    for (var id = 1; id <= 5; id++) {
      final image = createTestImage(temporaryDirectory, 'estado-$id.png');
      items.add(createMediaItem(id, image.path));
    }
    final mediaRepository = FakeMediaItemRepository(initialItems: items);
    final ocrRepository = FakeOcrRepository(
      initialResults: {
        3: createOcrResult(3, 'Texto fictício'),
        4: createOcrResult(4, ''),
      },
    );
    final queue = FakeOcrQueue(
      ocrRepository,
      initialStates: const {
        1: OcrItemState.pending,
        2: OcrItemState.processing,
        3: OcrItemState.completedWithText,
        4: OcrItemState.completedWithoutText,
        5: OcrItemState.failed,
      },
    );

    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        ocrRepository: ocrRepository,
        ocrQueue: queue,
      ),
    );
    await tester.pump();

    for (final label in [
      'Aguardando',
      'Processando',
      'Texto extraído',
      'Sem texto',
      'Falha',
    ]) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('falha oferece nova tentativa e redefine a tarefa', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'tentar-novamente.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final ocrRepository = FakeOcrRepository(texts: ['Recuperado']);
    final queue = FakeOcrQueue(
      ocrRepository,
      initialStates: const {1: OcrItemState.failed},
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        ocrRepository: ocrRepository,
        ocrQueue: queue,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);

    await tapDetailAction(tester, 'Tentar novamente');
    await tester.pump();

    expect(queue.retryCallCount, 1);
    expect(find.text('Recuperado'), findsOneWidget);
    expect(find.text('Texto extraído'), findsOneWidget);
  });

  testWidgets('ações de OCR ficam desabilitadas durante processamento', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'processando.png');
    final mediaRepository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final ocrRepository = FakeOcrRepository();
    final queue = FakeOcrQueue(
      ocrRepository,
      initialStates: const {1: OcrItemState.processing},
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: mediaRepository,
        ocrRepository: ocrRepository,
        ocrQueue: queue,
      ),
    );
    await tester.pump();
    final tile = find.byKey(const ValueKey('screenshot-tile-1'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Extraindo texto...'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Processando'), findsWidgets);
  });

  testWidgets('Home abre sem aguardar a recuperação da fila', (tester) async {
    final recovery = Completer<void>();
    final ocrRepository = FakeOcrRepository();
    final queue = FakeOcrQueue(ocrRepository, recoveryCompleter: recovery);

    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        ocrRepository: ocrRepository,
        ocrQueue: queue,
      ),
    );
    await tester.pump();

    expect(find.text('Últimos prints'), findsOneWidget);
    expect(find.text('Adicionar print'), findsWidgets);
    recovery.complete();
  });

  testWidgets('digitação pesquisa OCR e limpar restaura a biblioteca', (
    tester,
  ) async {
    final first = createTestImage(temporaryDirectory, 'busca-1.png');
    final second = createTestImage(temporaryDirectory, 'busca-2.png');
    final repository = FakeMediaItemRepository(
      initialItems: [
        createMediaItem(1, first.path),
        createMediaItem(2, second.path),
      ],
      recognizedTexts: const {1: 'Código local encontrado'},
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'codigo');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('1 resultado para “codigo”'), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-2')), findsNothing);
    expect(find.textContaining('Código local'), findsOneWidget);

    await tester.tap(find.byTooltip('Limpar pesquisa'));
    await tester.pump();

    expect(repository.searchCallCount, 1);
    expect(find.textContaining('resultado para'), findsNothing);
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-2')), findsOneWidget);
  });

  testWidgets('pesquisa sem correspondência mostra estado vazio', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'sem-resultado.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
      recognizedTexts: const {1: 'Outro conteúdo'},
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('0 resultados para “inexistente”'), findsOneWidget);
    expect(find.text('Nenhum print corresponde à pesquisa.'), findsOneWidget);
  });

  testWidgets('erro de pesquisa mostra mensagem genérica', (tester) async {
    final repository = FakeMediaItemRepository(
      searchError: StateError('consulta e conteúdo privados'),
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'consulta');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Não foi possível realizar a pesquisa.'), findsOneWidget);
    expect(find.textContaining('conteúdo privados'), findsNothing);
  });

  testWidgets('resultado abre detalhes e voltar preserva a consulta', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'abrir-busca.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
      recognizedTexts: const {1: 'Código persistido'},
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'codigo');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await openFirstScreenshot(tester);
    expect(find.text('Detalhes do screenshot'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('1 resultado para “codigo”'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'codigo',
    );
  });

  testWidgets('debounce evita consultas durante digitação contínua', (
    tester,
  ) async {
    final repository = FakeMediaItemRepository();
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();
    final field = find.byType(TextField);

    await tester.enterText(field, 'co');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.enterText(field, 'codi');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.enterText(field, 'codigo');
    await tester.pump(const Duration(milliseconds: 299));
    expect(repository.searchCallCount, 0);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(repository.searchCallCount, 1);
    expect(repository.searchQueries, ['codigo']);
  });

  testWidgets('resultado antigo não substitui consulta mais nova', (
    tester,
  ) async {
    final firstImage = createTestImage(temporaryDirectory, 'antiga.png');
    final secondImage = createTestImage(temporaryDirectory, 'nova.png');
    final firstItem = createMediaItem(1, firstImage.path);
    final secondItem = createMediaItem(2, secondImage.path);
    final firstSearch = Completer<List<ScreenshotSearchResult>>();
    final secondSearch = Completer<List<ScreenshotSearchResult>>();
    final repository = FakeMediaItemRepository(
      initialItems: [firstItem, secondItem],
      searchCompleters: {'primeira': firstSearch, 'segunda': secondSearch},
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'primeira');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'segunda');
    await tester.pump(const Duration(milliseconds: 300));
    secondSearch.complete([
      ScreenshotSearchResult(mediaItem: secondItem, snippet: 'Segunda busca'),
    ]);
    await tester.pump();
    firstSearch.complete([
      ScreenshotSearchResult(mediaItem: firstItem, snippet: 'Primeira busca'),
    ]);
    await tester.pump();

    expect(find.text('1 resultado para “segunda”'), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsNothing);
  });

  testWidgets('OCR concluído atualiza pesquisa ativa e mantém consulta', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'ocr-dinamico.png');
    final item = createMediaItem(1, image.path);
    final repository = FakeMediaItemRepository(initialItems: [item]);
    final ocrRepository = FakeOcrRepository();
    final queue = FakeOcrQueue(
      ocrRepository,
      initialStates: const {1: OcrItemState.pending},
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        ocrRepository: ocrRepository,
        ocrQueue: queue,
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'local');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(
      find.text('Alguns screenshots ainda estão sendo processados.'),
      findsOneWidget,
    );
    expect(find.text('Nenhum print corresponde à pesquisa.'), findsOneWidget);

    repository.setRecognizedText(1, 'Resultado local concluído');
    queue.emitState(1, OcrItemState.completedWithText);
    await tester.pump();
    await tester.pump();

    expect(find.text('1 resultado para “local”'), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
  });

  testWidgets('item importado aparece na busca somente após concluir OCR', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'importado-busca.png');
    final picker = FakeScreenshotPicker(
      selections: [SelectedScreenshot(path: image.path)],
    );
    final repository = FakeMediaItemRepository();
    final ocrRepository = FakeOcrRepository();
    final queue = FakeOcrQueue(ocrRepository);
    await tester.pumpWidget(
      buildTestApp(
        picker,
        repository: repository,
        ocrRepository: ocrRepository,
        ocrQueue: queue,
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'novo');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.tap(find.text('Adicionar print').last);
    await tester.pump();
    expect(find.text('Nenhum print corresponde à pesquisa.'), findsOneWidget);

    repository.setRecognizedText(1, 'Novo resultado importado');
    queue.emitState(1, OcrItemState.completedWithText);
    await tester.pump();
    await tester.pump();

    expect(find.text('1 resultado para “novo”'), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
  });

  testWidgets('remoção atualiza resultados da pesquisa', (tester) async {
    final image = createTestImage(temporaryDirectory, 'remover-busca.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
      recognizedTexts: const {1: 'Termo removível'},
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'termo');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await openFirstScreenshot(tester);

    await tapRemoveFromMemoShot(tester);
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(find.text('0 resultados para “termo”'), findsOneWidget);
    expect(find.text('Nenhum print corresponde à pesquisa.'), findsOneWidget);
  });

  testWidgets('pesquisa não apresenta overflow em largura de 320 pixels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image = createTestImage(temporaryDirectory, 'busca-estreita.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
      recognizedTexts: const {1: 'Texto para busca estreita'},
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'estreita');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('1 resultado para “estreita”'), findsOneWidget);
  });

  testWidgets('mantém o tema claro com brilho de plataforma escuro', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pump();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

    expect(materialApp.themeMode, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
    expect(scaffold.backgroundColor, isNull);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
      AppTheme.background,
    );
  });

  testWidgets('não apresenta overflow em uma tela de 320 por 568', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Processamento local'), findsNothing);
  });

  testWidgets('gerenciamento de Pastas abre categorias com estado vazio', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pump();

    expect(find.text('Nenhuma pasta criada.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();

    expect(find.text('Pastas'), findsOneWidget);
    expect(find.text('Nenhuma pasta criada.'), findsOneWidget);
    expect(find.text('Nova pasta'), findsOneWidget);
  });

  testWidgets('categorias aparecem como pastas e abrem o detalhe existente', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'pasta-home.png');
    final item = createMediaItem(1, image.path);
    final media = FakeMediaItemRepository(initialItems: [item]);
    final categories = FakeCategoryRepository();
    final category = await categories.createCategory('Carreira');
    categories.mediaItems.add(item);
    await categories.replaceForMedia(1, {category.id});

    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: media,
        categoryRepository: categories,
      ),
    );
    await tester.pump();

    expect(find.text('Carreira'), findsOneWidget);
    expect(find.text('1 print'), findsOneWidget);
    await tester.tap(find.byKey(Key('folder-${category.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Carreira'), findsWidgets);
    expect(find.text('1 print'), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
  });

  testWidgets('pastas com nomes longos não causam overflow na Home', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final categories = FakeCategoryRepository();
    await categories.createCategory('Referências profissionais extensas');

    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final label = tester.widget<Text>(
      find.text('Referências profissionais extensas'),
    );
    expect(label.overflow, TextOverflow.ellipsis);
  });

  testWidgets('Home mostra somente raízes ordenadas e preserva Todos', (
    tester,
  ) async {
    final categories = FakeCategoryRepository();
    final zeta = await categories.createRootCategory('Zeta');
    final alpha = await categories.createRootCategory('Álbuns');
    final child = await categories.createSubcategory(
      parentId: alpha.id,
      name: 'Viagens',
    );

    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();

    expect(find.byKey(const Key('all-folder')), findsOneWidget);
    expect(find.byKey(Key('folder-${alpha.id}')), findsOneWidget);
    expect(find.byKey(Key('folder-${zeta.id}')), findsOneWidget);
    expect(find.byKey(Key('folder-${child.id}')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(Key('folder-${alpha.id}'))).dx,
      lessThan(tester.getTopLeft(find.byKey(Key('folder-${zeta.id}'))).dx),
    );
  });

  testWidgets(
    'detalhe navega por subpastas com breadcrumb e prints somente diretos',
    (tester) async {
      final rootFile = createTestImage(temporaryDirectory, 'raiz.png');
      final childFile = createTestImage(temporaryDirectory, 'filha.png');
      final media = FakeMediaItemRepository(
        initialItems: [
          createMediaItem(1, rootFile.path, importedAt: DateTime(2025)),
          createMediaItem(2, childFile.path, importedAt: DateTime(2026)),
        ],
      );
      final categories = FakeCategoryRepository();
      final root = await categories.createRootCategory('Livros');
      final child = await categories.createSubcategory(
        parentId: root.id,
        name: 'Trechos',
      );
      final grandchild = await categories.createSubcategory(
        parentId: child.id,
        name: 'Favoritos',
      );
      await categories.replaceForMedia(1, {root.id});
      await categories.replaceForMedia(2, {child.id});

      await tester.pumpWidget(
        buildTestApp(
          FakeScreenshotPicker(),
          repository: media,
          categoryRepository: categories,
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(Key('folder-${root.id}')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('category-breadcrumb')), findsOneWidget);
      expect(find.text('Pastas'), findsOneWidget);
      expect(find.byKey(Key('subfolder-${child.id}')), findsOneWidget);
      expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('screenshot-tile-2')), findsNothing);
      expect(find.text('1 print · 1 subpasta'), findsOneWidget);

      await tester.tap(find.byKey(Key('subfolder-${child.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('breadcrumb-${root.id}')), findsOneWidget);
      expect(find.byKey(Key('subfolder-${grandchild.id}')), findsOneWidget);
      expect(find.byKey(const ValueKey('screenshot-tile-1')), findsNothing);
      expect(find.byKey(const ValueKey('screenshot-tile-2')), findsOneWidget);

      await tester.tap(find.byKey(Key('breadcrumb-${root.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('subfolder-${child.id}')), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
    },
  );

  testWidgets('breadcrumb suporta vários níveis e nomes longos sem overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final categories = FakeCategoryRepository();
    final root = await categories.createRootCategory('Referências extensas');
    final child = await categories.createSubcategory(
      parentId: root.id,
      name: 'Desenvolvimento profissional',
    );
    final grandchild = await categories.createSubcategory(
      parentId: child.id,
      name: 'Artigos favoritos',
    );

    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(Key('folder-${root.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('subfolder-${child.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('subfolder-${grandchild.id}')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(Key('breadcrumb-${root.id}')), findsOneWidget);
    expect(find.byKey(Key('breadcrumb-${child.id}')), findsOneWidget);
    expect(find.text('Artigos favoritos'), findsWidgets);
    expect(find.text('Nenhuma subpasta.'), findsOneWidget);
    expect(find.text('Nenhum print nesta pasta.'), findsOneWidget);
  });

  testWidgets('gerenciamento identifica nomes iguais por caminho completo', (
    tester,
  ) async {
    final categories = FakeCategoryRepository();
    final books = await categories.createRootCategory('Livros');
    final studies = await categories.createRootCategory('Estudos');
    await categories.createSubcategory(parentId: books.id, name: 'Trechos');
    await categories.createSubcategory(parentId: studies.id, name: 'Trechos');

    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();

    expect(find.text('Livros/Trechos'), findsOneWidget);
    expect(find.text('Estudos/Trechos'), findsOneWidget);
    expect(find.text('Nova pasta'), findsOneWidget);
  });

  testWidgets('CategoriesPage cria subpasta escolhendo pasta-mãe', (
    tester,
  ) async {
    final categories = FakeCategoryRepository();
    final books = await categories.createRootCategory('Livros');
    await categories.createRootCategory('Carreira');
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-category-button')));
    await tester.pumpAndSettle();

    expect(find.text('Local: Raiz'), findsOneWidget);
    await tester.tap(find.byKey(const Key('choose-folder-parent')));
    await tester.pumpAndSettle();
    final destinationList = find.byKey(const Key('folder-destination-list'));
    expect(find.byKey(const Key('destination-root')), findsOneWidget);
    expect(
      find.descendant(of: destinationList, matching: find.text('Carreira')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: destinationList, matching: find.text('Livros')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.descendant(
              of: destinationList,
              matching: find.text('Carreira'),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(
                of: destinationList,
                matching: find.text('Livros'),
              ),
            )
            .dy,
      ),
    );
    await tester.tap(find.byKey(Key('destination-${books.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Local: Livros'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      ' Trechos ',
    );
    await tester.tap(find.byKey(const Key('save-category-button')));
    await tester.pumpAndSettle();

    final child = (await categories.loadChildCategories(books.id)).single;
    expect(child.name, 'Trechos');
    expect(find.text('Livros/Trechos'), findsOneWidget);
  });

  testWidgets('CategoryDetailPage cria subpasta e atualiza imediatamente', (
    tester,
  ) async {
    final categories = FakeCategoryRepository();
    final books = await categories.createRootCategory('Livros');
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(Key('folder-${books.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ações da pasta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova subpasta'));
    await tester.pumpAndSettle();

    expect(find.text('Criar subpasta em Livros'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'Capas',
    );
    await tester.tap(find.byKey(const Key('save-category-button')));
    await tester.pumpAndSettle();

    final child = (await categories.loadChildCategories(books.id)).single;
    expect(find.byKey(Key('subfolder-${child.id}')), findsOneWidget);
    expect(find.text('Capas'), findsOneWidget);

    await tester.tap(find.byTooltip('Ações da pasta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova subpasta'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      ' capas ',
    );
    await tester.tap(find.byKey(const Key('save-category-button')));
    await tester.pump();
    expect(find.text('Já existe uma pasta com esse nome.'), findsOneWidget);
  });

  testWidgets('mesmo nome pode ser criado em mães diferentes pela interface', (
    tester,
  ) async {
    final categories = FakeCategoryRepository();
    final books = await categories.createRootCategory('Livros');
    final studies = await categories.createRootCategory('Estudos');
    await categories.createSubcategory(parentId: books.id, name: 'Trechos');
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();

    final studiesTile = find.byKey(ValueKey('category-tile-${studies.id}'));
    await tester.tap(
      find.descendant(
        of: studiesTile,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova subpasta'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'trechos',
    );
    await tester.tap(find.byKey(const Key('save-category-button')));
    await tester.pumpAndSettle();

    expect(find.text('Livros/Trechos'), findsOneWidget);
    expect(find.text('Estudos/trechos'), findsOneWidget);
  });

  testWidgets('seletor de movimento indica atual e bloqueia ciclo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final categories = FakeCategoryRepository();
    final root = await categories.createRootCategory(
      'Pasta raiz com nome bastante comprido',
    );
    final child = await categories.createSubcategory(
      parentId: root.id,
      name: 'Filha',
    );
    final grandchild = await categories.createSubcategory(
      parentId: child.id,
      name: 'Neta',
    );
    await categories.createRootCategory('Destino');
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();

    final rootTile = find.byKey(ValueKey('category-tile-${root.id}'));
    await tester.tap(
      find.descendant(
        of: rootTile,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover'));
    await tester.pumpAndSettle();
    final confirm = tester.widget<FilledButton>(
      find.byKey(const Key('confirm-category-move')),
    );
    expect(confirm.onPressed, isNull);
    expect(find.textContaining('(atual)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('choose-move-destination')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<ListTile>(
            find.descendant(
              of: find.byKey(Key('destination-${root.id}')),
              matching: find.byType(ListTile),
            ),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<ListTile>(
            find.descendant(
              of: find.byKey(Key('destination-${child.id}')),
              matching: find.byType(ListTile),
            ),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<ListTile>(
            find.descendant(
              of: find.byKey(Key('destination-${grandchild.id}')),
              matching: find.byType(ListTile),
            ),
          )
          .enabled,
      isFalse,
    );
    expect(find.text('Destino atual'), findsOneWidget);
    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(categories.moveCallCount, 0);
  });

  testWidgets('move raiz com subárvore e atualiza breadcrumb e Home', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'mover-pasta.png');
    final item = createMediaItem(1, image.path);
    final media = FakeMediaItemRepository(initialItems: [item]);
    final categories = FakeCategoryRepository();
    final books = await categories.createRootCategory('Livros');
    final excerpts = await categories.createSubcategory(
      parentId: books.id,
      name: 'Trechos',
    );
    final studies = await categories.createRootCategory('Estudos');
    await categories.replaceForMedia(1, {books.id});
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: media,
        categoryRepository: categories,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(Key('folder-${books.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ações da pasta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose-move-destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('destination-${studies.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-category-move')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('breadcrumb-${studies.id}')), findsOneWidget);
    expect((await categories.findCategoryById(books.id))?.parentId, studies.id);
    expect(
      (await categories.findCategoryById(excerpts.id))?.parentId,
      books.id,
    );
    expect((await categories.loadForMedia(1)).single.id, books.id);
    await tester.tap(find.byKey(const Key('breadcrumb-folders')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('folder-${books.id}')), findsNothing);
    expect(find.byKey(Key('folder-${studies.id}')), findsOneWidget);
  });

  testWidgets('move subpasta para outra mãe e depois para raiz', (
    tester,
  ) async {
    final categories = FakeCategoryRepository();
    final books = await categories.createRootCategory('Livros');
    final studies = await categories.createRootCategory('Estudos');
    final child = await categories.createSubcategory(
      parentId: books.id,
      name: 'Trechos',
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();

    await _moveCategoryFromManagement(tester, child.id, studies.id);
    expect(find.text('Estudos/Trechos'), findsOneWidget);
    final moved = await categories.findCategoryById(child.id);
    expect(moved?.id, child.id);
    expect(moved?.parentId, studies.id);

    await _moveCategoryFromManagement(tester, child.id, null);
    expect((await categories.findCategoryById(child.id))?.parentId, isNull);
    expect(find.text('Trechos'), findsOneWidget);
  });

  testWidgets('conflito e erro ao mover mantêm o dialog aberto', (
    tester,
  ) async {
    final categories = ControlledCategoryRepository();
    final books = await categories.createRootCategory('Livros');
    final studies = await categories.createRootCategory('Estudos');
    final child = await categories.createSubcategory(
      parentId: books.id,
      name: 'Trechos',
    );
    await categories.createSubcategory(parentId: studies.id, name: 'trechos');
    categories.createOperationCalls = 0;
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();
    await _openMoveDialog(tester, child.id);
    await _selectMoveDestination(tester, studies.id);
    await tester.tap(find.byKey(const Key('confirm-category-move')));
    await tester.pump();
    expect(
      find.text('Já existe uma pasta com esse nome no destino escolhido.'),
      findsOneWidget,
    );
    expect((await categories.findCategoryById(child.id))?.parentId, books.id);

    categories.failMove = true;
    await tester.tap(find.byKey(const Key('choose-move-destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('destination-root')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-category-move')));
    await tester.pump();
    expect(find.text('Não foi possível mover a pasta.'), findsOneWidget);

    categories.failMove = false;
    categories.moveFailure = const CategoryHierarchyException(
      CategoryHierarchyError.selfParent,
    );
    await tester.tap(find.byKey(const Key('confirm-category-move')));
    await tester.pump();
    expect(
      find.text('Uma pasta não pode ser movida para dentro dela mesma.'),
      findsOneWidget,
    );

    categories.moveFailure = const CategoryHierarchyException(
      CategoryHierarchyError.cycle,
    );
    await tester.tap(find.byKey(const Key('confirm-category-move')));
    await tester.pump();
    expect(
      find.text('Uma pasta não pode ser movida para uma de suas subpastas.'),
      findsOneWidget,
    );
  });

  testWidgets('criação e movimento pendentes impedem envios repetidos', (
    tester,
  ) async {
    final categories = ControlledCategoryRepository();
    final root = await categories.createRootCategory('Livros');
    final destination = await categories.createRootCategory('Estudos');
    categories.createOperationCalls = 0;
    categories.createBlocker = Completer<void>();
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-category-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'Projetos',
    );
    await tester.tap(find.byKey(const Key('save-category-button')));
    await tester.tap(find.byKey(const Key('save-category-button')));
    await tester.pump();
    expect(categories.createOperationCalls, 1);
    categories.createBlocker!.complete();
    await tester.pumpAndSettle();

    categories.moveBlocker = Completer<void>();
    await _openMoveDialog(tester, root.id);
    await _selectMoveDestination(tester, destination.id);
    await tester.tap(find.byKey(const Key('confirm-category-move')));
    await tester.tap(find.byKey(const Key('confirm-category-move')));
    await tester.pump();
    expect(categories.moveOperationCalls, 1);
    categories.moveBlocker!.complete();
    await tester.pumpAndSettle();
    expect(
      (await categories.findCategoryById(root.id))?.parentId,
      destination.id,
    );
  });

  testWidgets('erro ao criar não fecha dialog e permite corrigir', (
    tester,
  ) async {
    final categories = ControlledCategoryRepository()..failCreate = true;
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-category-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'Projetos',
    );
    await tester.tap(find.byKey(const Key('save-category-button')));
    await tester.pump();

    expect(find.text('Não foi possível criar a pasta.'), findsOneWidget);
    expect(find.byKey(const Key('save-category-button')), findsOneWidget);
  });

  testWidgets('detalhe distingue pasta inexistente de falha de carregamento', (
    tester,
  ) async {
    final missing = Category(
      id: 99,
      name: 'Ausente',
      normalizedName: 'ausente',
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(
      buildCategoryDetailTestApp(
        summary: CategorySummary(category: missing, mediaCount: 0),
        categories: FakeCategoryRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pasta não encontrada.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final failing = FailingCategoryRepository(failFind: true);
    final root = await failing.createRootCategory('Livros');
    await tester.pumpWidget(
      buildCategoryDetailTestApp(
        summary: CategorySummary(category: root, mediaCount: 0),
        categories: failing,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar a pasta.'), findsOneWidget);
  });

  testWidgets('detalhe mantém seções independentes quando uma consulta falha', (
    tester,
  ) async {
    final childFailure = FailingCategoryRepository(failChildren: true);
    final first = await childFailure.createRootCategory('Livros');
    await tester.pumpWidget(
      buildCategoryDetailTestApp(
        summary: CategorySummary(category: first, mediaCount: 0),
        categories: childFailure,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar as subpastas.'),
      findsOneWidget,
    );
    expect(find.text('Nenhum print nesta pasta.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final mediaFailure = FailingCategoryRepository(failMedia: true);
    final second = await mediaFailure.createRootCategory('Estudos');
    await tester.pumpWidget(
      buildCategoryDetailTestApp(
        summary: CategorySummary(category: second, mediaCount: 0),
        categories: mediaFailure,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma subpasta.'), findsOneWidget);
    expect(
      find.text('Não foi possível carregar os prints desta pasta.'),
      findsOneWidget,
    );
  });

  testWidgets('menu compacto abre gerenciamento de etiquetas', (tester) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pump();

    expect(find.text('Etiquetas'), findsNothing);
    await tester.tap(find.byKey(const Key('home-actions-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gerenciar etiquetas'));
    await tester.pumpAndSettle();

    expect(find.text('Etiquetas'), findsOneWidget);
    expect(find.text('Nenhuma etiqueta criada.'), findsOneWidget);
    expect(find.byKey(const Key('new-tag-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('new-tag-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-tag-name-field')),
      'Favorita',
    );
    await tester.tap(find.byKey(const Key('save-new-tag-button')));
    await tester.pumpAndSettle();
    expect(find.text('Favorita'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Etiquetas'), findsNothing);
  });

  testWidgets(
    'seletor lista etiquetas ordenadas, quantidades e permite cancelar',
    (tester) async {
      final tags = FakeTagRepository();
      final zeta = await tags.createTag('Zeta');
      await tags.createTag('Ação');
      tags.seedAssociation(tagId: zeta.id, mediaItemId: 1);
      tags.seedAssociation(tagId: zeta.id, mediaItemId: 2);

      await tester.pumpWidget(
        buildTestApp(FakeScreenshotPicker(), tagRepository: tags),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open-tag-filter')));
      await tester.pumpAndSettle();

      expect(find.text('Todas as etiquetas'), findsOneWidget);
      expect(find.text('Nenhum screenshot'), findsOneWidget);
      expect(find.text('2 screenshots'), findsOneWidget);
      final actionTop = tester.getTopLeft(find.text('Ação')).dy;
      final zetaTop = tester.getTopLeft(find.text('Zeta')).dy;
      expect(actionTop, lessThan(zetaTop));

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('active-tag-filter-chip')), findsNothing);
    },
  );

  testWidgets('seleciona etiqueta, filtra imediatamente e permite limpar', (
    tester,
  ) async {
    final firstFile = createTestImage(temporaryDirectory, 'filtro-a.png');
    final secondFile = createTestImage(temporaryDirectory, 'filtro-b.png');
    final repository = FakeMediaItemRepository(
      initialItems: [
        createMediaItem(1, firstFile.path, importedAt: DateTime(2026, 1)),
        createMediaItem(2, secondFile.path, importedAt: DateTime(2026, 2)),
      ],
    );
    final tags = FakeTagRepository();
    final selected = await tags.createTag('Importante');
    tags.seedAssociation(tagId: selected.id, mediaItemId: 1);

    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        tagRepository: tags,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-tag-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('tag-filter-option-${selected.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Etiqueta: Importante'), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-2')), findsNothing);

    await tester.tap(find.byTooltip('Limpar filtro'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('active-tag-filter-chip')), findsNothing);
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-2')), findsOneWidget);
  });

  testWidgets('pasta Todos restaura a biblioteca geral', (tester) async {
    final firstFile = createTestImage(temporaryDirectory, 'todos-a.png');
    final secondFile = createTestImage(temporaryDirectory, 'todos-b.png');
    final repository = FakeMediaItemRepository(
      initialItems: [
        createMediaItem(1, firstFile.path),
        createMediaItem(2, secondFile.path),
      ],
    );
    final tags = FakeTagRepository();
    final selected = await tags.createTag('Somente um');
    tags.seedAssociation(tagId: selected.id, mediaItemId: 1);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        tagRepository: tags,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-tag-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('tag-filter-option-${selected.id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('screenshot-tile-2')), findsNothing);
    await tester.tap(find.byKey(const Key('all-folder')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('active-tag-filter-chip')), findsNothing);
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-2')), findsOneWidget);
  });

  testWidgets('pesquisa textual e etiqueta usam lógica AND', (tester) async {
    final firstFile = createTestImage(temporaryDirectory, 'and-a.png');
    final secondFile = createTestImage(temporaryDirectory, 'and-b.png');
    final thirdFile = createTestImage(temporaryDirectory, 'and-c.png');
    final repository = FakeMediaItemRepository(
      initialItems: [
        createMediaItem(1, firstFile.path),
        createMediaItem(2, secondFile.path),
        createMediaItem(3, thirdFile.path),
      ],
      recognizedTexts: const {
        1: 'projeto importante',
        2: 'projeto sem etiqueta',
        3: 'outro conteúdo',
      },
    );
    final tags = FakeTagRepository();
    final selected = await tags.createTag('Trabalho');
    tags.seedAssociation(tagId: selected.id, mediaItemId: 1);
    tags.seedAssociation(tagId: selected.id, mediaItemId: 3);

    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        tagRepository: tags,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-tag-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('tag-filter-option-${selected.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'projeto');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();

    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-2')), findsNothing);
    expect(find.byKey(const ValueKey('screenshot-tile-3')), findsNothing);
  });

  testWidgets('consulta antiga não sobrescreve filtro mais recente', (
    tester,
  ) async {
    final firstFile = createTestImage(temporaryDirectory, 'concorrente-a.png');
    final secondFile = createTestImage(temporaryDirectory, 'concorrente-b.png');
    final oldSearch = Completer<List<ScreenshotSearchResult>>();
    final first = createMediaItem(1, firstFile.path);
    final second = createMediaItem(2, secondFile.path);
    final repository = FakeMediaItemRepository(
      initialItems: [first, second],
      recognizedTexts: const {1: 'projeto filtrado', 2: 'projeto antigo'},
      searchCompleters: {'all:projeto': oldSearch},
    );
    final tags = FakeTagRepository();
    final selected = await tags.createTag('Atual');
    tags.seedAssociation(tagId: selected.id, mediaItemId: 1);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        tagRepository: tags,
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'projeto');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.tap(find.byKey(const Key('open-tag-filter')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(Key('tag-filter-option-${selected.id}')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);

    oldSearch.complete([
      ScreenshotSearchResult(mediaItem: second, snippet: 'projeto antigo'),
    ]);
    await tester.pump();
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-2')), findsNothing);
  });

  testWidgets('descarte durante consulta filtrada não atualiza Home fechada', (
    tester,
  ) async {
    final file = createTestImage(temporaryDirectory, 'dispose-filtro.png');
    final pending = Completer<List<ScreenshotSearchResult>>();
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, file.path)],
      recognizedTexts: const {1: 'consulta pendente'},
      searchCompleters: {'1:consulta': pending},
    );
    final tags = FakeTagRepository();
    final selected = await tags.createTag('Pendente');
    tags.seedAssociation(tagId: selected.id, mediaItemId: 1);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        tagRepository: tags,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-tag-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('tag-filter-option-${selected.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'consulta');
    await tester.pump(const Duration(milliseconds: 301));

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(const []);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('filtro sem resultados mostra mensagem e ação para limpar', (
    tester,
  ) async {
    final tags = FakeTagRepository();
    final selected = await tags.createTag('Vazia');
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), tagRepository: tags),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-tag-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('tag-filter-option-${selected.id}')));
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum print encontrado com esta etiqueta.'),
      findsOneWidget,
    );
    expect(find.text('Limpar filtro'), findsOneWidget);
  });

  testWidgets('erros ao listar etiquetas e carregar filtro permitem repetir', (
    tester,
  ) async {
    final failingTags = FakeTagRepository(failLoadSummaries: true);
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), tagRepository: failingTags),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-tag-filter')));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar as etiquetas.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    final tags = FakeTagRepository();
    final selected = await tags.createTag('Falha');
    final repository = FakeMediaItemRepository(failFilteredLoad: true);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        tagRepository: tags,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-tag-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('tag-filter-option-${selected.id}')));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar os screenshots.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets(
    'etiqueta selecionada excluída é limpa ao voltar do gerenciamento',
    (tester) async {
      final file = createTestImage(temporaryDirectory, 'tag-excluida.png');
      final repository = FakeMediaItemRepository(
        initialItems: [createMediaItem(1, file.path)],
      );
      final tags = FakeTagRepository();
      final selected = await tags.createTag('Descartável');
      tags.seedAssociation(tagId: selected.id, mediaItemId: 1);
      await tester.pumpWidget(
        buildTestApp(
          FakeScreenshotPicker(),
          repository: repository,
          tagRepository: tags,
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open-tag-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('tag-filter-option-${selected.id}')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home-actions-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gerenciar etiquetas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ações da etiqueta Descartável'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir etiqueta'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-tag-deletion')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('active-tag-filter-chip')), findsNothing);
      expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
    },
  );

  testWidgets('voltar dos detalhes atualiza associação do filtro ativo', (
    tester,
  ) async {
    final file = createTestImage(temporaryDirectory, 'tag-detalhe.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, file.path)],
    );
    final tags = FakeTagRepository();
    final selected = await tags.createTag('Revisar');
    tags.seedAssociation(tagId: selected.id, mediaItemId: 1);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        tagRepository: tags,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-tag-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('tag-filter-option-${selected.id}')));
    await tester.pumpAndSettle();
    await openFirstScreenshot(tester);
    await tester.ensureVisible(find.byTooltip('Remover etiqueta Revisar'));
    await tester.tap(find.byTooltip('Remover etiqueta Revisar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum print encontrado com esta etiqueta.'),
      findsOneWidget,
    );
  });

  testWidgets('criar categoria atualiza lista e contador da Home', (
    tester,
  ) async {
    final categories = FakeCategoryRepository();
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-category-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'Trabalho',
    );
    await tester.tap(find.byKey(const Key('save-category-button')));
    await tester.pumpAndSettle();

    expect(find.text('Trabalho'), findsOneWidget);
    expect(find.text('0 prints'), findsOneWidget);
    expect((await categories.loadRootCategories()).single.name, 'Trabalho');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('folder-1')), findsOneWidget);
  });

  testWidgets('nome duplicado e nome em branco mostram erros legíveis', (
    tester,
  ) async {
    final categories = FakeCategoryRepository();
    await categories.createCategory('Carrêira');
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-category-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' carreira ');
    await tester.tap(find.byKey(const Key('save-category-button')));
    await tester.pump();
    expect(find.text('Já existe uma pasta com esse nome.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byKey(const Key('save-category-button')));
    await tester.pump();
    expect(find.text('Digite um nome para a pasta.'), findsOneWidget);
  });

  testWidgets('detalhes associam múltiplas categorias e permitem desmarcar', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'categorias.png');
    final media = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final categories = FakeCategoryRepository();
    final first = await categories.createCategory('Trabalho');
    final second = await categories.createCategory('Estudos');
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: media,
        categoryRepository: categories,
      ),
    );
    await tester.pump();
    await openFirstScreenshot(tester);
    expect(find.text('Nenhuma categoria atribuída.'), findsOneWidget);
    expect(find.text('Alterar organização'), findsOneWidget);
    expect(find.text('Aceitar sugestão'), findsNothing);
    expect(find.text('Rejeitar sugestão'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('edit-categories-button')));
    await tester.tap(find.byKey(const Key('edit-categories-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('category-checkbox-${first.id}')));
    await tester.tap(find.byKey(ValueKey('category-checkbox-${second.id}')));
    await tester.tap(find.byKey(const Key('save-category-selection')));
    await tester.pumpAndSettle();

    expect(find.text('Trabalho'), findsOneWidget);
    expect(find.text('Estudos'), findsOneWidget);
    await tester.tap(find.byKey(const Key('edit-categories-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('category-checkbox-${first.id}')));
    await tester.tap(find.byKey(const Key('save-category-selection')));
    await tester.pumpAndSettle();
    expect(find.text('Trabalho'), findsNothing);
    expect(find.text('Estudos'), findsOneWidget);
    expect(media.itemCount, 1);
  });

  testWidgets('categorias e nomes longos não causam overflow em 320 pixels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final categories = FakeCategoryRepository();
    await categories.createCategory('Categoria com um nome bastante comprido');
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Categoria com um nome bastante comprido'),
      findsOneWidget,
    );
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Nenhum print nesta pasta.'), findsOneWidget);
  });

  testWidgets('tocar em categoria mostra somente screenshots associados', (
    tester,
  ) async {
    final first = createTestImage(temporaryDirectory, 'associado.png');
    final second = createTestImage(temporaryDirectory, 'fora.png');
    final media = FakeMediaItemRepository(
      initialItems: [
        createMediaItem(1, first.path, importedAt: DateTime(2025)),
        createMediaItem(2, second.path, importedAt: DateTime(2026)),
      ],
    );
    final categories = FakeCategoryRepository();
    final category = await categories.createCategory('Trabalho');
    await categories.replaceForMedia(1, {category.id});
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: media,
        categoryRepository: categories,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('category-tile-${category.id}')));
    await tester.pumpAndSettle();

    expect(find.text('1 print'), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-2')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('screenshot-tile-1')));
    await tester.tap(find.byKey(const ValueKey('screenshot-tile-1')));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes do screenshot'), findsOneWidget);
  });

  testWidgets('categoria vazia apresenta estado correto', (tester) async {
    final categories = FakeCategoryRepository();
    final category = await categories.createCategory('Vazia');
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('category-tile-${category.id}')));
    await tester.pumpAndSettle();

    expect(find.text('0 prints'), findsOneWidget);
    expect(find.text('Nenhum print nesta pasta.'), findsOneWidget);
  });

  testWidgets('voltar dos detalhes atualiza associações da categoria', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'alterar-categoria.png');
    final media = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final categories = FakeCategoryRepository();
    final category = await categories.createCategory('Revisar');
    await categories.replaceForMedia(1, {category.id});
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: media,
        categoryRepository: categories,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('category-tile-${category.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('screenshot-tile-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('edit-categories-button')));
    await tester.tap(find.byKey(const Key('edit-categories-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('category-checkbox-${category.id}')));
    await tester.tap(find.byKey(const Key('save-category-selection')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Nenhum print nesta pasta.'), findsOneWidget);
  });

  testWidgets('voltar após remover screenshot atualiza tela da categoria', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'remover-filtrado.png');
    final media = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final categories = FakeCategoryRepository();
    final category = await categories.createCategory('Descartar');
    await categories.replaceForMedia(1, {category.id});
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: media,
        categoryRepository: categories,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('category-tile-${category.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('screenshot-tile-1')));
    await tester.pumpAndSettle();
    await tapRemoveFromMemoShot(tester);
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum print nesta pasta.'), findsOneWidget);
    expect(find.text('0 prints'), findsOneWidget);
  });

  testWidgets('renomear atualiza interface e conflito mostra erro', (
    tester,
  ) async {
    final categories = FakeCategoryRepository();
    final first = await categories.createCategory('Carreira');
    await categories.createCategory('Estudos');
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renomear'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('rename-category-field')),
      'estúdos',
    );
    await tester.tap(find.byKey(const Key('save-category-rename')));
    await tester.pump();
    expect(find.text('Já existe uma pasta com esse nome.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('rename-category-field')),
      'Projetos',
    );
    await tester.tap(find.byKey(const Key('save-category-rename')));
    await tester.pumpAndSettle();
    expect(find.text('Projetos'), findsOneWidget);
    expect(find.text(first.name), findsNothing);
  });

  testWidgets('renomear subpasta preserva hierarquia e atualiza caminho', (
    tester,
  ) async {
    final categories = FakeCategoryRepository();
    final root = await categories.createRootCategory('Livros');
    final child = await categories.createSubcategory(
      parentId: root.id,
      name: 'Trechos',
    );
    final otherRoot = await categories.createRootCategory('Estudos');
    await categories.createSubcategory(
      parentId: otherRoot.id,
      name: 'Citações',
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();

    final tile = find.byKey(ValueKey('category-tile-${child.id}'));
    await tester.tap(
      find.descendant(of: tile, matching: find.byType(PopupMenuButton<String>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renomear'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('rename-category-field')),
      'Citações',
    );
    await tester.tap(find.byKey(const Key('save-category-rename')));
    await tester.pumpAndSettle();

    expect(find.text('Livros/Citações'), findsOneWidget);
    expect((await categories.findCategoryById(child.id))?.parentId, root.id);
  });

  testWidgets(
    'excluir folha no detalhe retorna com segurança e preserva print',
    (tester) async {
      final image = createTestImage(temporaryDirectory, 'folha-excluida.png');
      final item = createMediaItem(1, image.path);
      final media = FakeMediaItemRepository(initialItems: [item]);
      final categories = FakeCategoryRepository();
      final leaf = await categories.createRootCategory('Temporária');
      await categories.replaceForMedia(item.id, {leaf.id});
      await tester.pumpWidget(
        buildTestApp(
          FakeScreenshotPicker(),
          repository: media,
          categoryRepository: categories,
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(Key('folder-${leaf.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ações da pasta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir pasta'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Os prints não serão excluídos.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirm-category-deletion')));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('folder-${leaf.id}')), findsNothing);
      expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
      expect(media.itemCount, 1);
      expect(image.existsSync(), isTrue);
    },
  );

  testWidgets('cancelar exclusão preserva categoria e screenshot', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'cancelar-exclusao.png');
    final media = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final categories = FakeCategoryRepository();
    final category = await categories.createCategory('Manter');
    await categories.replaceForMedia(1, {category.id});
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: media,
        categoryRepository: categories,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir pasta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Manter'), findsOneWidget);
    expect(media.itemCount, 1);
    expect(image.existsSync(), isTrue);
  });

  testWidgets('exclusão de pasta com filhas mostra mensagem específica', (
    tester,
  ) async {
    final categories = FakeCategoryRepository();
    final root = await categories.createRootCategory('Livros');
    await categories.createSubcategory(parentId: root.id, name: 'Trechos');
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), categoryRepository: categories),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();

    final tile = find.byKey(ValueKey('category-tile-${root.id}'));
    await tester.tap(
      find.descendant(of: tile, matching: find.byType(PopupMenuButton<String>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir pasta'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Os prints não serão excluídos.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirm-category-deletion')));
    await tester.pumpAndSettle();

    expect(
      find.text('Esta pasta possui subpastas e não pode ser excluída.'),
      findsOneWidget,
    );
    expect(await categories.findCategoryById(root.id), isNotNull);
  });

  testWidgets('confirmar exclusão preserva screenshot e atualiza Home', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'preservado.png');
    final media = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final categories = FakeCategoryRepository();
    final category = await categories.createCategory('Excluir');
    await categories.replaceForMedia(1, {category.id});
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: media,
        categoryRepository: categories,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir pasta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-category-deletion')));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma pasta criada.'), findsOneWidget);
    expect(media.itemCount, 1);
    expect(image.existsSync(), isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma pasta criada.'), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('screenshot-tile-1')));
    await tester.tap(find.byKey(const ValueKey('screenshot-tile-1')));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma categoria atribuída.'), findsOneWidget);
  });

  testWidgets('Home não exibe card explicativo de importação manual', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pump();

    expect(
      find.text('Você também pode enviar imagens pelo menu Compartilhar.'),
      findsNothing,
    );
    expect(find.text('Importar screenshots'), findsNothing);
    expect(find.byKey(const Key('add-print-button')), findsOneWidget);
  });

  testWidgets(
    'compartilhamento inicial atualiza Home e mostra feedback singular',
    (tester) async {
      final image = createTestImage(temporaryDirectory, 'inicial-shared.png');
      final source = FakeIncomingShareSource(
        initialMedia: [
          IncomingSharedMedia(
            path: image.path,
            type: IncomingMediaType.image,
            mimeType: 'image/png',
          ),
        ],
      );
      await tester.pumpWidget(
        buildTestApp(FakeScreenshotPicker(), incomingShareSource: source),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 item'), findsOneWidget);
      expect(find.text('Screenshot adicionado ao MemoShot.'), findsOneWidget);
      expect(source.resetCount, 1);
    },
  );

  testWidgets('compartilhamento aberto mostra feedback plural', (tester) async {
    final first = createTestImage(temporaryDirectory, 'shared-a.png');
    final second = createTestImage(temporaryDirectory, 'shared-b.png');
    final source = FakeIncomingShareSource();
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), incomingShareSource: source),
    );
    await tester.pump();

    source.emit([
      IncomingSharedMedia(path: first.path, type: IncomingMediaType.image),
      IncomingSharedMedia(path: second.path, type: IncomingMediaType.image),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('2 itens'), findsOneWidget);
    expect(find.text('2 screenshots adicionados ao MemoShot.'), findsOneWidget);
  });

  testWidgets('compartilhamento duplicado mostra feedback correto', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'shared-duplicada.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, image.path)],
    );
    final source = FakeIncomingShareSource();
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        incomingShareSource: source,
      ),
    );
    await tester.pump();
    source.emit([
      IncomingSharedMedia(path: image.path, type: IncomingMediaType.image),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Esta imagem já estava no MemoShot.'), findsOneWidget);
    expect(repository.itemCount, 1);
  });

  testWidgets('resultado parcial informa importada e duplicada', (
    tester,
  ) async {
    final existing = createTestImage(temporaryDirectory, 'shared-existe.png');
    final fresh = createTestImage(temporaryDirectory, 'shared-nova.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, existing.path)],
    );
    final source = FakeIncomingShareSource();
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        incomingShareSource: source,
      ),
    );
    await tester.pump();
    source.emit([
      IncomingSharedMedia(path: existing.path, type: IncomingMediaType.image),
      IncomingSharedMedia(path: fresh.path, type: IncomingMediaType.image),
    ]);
    await tester.pumpAndSettle();

    expect(
      find.text('1 imagem adicionada e 1 já estava no MemoShot.'),
      findsOneWidget,
    );
  });

  testWidgets('compartilhamento preserva pesquisa ativa', (tester) async {
    final existing = createTestImage(temporaryDirectory, 'busca-shared-a.png');
    final incoming = createTestImage(temporaryDirectory, 'busca-shared-b.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, existing.path)],
      recognizedTexts: const {1: 'Conteúdo pesquisável'},
    );
    final source = FakeIncomingShareSource();
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        incomingShareSource: source,
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'pesquisável');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    source.emit([
      IncomingSharedMedia(path: incoming.path, type: IncomingMediaType.image),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('1 resultado para “pesquisável”'), findsOneWidget);
    expect(repository.itemCount, 2);
  });

  testWidgets('detalhes distinguem origem picker e compartilhada', (
    tester,
  ) async {
    final pickerImage = createTestImage(temporaryDirectory, 'picker.png');
    final sharedImage = createTestImage(temporaryDirectory, 'shared.png');
    final repository = FakeMediaItemRepository(
      initialItems: [
        createMediaItem(1, pickerImage.path),
        createMediaItem(2, sharedImage.path, importOrigin: ImportOrigin.shared),
      ],
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const ValueKey('screenshot-tile-1')));
    await tester.tap(find.byKey(const ValueKey('screenshot-tile-1')));
    await tester.pumpAndSettle();
    expect(find.text('Selecionado no dispositivo'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('screenshot-tile-2')));
    await tester.tap(find.byKey(const ValueKey('screenshot-tile-2')));
    await tester.pumpAndSettle();
    expect(find.text('Compartilhado com o MemoShot'), findsOneWidget);
  });

  testWidgets('primeira execução apresenta e conclui onboarding', (
    tester,
  ) async {
    final onboarding = FakeOnboardingRepository();
    final source = FakeAutomaticScreenshotSource();
    final settings = FakeAutomaticImportSettingsRepository(
      hasStoredPreference: false,
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        onboardingRepository: onboarding,
        automaticScreenshotSource: source,
        automaticSettingsRepository: settings,
      ),
    );
    await tester.pump();

    expect(find.text('Capturou, organizou.'), findsOneWidget);
    expect(
      find.text(
        'O MemoShot ajuda a encontrar e organizar seus prints automaticamente.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    expect(find.text('Tudo no seu dispositivo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    expect(find.text('Permita o acesso aos seus prints'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-allow')));
    await tester.pumpAndSettle();

    expect(onboarding.completed, isTrue);
    expect(onboarding.completeCalls, 1);
    expect(source.requestCount, 1);
    expect(settings.enabled, isTrue);
    expect(find.text('Últimos prints'), findsOneWidget);
  });

  testWidgets('onboarding concluído não reaparece', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        onboardingRepository: FakeOnboardingRepository(completed: true),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('onboarding-next')), findsNothing);
    expect(find.text('Últimos prints'), findsOneWidget);
  });

  testWidgets('Agora não conclui sem pedir permissão e sem loop', (
    tester,
  ) async {
    final onboarding = FakeOnboardingRepository();
    final source = FakeAutomaticScreenshotSource(
      permission: MediaPermissionStatus.notRequested,
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        onboardingRepository: onboarding,
        automaticScreenshotSource: source,
        automaticSettingsRepository: FakeAutomaticImportSettingsRepository(
          hasStoredPreference: false,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-not-now')));
    await tester.pumpAndSettle();

    expect(source.requestCount, 0);
    expect(onboarding.completed, isTrue);
    expect(find.text('Últimos prints'), findsOneWidget);

    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), onboardingRepository: onboarding),
    );
    await tester.pump();
    expect(find.byKey(const Key('onboarding-next')), findsNothing);
  });

  testWidgets('permissão negada conclui onboarding e mostra aviso na Home', (
    tester,
  ) async {
    final source = FakeAutomaticScreenshotSource(
      permission: MediaPermissionStatus.denied,
    );
    final settings = FakeAutomaticImportSettingsRepository(
      hasStoredPreference: false,
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        onboardingRepository: FakeOnboardingRepository(),
        automaticScreenshotSource: source,
        automaticSettingsRepository: settings,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-allow')));
    await tester.pumpAndSettle();

    expect(settings.enabled, isFalse);
    expect(find.byKey(const Key('automatic-import-notice')), findsOneWidget);
    expect(find.text('Últimos prints'), findsOneWidget);
  });

  testWidgets('descarte durante solicitação do onboarding é seguro', (
    tester,
  ) async {
    final blocker = Completer<MediaPermissionStatus>();
    final source = FakeAutomaticScreenshotSource(
      permissionRequestCompleter: blocker,
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        onboardingRepository: FakeOnboardingRepository(),
        automaticScreenshotSource: source,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-allow')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    blocker.complete(MediaPermissionStatus.fullAccess);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Home abre Configurações com privacidade e sobre', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Captura e organização automática'), findsOneWidget);
    expect(find.text('Acervo existente'), findsOneWidget);
    expect(find.text('Organizar screenshots antigos'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Privacidade'), 200);
    expect(find.text('Privacidade'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sobre o MemoShot'), 250);
    expect(find.text('Sobre o MemoShot'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Capturou, organizou.'), 120);
    expect(find.text('Capturou, organizou.'), findsOneWidget);
    expect(
      find.textContaining('não são enviados para servidores'),
      findsOneWidget,
    );
  });

  testWidgets('Configurações abre acervo sem iniciar mapeamento', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-existing-screenshot-inventory')),
      180,
    );
    await tester.tap(
      find.byKey(const Key('open-existing-screenshot-inventory')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acervo existente'), findsOneWidget);
    expect(find.text('Mapear meus screenshots'), findsOneWidget);
    expect(find.byKey(const Key('inventory-scan-progress')), findsNothing);
  });

  testWidgets('switch desliga, salva e permanece somente em Configurações', (
    tester,
  ) async {
    final settings = FakeAutomaticImportSettingsRepository(enabled: true);
    final source = FakeAutomaticScreenshotSource();
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        automaticScreenshotSource: source,
        automaticSettingsRepository: settings,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('automatic-import-switch')), findsNothing);
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    final switchTile = tester.widget<SwitchListTile>(
      find.byKey(const Key('automatic-import-switch')),
    );
    switchTile.onChanged!(false);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();

    expect(settings.enabled, isFalse);
    expect(settings.disableCalls, 1);
    expect(find.byKey(const Key('settings-progress')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('automatic-import-switch')), findsNothing);
    expect(find.text('Processamento local'), findsNothing);
  });

  testWidgets('reativar sem permissão solicita acesso e restaura switch', (
    tester,
  ) async {
    final settings = FakeAutomaticImportSettingsRepository(enabled: false);
    final source = FakeAutomaticScreenshotSource(
      permission: MediaPermissionStatus.denied,
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        automaticScreenshotSource: source,
        automaticSettingsRepository: settings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('automatic-import-switch')));
    await tester.pumpAndSettle();

    expect(source.requestCount, 1);
    expect(settings.enabled, isFalse);
    expect(
      find.text('Permita o acesso às imagens para ativar esta função.'),
      findsOneWidget,
    );
  });

  testWidgets('reativar com acesso salva preferência e configura uma vez', (
    tester,
  ) async {
    final settings = FakeAutomaticImportSettingsRepository(enabled: false);
    final source = FakeAutomaticScreenshotSource(maxMediaId: 12);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        automaticScreenshotSource: source,
        automaticSettingsRepository: settings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('automatic-import-switch')),
    );
    tile.onChanged!(true);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();

    expect(settings.enabled, isTrue);
    expect(settings.marker, 12);
    expect(settings.enableCalls, 1);
    expect(source.requestCount, 1);
    expect(source.backgroundConfigurationCount, 2);
  });

  testWidgets('erro ao ativar restaura switch e mostra mensagem', (
    tester,
  ) async {
    final settings = FakeAutomaticImportSettingsRepository(failEnable: true);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        automaticSettingsRepository: settings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    tester
        .widget<SwitchListTile>(
          find.byKey(const Key('automatic-import-switch')),
        )
        .onChanged!(true);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();

    expect(settings.enabled, isFalse);
    expect(
      find.text('Não foi possível ativar a organização automática.'),
      findsOneWidget,
    );
  });

  testWidgets('erro ao desativar restaura switch e mostra mensagem', (
    tester,
  ) async {
    final settings = FakeAutomaticImportSettingsRepository(
      enabled: true,
      failDisable: true,
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        automaticSettingsRepository: settings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    tester
        .widget<SwitchListTile>(
          find.byKey(const Key('automatic-import-switch')),
        )
        .onChanged!(false);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();

    expect(settings.enabled, isTrue);
    expect(
      find.text('Não foi possível atualizar a configuração.'),
      findsOneWidget,
    );
  });

  testWidgets('ativação pendente impede solicitações repetidas', (
    tester,
  ) async {
    final permission = Completer<MediaPermissionStatus>();
    final source = FakeAutomaticScreenshotSource(
      permissionRequestCompleter: permission,
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), automaticScreenshotSource: source),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    final callback = tester
        .widget<SwitchListTile>(
          find.byKey(const Key('automatic-import-switch')),
        )
        .onChanged!;
    callback(true);
    callback(true);
    await tester.pump();

    expect(source.requestCount, 1);
    expect(find.byKey(const Key('settings-progress')), findsOneWidget);
    permission.complete(MediaPermissionStatus.fullAccess);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    expect(source.requestCount, 1);
  });

  testWidgets('negação permanente abre configurações do Android', (
    tester,
  ) async {
    final source = FakeAutomaticScreenshotSource(
      permission: MediaPermissionStatus.permanentlyDenied,
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), automaticScreenshotSource: source),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Abrir configurações do Android'), findsOneWidget);
    await tester.tap(find.byKey(const Key('permission-action')));
    await tester.pump();
    expect(source.openSettingsCount, 1);
    expect(source.requestCount, 0);
  });

  testWidgets('retorno das configurações Android atualiza permissão e Home', (
    tester,
  ) async {
    final source = FakeAutomaticScreenshotSource(
      permission: MediaPermissionStatus.permanentlyDenied,
    );
    final settings = FakeAutomaticImportSettingsRepository(enabled: true);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        automaticScreenshotSource: source,
        automaticSettingsRepository: settings,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('automatic-import-notice')), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Acesso não permitido'), findsOneWidget);

    source.permission = MediaPermissionStatus.fullAccess;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();

    expect(find.text('Acesso permitido'), findsOneWidget);
    expect(source.startCount, 1);
    await tester.pageBack();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('automatic-import-notice')), findsNothing);
  });

  testWidgets('Configurações apresenta estados amigáveis de permissão', (
    tester,
  ) async {
    for (final entry in <(MediaPermissionStatus, String)>[
      (MediaPermissionStatus.fullAccess, 'Acesso permitido'),
      (MediaPermissionStatus.limitedAccess, 'Acesso parcial'),
      (MediaPermissionStatus.denied, 'Acesso não permitido'),
      (MediaPermissionStatus.unsupported, 'Indisponível neste dispositivo'),
    ]) {
      await tester.pumpWidget(
        buildTestApp(
          FakeScreenshotPicker(),
          automaticScreenshotSource: FakeAutomaticScreenshotSource(
            permission: entry.$1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
    }
  });

  testWidgets('automação começa desativada e não solicita permissão', (
    tester,
  ) async {
    final source = FakeAutomaticScreenshotSource();
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), automaticScreenshotSource: source),
    );
    await tester.pump();

    expect(find.text('Importação automática'), findsNothing);
    expect(find.byKey(const Key('automatic-import-switch')), findsNothing);
    expect(find.byKey(const Key('automatic-import-notice')), findsNothing);
    expect(source.requestCount, 0);
  });

  testWidgets('automação armazenada continua ativa sem controle na Home', (
    tester,
  ) async {
    final source = FakeAutomaticScreenshotSource();
    final settings = FakeAutomaticImportSettingsRepository(enabled: true);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        automaticScreenshotSource: source,
        automaticSettingsRepository: settings,
      ),
    );
    await tester.pumpAndSettle();

    expect(source.requestCount, 0);
    expect(source.startCount, 1);
    expect(settings.enabled, isTrue);
    expect(find.byKey(const Key('automatic-import-notice')), findsNothing);
  });

  testWidgets('falta de permissão mostra aviso contextual compacto', (
    tester,
  ) async {
    final source = FakeAutomaticScreenshotSource(
      permission: MediaPermissionStatus.denied,
    );
    final settings = FakeAutomaticImportSettingsRepository(enabled: true);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        automaticScreenshotSource: source,
        automaticSettingsRepository: settings,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('automatic-import-notice')), findsOneWidget);
    expect(
      find.text('Permita o acesso às imagens para organizar novos prints.'),
      findsOneWidget,
    );
    expect(find.text('Conceder acesso'), findsOneWidget);
    expect(source.requestCount, 0);
  });

  testWidgets('acesso limitado mostra aviso contextual e ação clara', (
    tester,
  ) async {
    final source = FakeAutomaticScreenshotSource(
      permission: MediaPermissionStatus.limitedAccess,
    );
    final settings = FakeAutomaticImportSettingsRepository(enabled: true);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        automaticScreenshotSource: source,
        automaticSettingsRepository: settings,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'O acesso parcial às imagens impede a organização de novos prints.',
      ),
      findsOneWidget,
    );
    expect(find.text('Revisar acesso'), findsOneWidget);
    expect(source.startCount, 0);
  });

  testWidgets('Android sem suporte mostra falha contextual sem detalhes', (
    tester,
  ) async {
    final source = FakeAutomaticScreenshotSource(
      permission: MediaPermissionStatus.unsupported,
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        automaticScreenshotSource: source,
        automaticSettingsRepository: FakeAutomaticImportSettingsRepository(
          enabled: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'A organização automática não está disponível neste dispositivo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.textContaining('WorkManager'), findsNothing);
    expect(find.textContaining('MediaStore'), findsNothing);
  });

  testWidgets('importação automática atualiza biblioteca e feedback', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'automatico.png');
    final source = FakeAutomaticScreenshotSource(
      batches: [
        AutomaticScreenshotBatch(
          lastExaminedMediaId: 8,
          items: [
            AutomaticScreenshotCandidate(
              mediaId: 8,
              temporaryPath: image.path,
              mimeType: 'image/png',
            ),
          ],
        ),
      ],
    );
    final settings = FakeAutomaticImportSettingsRepository(
      enabled: true,
      marker: 7,
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        automaticScreenshotSource: source,
        automaticSettingsRepository: settings,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('Screenshot importado automaticamente.'), findsOneWidget);
  });

  testWidgets('detalhes apresentam origem automática', (tester) async {
    final image = createTestImage(temporaryDirectory, 'origem-auto.png');
    final repository = FakeMediaItemRepository(
      initialItems: [
        createMediaItem(1, image.path, importOrigin: ImportOrigin.automatic),
      ],
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();
    await openFirstScreenshot(tester);

    expect(find.text('Importado automaticamente'), findsOneWidget);
  });

  testWidgets('Home abre antes de terminar consumo da caixa de entrada', (
    tester,
  ) async {
    final inboxCompleter = Completer<List<BackgroundScreenshotEntry>>();
    final source = FakeAutomaticScreenshotSource(
      inboxCompleter: inboxCompleter,
    );

    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), automaticScreenshotSource: source),
    );
    await tester.pump();

    expect(find.text('MemoShot'), findsOneWidget);
    expect(find.text('Últimos prints'), findsOneWidget);

    inboxCompleter.complete(const []);
    await tester.pump();
  });

  testWidgets('entrada em segundo plano preserva pesquisa ativa', (
    tester,
  ) async {
    final existing = createTestImage(temporaryDirectory, 'busca-inbox-a.png');
    final incoming = createTestImage(temporaryDirectory, 'busca-inbox-b.png');
    final repository = FakeMediaItemRepository(
      initialItems: [createMediaItem(1, existing.path)],
      recognizedTexts: const {1: 'Conteúdo pesquisável'},
    );
    final inboxCompleter = Completer<List<BackgroundScreenshotEntry>>();
    final source = FakeAutomaticScreenshotSource(
      inboxCompleter: inboxCompleter,
    );
    final settings = FakeAutomaticImportSettingsRepository(
      enabled: true,
      marker: 4,
    );
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: repository,
        automaticScreenshotSource: source,
        automaticSettingsRepository: settings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pesquisável');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    inboxCompleter.complete([
      BackgroundScreenshotEntry(
        entryId: 'background-1',
        mediaId: 5,
        privatePath: incoming.path,
        mimeType: 'image/png',
      ),
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 resultado para “pesquisável”'), findsOneWidget);
    expect(repository.itemCount, 2);
  });

  testWidgets('Home mostra screenshots pela captura real', (tester) async {
    final first = createTestImage(temporaryDirectory, 'home-order-a.png');
    final second = createTestImage(temporaryDirectory, 'home-order-b.png');
    final third = createTestImage(temporaryDirectory, 'home-order-c.png');
    final repository = FakeMediaItemRepository(
      initialItems: [
        createMediaItem(
          1,
          first.path,
          importedAt: DateTime(2026, 3, 3),
          capturedAt: DateTime(2026, 3, 1),
        ),
        createMediaItem(
          2,
          second.path,
          importedAt: DateTime(2026, 3, 1),
          capturedAt: DateTime(2026, 3, 3),
        ),
        createMediaItem(
          3,
          third.path,
          importedAt: DateTime(2026, 3, 2),
          capturedAt: DateTime(2026, 3, 2),
        ),
      ],
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();

    final grid = tester.widget<ScreenshotSliverGrid>(
      find.byType(ScreenshotSliverGrid),
    );
    expect(grid.mediaItems.map((item) => item.id), [2, 3, 1]);
  });

  testWidgets('Home e Configurações não expõem revisão ou notificações', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pumpAndSettle();

    expect(find.text('Para revisar'), findsNothing);
    expect(find.byType(ReviewQueuePage), findsNothing);

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Notificações de revisão'), findsNothing);
    expect(find.byKey(const Key('review-notifications-switch')), findsNothing);
  });

  testWidgets(
    'detalhe referenciado fica seguro quando original está indisponível',
    (tester) async {
      final item = createReferencedMediaItem(1);
      await tester.pumpWidget(
        buildTestApp(
          FakeScreenshotPicker(),
          repository: FakeMediaItemRepository(initialItems: [item]),
          mediaStoreContentGateway: _UnavailableMediaStoreGateway(),
        ),
      );
      await tester.pumpAndSettle();
      await openFirstScreenshot(tester);

      expect(find.text('Imagem indisponível.'), findsOneWidget);
      expect(find.textContaining('content://'), findsNothing);
      expect(find.textContaining('external_primary:1'), findsNothing);
      await tapRemoveFromMemoShot(tester);
      expect(
        find.textContaining('A imagem original continuará na galeria.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('detalhe abre original e traduz falhas controladas', (
    tester,
  ) async {
    const cases = {
      OriginalMediaOpenResult.unavailable:
          'Esta imagem não está mais disponível no dispositivo.',
      OriginalMediaOpenResult.permissionDenied:
          'Revise o acesso às imagens para abrir o original.',
      OriginalMediaOpenResult.noCompatibleApp:
          'Não encontramos um aplicativo para abrir esta imagem.',
      OriginalMediaOpenResult.temporaryFailure:
          'Não foi possível abrir a imagem agora.',
    };
    for (final entry in cases.entries) {
      final viewer = FakeOriginalMediaViewer(entry.key);
      await tester.pumpWidget(
        buildTestApp(
          FakeScreenshotPicker(),
          repository: FakeMediaItemRepository(
            initialItems: [createReferencedMediaItem(1)],
          ),
          originalMediaViewer: viewer,
        ),
      );
      await tester.pumpAndSettle();
      await openFirstScreenshot(tester);
      await tapDetailAction(tester, 'Abrir original');
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);
      expect(viewer.openedIds, [1]);
      expect(find.text('Alterar organização'), findsOneWidget);
      expect(find.textContaining('content://'), findsNothing);
    }

    final viewer = FakeOriginalMediaViewer(OriginalMediaOpenResult.opened);
    await tester.pumpWidget(
      buildTestApp(
        FakeScreenshotPicker(),
        repository: FakeMediaItemRepository(
          initialItems: [createReferencedMediaItem(1)],
        ),
        originalMediaViewer: viewer,
      ),
    );
    await tester.pumpAndSettle();
    await openFirstScreenshot(tester);
    await tapDetailAction(tester, 'Abrir original');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-original-error')), findsNothing);
  });

  testWidgets('Home consulta e mantém somente os 12 prints mais recentes', (
    tester,
  ) async {
    final repository = FakeMediaItemRepository(
      initialItems: _manyMediaItems(125),
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();

    final grid = tester.widget<ScreenshotSliverGrid>(
      find.byType(ScreenshotSliverGrid),
    );
    expect(grid.mediaItems, hasLength(homeRecentMediaItemLimit));
    expect(repository.loadCallCount, 1);
    expect(repository.pageRequests.single.pageSize, homeRecentMediaItemLimit);
    expect(find.text('Últimos prints'), findsOneWidget);
    expect(find.text('Ver todos'), findsOneWidget);
    expect(
      find.byType(MediaItemThumbnail).evaluate().length,
      lessThanOrEqualTo(homeRecentMediaItemLimit),
    );
  });

  testWidgets('Ver todos abre biblioteca e pagina até o fim', (tester) async {
    final repository = FakeMediaItemRepository(
      initialItems: _manyMediaItems(65),
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('view-all-screenshots')));
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca'), findsOneWidget);
    var grid = tester.widget<ScreenshotSliverGrid>(
      find.byType(ScreenshotSliverGrid),
    );
    expect(grid.mediaItems, hasLength(defaultMediaPageSize));
    expect(repository.pageRequests.last.pageSize, defaultMediaPageSize);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('screenshot-tile-1')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    grid = tester.widget<ScreenshotSliverGrid>(
      find.byType(ScreenshotSliverGrid),
    );
    expect(grid.mediaItems, hasLength(65));
    expect(repository.loadCallCount, 3);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1000));
    await tester.pumpAndSettle();
    grid = tester.widget<ScreenshotSliverGrid>(
      find.byType(ScreenshotSliverGrid),
    );
    expect(grid.mediaItems, hasLength(65));
    expect(repository.loadCallCount, 3);
  });

  testWidgets(
    'erro intermediário da biblioteca preserva itens e permite retry',
    (tester) async {
      final repository = FakeMediaItemRepository(
        initialItems: _manyMediaItems(70),
        failNextPage: true,
      );
      await tester.pumpWidget(
        buildTestApp(FakeScreenshotPicker(), repository: repository),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('view-all-screenshots')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -5000),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível carregar mais prints.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ScreenshotSliverGrid>(find.byType(ScreenshotSliverGrid))
            .mediaItems,
        hasLength(60),
      );

      repository.failNextPage = false;
      tester
          .widget<TextButton>(find.byKey(const Key('library-message-action')))
          .onPressed!();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ScreenshotSliverGrid>(find.byType(ScreenshotSliverGrid))
            .mediaItems,
        hasLength(70),
      );
    },
  );

  testWidgets('erro da primeira página usa mensagem e retry próprios', (
    tester,
  ) async {
    final repository = FakeMediaItemRepository(
      initialItems: _manyMediaItems(1),
      loadError: StateError('Falha privada'),
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();
    expect(find.text('Não foi possível carregar seus prints.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    repository._loadError = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Últimos prints'), findsOneWidget);
  });
}

List<MediaItem> _manyMediaItems(int count) {
  final capturedAt = DateTime.utc(2026, 7, 19);
  return List.generate(
    count,
    (index) => createMediaItem(
      index + 1,
      '/tmp/memoshot-page-${index + 1}.png',
      importedAt: capturedAt,
      capturedAt: capturedAt,
    ),
  );
}

Widget buildTestApp(
  ScreenshotPicker picker, {
  FakeMediaItemRepository? repository,
  FakeOcrRepository? ocrRepository,
  FakeOcrQueue? ocrQueue,
  FakeClassificationQueue? classificationQueue,
  FakeCategoryRepository? categoryRepository,
  RecentFolderRepository? recentFolderRepository,
  FakeTagRepository? tagRepository,
  FakeClassificationSuggestionRepository? classificationRepository,
  IncomingShareSource? incomingShareSource,
  FakeAutomaticScreenshotSource? automaticScreenshotSource,
  FakeAutomaticImportSettingsRepository? automaticSettingsRepository,
  OnboardingRepository? onboardingRepository,
  ExistingScreenshotInventoryCoordinator?
  existingScreenshotInventoryCoordinator,
  MediaStoreContentGateway? mediaStoreContentGateway,
  OriginalMediaViewer? originalMediaViewer,
}) {
  final resolvedOcrRepository = ocrRepository ?? FakeOcrRepository();
  final resolvedMediaRepository = repository ?? FakeMediaItemRepository();
  final resolvedCategoryRepository =
      categoryRepository ?? FakeCategoryRepository();
  final resolvedRecentFolderRepository =
      recentFolderRepository ??
      LocalRecentFolderRepository(
        store: MemoryRecentFolderIdStore(),
        categoryRepository: resolvedCategoryRepository,
      );
  final resolvedTagRepository = tagRepository ?? FakeTagRepository();
  resolvedCategoryRepository.mediaItems = resolvedMediaRepository._items;
  resolvedMediaRepository.tagAssociations = resolvedTagRepository._associations;
  final resolvedAutomaticSource =
      automaticScreenshotSource ?? FakeAutomaticScreenshotSource();
  return MemoShotApp(
    key: UniqueKey(),
    screenshotPicker: picker,
    mediaRepository: resolvedMediaRepository,
    ocrRepository: resolvedOcrRepository,
    ocrQueue: ocrQueue ?? FakeOcrQueue(resolvedOcrRepository),
    classificationQueue: classificationQueue,
    categoryRepository: resolvedCategoryRepository,
    recentFolderRepository: resolvedRecentFolderRepository,
    classificationSuggestionRepository:
        classificationRepository ?? FakeClassificationSuggestionRepository(),
    tagRepository: resolvedTagRepository,
    incomingShareSource: incomingShareSource ?? FakeIncomingShareSource(),
    automaticScreenshotSource: resolvedAutomaticSource,
    automaticImportSettingsRepository:
        automaticSettingsRepository ?? FakeAutomaticImportSettingsRepository(),
    onboardingRepository:
        onboardingRepository ?? FakeOnboardingRepository(completed: true),
    existingScreenshotInventoryCoordinator:
        existingScreenshotInventoryCoordinator ??
        ExistingScreenshotInventoryCoordinator(
          permissionSource: resolvedAutomaticSource,
          scanner: _EmptyExistingScreenshotScanner(),
          repository: _EmptyExistingScreenshotRepository(),
        ),
    mediaStoreContentGateway: mediaStoreContentGateway,
    originalMediaViewer: originalMediaViewer,
  );
}

class _EmptyExistingScreenshotScanner implements ExistingScreenshotScanner {
  @override
  Future<String> beginScan() async => 'test';

  @override
  Future<void> cancelScan() async {}

  @override
  Future<ExistingScreenshotScanPage> scanPage({
    required String sessionId,
    ExistingScreenshotScanCursor? cursor,
  }) async => const ExistingScreenshotScanPage(
    examinedCount: 0,
    recognizedCount: 0,
    hasNext: false,
    nextCursor: null,
    items: [],
  );
}

class _EmptyExistingScreenshotRepository
    implements ExistingScreenshotCandidateRepository {
  @override
  Future<void> completeScan({
    required DateTime scanStartedAt,
    required DateTime completedAt,
    required bool partialAccess,
  }) async {}

  @override
  Future<void> clearInventory() async {}

  @override
  Future<int> countAvailable() async => 0;

  @override
  Future<int> countUnavailable() async => 0;

  @override
  Future<ExistingScreenshotCandidate?> findBySourceKey(
    String sourceKey,
  ) async => null;

  @override
  Future<ExistingScreenshotInventorySummary> loadSummary() async =>
      const ExistingScreenshotInventorySummary.empty();

  @override
  Future<List<ExistingScreenshotCandidate>> loadCandidatesPage({
    int limit = 200,
    String? afterSourceKey,
  }) async => const [];

  @override
  Future<void> markUnavailableNotSeenInCompletedScan(
    DateTime scanStartedAt,
  ) async {}

  @override
  Future<void> recordCompletedScan({
    required DateTime completedAt,
    required bool partialAccess,
  }) async {}

  @override
  Future<void> upsertBatch(
    List<ExistingScreenshotCandidate> candidates,
  ) async {}
}

class FakeClassificationSuggestionRepository
    implements ClassificationSuggestionRepository {
  FakeClassificationSuggestionRepository({
    List<StoredClassificationSuggestion> pending = const [],
    List<int> counts = const [0],
    this.countError,
    this.loadError,
  }) : _pending = [...pending],
       _counts = [...counts];

  final List<StoredClassificationSuggestion> _pending;
  final List<int> _counts;
  final Object? countError;
  final Object? loadError;
  int countCallCount = 0;

  @override
  Future<int> countPendingReview() async {
    countCallCount++;
    if (countError != null) throw countError!;
    if (_counts.isEmpty) return 0;
    final index = (countCallCount - 1).clamp(0, _counts.length - 1);
    return _counts[index];
  }

  @override
  Future<ReviewNotificationSnapshot> loadReviewNotificationSnapshot() async {
    if (_pending.isEmpty) return const ReviewNotificationSnapshot.empty();
    final latest = _pending.reduce(
      (left, right) => left.createdAt.isAfter(right.createdAt) ? left : right,
    );
    return ReviewNotificationSnapshot(
      pendingCount: _pending.length,
      latestPendingCreatedAt: latest.createdAt,
      latestPendingMediaItemId: latest.mediaItemId,
    );
  }

  @override
  Future<List<StoredClassificationSuggestion>> loadPendingReview() async {
    if (loadError != null) throw loadError!;
    return [..._pending];
  }

  @override
  Future<StoredClassificationSuggestion?> loadByMediaItemId(
    int mediaItemId,
  ) async =>
      _pending.where((item) => item.mediaItemId == mediaItemId).firstOrNull;

  @override
  Future<void> deleteForMediaItem(int mediaItemId) async {
    _pending.removeWhere((item) => item.mediaItemId == mediaItemId);
  }

  @override
  Future<StoredClassificationSuggestion> saveSuggestion(
    StoredClassificationSuggestion suggestion,
  ) async => suggestion;

  @override
  Future<StoredClassificationSuggestion> replaceSuggestion(
    StoredClassificationSuggestion suggestion,
  ) async => suggestion;

  @override
  Future<StoredClassificationSuggestion> saveAutomaticSuggestion(
    StoredClassificationSuggestion suggestion, {
    required DateTime ocrProcessedAt,
  }) async => suggestion;

  @override
  Future<StoredClassificationSuggestion> updateStatus(
    int mediaItemId,
    ClassificationSuggestionStatus status,
  ) => throw UnsupportedError('Fora do escopo do teste.');

  @override
  Future<StoredClassificationSuggestion> markAccepted(int mediaItemId) =>
      throw UnsupportedError('Fora do escopo do teste.');

  @override
  Future<StoredClassificationSuggestion> markRejected(int mediaItemId) =>
      throw UnsupportedError('Fora do escopo do teste.');

  @override
  Future<StoredClassificationSuggestion> markAutoApplied(int mediaItemId) =>
      throw UnsupportedError('Fora do escopo do teste.');
}

StoredClassificationSuggestion createSuggestion(int mediaItemId) {
  final at = DateTime.utc(2026, 7, 19);
  return StoredClassificationSuggestion(
    mediaItemId: mediaItemId,
    suggestedCategoryName: 'Carreira',
    confidence: 0.6,
    hasSuggestion: true,
    suggestedTags: const [],
    evidence: const [],
    status: ClassificationSuggestionStatus.pendingReview,
    reviewReason: ClassificationReviewReason.manualReview,
    engineVersion: 1,
    createdAt: at,
    updatedAt: at,
  );
}

Widget buildCategoryDetailTestApp({
  required CategorySummary summary,
  required FakeCategoryRepository categories,
  FakeMediaItemRepository? media,
}) {
  final resolvedMedia = media ?? FakeMediaItemRepository();
  final ocr = FakeOcrRepository();
  categories.mediaItems = resolvedMedia._items;
  return MaterialApp(
    theme: AppTheme.light,
    home: CategoryDetailPage(
      summary: summary,
      categoryRepository: categories,
      mediaRepository: resolvedMedia,
      ocrRepository: ocr,
      ocrQueue: FakeOcrQueue(ocr),
      tagRepository: FakeTagRepository(),
    ),
  );
}

class FakeTagRepository implements TagRepository {
  FakeTagRepository({
    this.failLoadForMedia = false,
    this.failAdd = false,
    this.failRemove = false,
    this.loadForMediaCompleter,
    this.addCompleter,
    this.failLoadSummaries = false,
  });

  final List<Tag> _tags = [];
  final Map<int, Set<int>> _associations = {};
  final bool failLoadForMedia;
  final bool failAdd;
  final bool failRemove;
  final Completer<List<Tag>>? loadForMediaCompleter;
  final Completer<void>? addCompleter;
  final bool failLoadSummaries;
  int createCallCount = 0;
  int addCallCount = 0;
  int removeCallCount = 0;
  int deleteCallCount = 0;
  int loadForMediaCallCount = 0;

  @override
  Future<Tag> createTag(String name) async {
    createCallCount++;
    final visibleName = name.trim();
    const normalizer = TextNormalizer();
    final normalizedName = normalizer.normalize(visibleName);
    if (normalizedName.isEmpty) {
      throw const TagValidationException(TagValidationError.empty);
    }
    if (visibleName.length > 40) {
      throw const TagValidationException(TagValidationError.tooLong);
    }
    if (_tags.any((tag) => tag.normalizedName == normalizedName)) {
      throw const TagValidationException(TagValidationError.duplicate);
    }
    final tag = Tag(
      id: _tags.length + 1,
      name: visibleName,
      normalizedName: normalizedName,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    _tags.add(tag);
    return tag;
  }

  @override
  Future<List<Tag>> loadTags() async => [..._tags]
    ..sort(
      (first, second) => first.normalizedName.compareTo(second.normalizedName),
    );

  @override
  Future<List<TagSummary>> loadTagSummaries() async {
    if (failLoadSummaries) throw StateError('Falha privada ao listar');
    final summaries = [
      for (final tag in _tags)
        TagSummary(
          tag: tag,
          mediaCount: _associations.values
              .where((tagIds) => tagIds.contains(tag.id))
              .length,
        ),
    ];
    summaries.sort(
      (first, second) =>
          first.tag.normalizedName.compareTo(second.tag.normalizedName),
    );
    return summaries;
  }

  @override
  Future<Tag?> findById(int id) async {
    final matches = _tags.where((tag) => tag.id == id);
    return matches.isEmpty ? null : matches.single;
  }

  @override
  Future<Tag?> findByNormalizedName(String normalizedName) async {
    const normalizer = TextNormalizer();
    final normalized = normalizer.normalize(normalizedName);
    final matches = _tags.where((tag) => tag.normalizedName == normalized);
    return matches.isEmpty ? null : matches.single;
  }

  @override
  Future<Tag> renameTag(Tag tag, String name) => throw UnimplementedError();

  @override
  Future<void> deleteTag(int tagId) async {
    deleteCallCount++;
    _tags.removeWhere((tag) => tag.id == tagId);
    for (final tagIds in _associations.values) {
      tagIds.remove(tagId);
    }
  }

  @override
  Future<void> addToMedia({
    required int tagId,
    required int mediaItemId,
  }) async {
    addCallCount++;
    if (failAdd) throw StateError('Falha privada ao associar');
    if (addCompleter != null) await addCompleter!.future;
    (_associations[mediaItemId] ??= {}).add(tagId);
  }

  @override
  Future<void> removeFromMedia({
    required int tagId,
    required int mediaItemId,
  }) async {
    removeCallCount++;
    if (failRemove) throw StateError('Falha privada ao remover');
    _associations[mediaItemId]?.remove(tagId);
  }

  @override
  Future<bool> isAssociated({
    required int tagId,
    required int mediaItemId,
  }) async {
    return _associations[mediaItemId]?.contains(tagId) ?? false;
  }

  @override
  Future<List<Tag>> loadForMedia(int mediaItemId) async {
    loadForMediaCallCount++;
    if (failLoadForMedia) throw StateError('Falha privada ao carregar');
    if (loadForMediaCompleter != null) return loadForMediaCompleter!.future;
    final ids = _associations[mediaItemId] ?? const <int>{};
    return _tags.where((tag) => ids.contains(tag.id)).toList()..sort(
      (first, second) => first.normalizedName.compareTo(second.normalizedName),
    );
  }

  @override
  Future<List<MediaItem>> loadMediaForTag(int tagId) async => const [];

  void seedAssociation({required int tagId, required int mediaItemId}) {
    (_associations[mediaItemId] ??= {}).add(tagId);
  }
}

class FakeAutomaticScreenshotSource implements AutomaticScreenshotSource {
  FakeAutomaticScreenshotSource({
    this.permission = MediaPermissionStatus.fullAccess,
    this.maxMediaId = 0,
    this.inboxCompleter,
    this.permissionRequestCompleter,
    this.failBackgroundConfiguration = false,
    List<AutomaticScreenshotBatch> batches = const [],
  }) : batches = [...batches];

  MediaPermissionStatus permission;
  int maxMediaId;
  int requestCount = 0;
  int startCount = 0;
  int stopCount = 0;
  final List<AutomaticScreenshotBatch> batches;
  final List<String> deletedPaths = [];
  final List<BackgroundScreenshotEntry> inbox = [];
  final Completer<List<BackgroundScreenshotEntry>>? inboxCompleter;
  final Completer<MediaPermissionStatus>? permissionRequestCompleter;
  final bool failBackgroundConfiguration;
  int backgroundMarker = 0;
  int backgroundConfigurationCount = 0;
  int openSettingsCount = 0;

  @override
  Future<void> acknowledgeBackgroundEntry(String entryId) async {
    inbox.removeWhere((entry) => entry.entryId == entryId);
  }

  @override
  Future<BackgroundMonitorStatus> configureBackgroundMonitoring({
    required bool enabled,
    required int lastMediaId,
    bool resetBaseline = false,
  }) async {
    backgroundConfigurationCount++;
    if (failBackgroundConfiguration) {
      throw StateError('Falha privada ao configurar');
    }
    backgroundMarker = resetBaseline || lastMediaId > backgroundMarker
        ? lastMediaId
        : backgroundMarker;
    return BackgroundMonitorStatus(
      available: true,
      enabled: enabled,
      lastMediaId: backgroundMarker,
    );
  }

  final StreamController<void> controller = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => controller.stream;

  @override
  Future<int> backgroundInboxPendingCount() async => inbox.length;

  @override
  Future<int> currentMaxMediaId() async => maxMediaId;

  @override
  Future<void> deleteTemporary(String path) async => deletedPaths.add(path);

  @override
  Future<void> openAppSettings() async => openSettingsCount++;

  @override
  Future<List<BackgroundScreenshotEntry>> loadBackgroundInbox() async =>
      inboxCompleter?.future ?? [...inbox];

  @override
  Future<MediaPermissionStatus> permissionStatus() async => permission;

  @override
  Future<MediaPermissionStatus> requestPermission() async {
    requestCount++;
    return permissionRequestCompleter?.future ?? permission;
  }

  @override
  Future<void> rejectBackgroundEntry(String entryId) async {
    inbox.removeWhere((entry) => entry.entryId == entryId);
  }

  @override
  Future<AutomaticScreenshotBatch> scanAfter(int lastMediaId) async =>
      batches.isEmpty
      ? AutomaticScreenshotBatch(
          lastExaminedMediaId: lastMediaId,
          items: const [],
        )
      : batches.removeAt(0);

  @override
  Future<void> startObserving() async {
    startCount++;
  }

  @override
  Future<void> stopObserving() async {
    stopCount++;
  }
}

class FakeAutomaticImportSettingsRepository
    implements AutomaticImportSettingsRepository {
  FakeAutomaticImportSettingsRepository({
    this.enabled = false,
    this.marker,
    this.hasStoredPreference = true,
    this.failEnable = false,
    this.failDisable = false,
  });

  bool enabled;
  int? marker;
  bool hasStoredPreference;
  final bool failEnable;
  final bool failDisable;
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> disable() async {
    disableCalls++;
    if (failDisable) throw StateError('Falha privada ao desativar');
    enabled = false;
    hasStoredPreference = true;
  }

  @override
  Future<void> enable({required int baselineMediaId}) async {
    enableCalls++;
    if (failEnable) throw StateError('Falha privada ao ativar');
    enabled = true;
    hasStoredPreference = true;
    marker = baselineMediaId;
  }

  @override
  Future<AutomaticImportSettings> load() async => AutomaticImportSettings(
    enabled: enabled,
    hasStoredPreference: hasStoredPreference,
    lastMediaId: marker,
    updatedAt: DateTime(2026),
  );

  @override
  Future<void> updateMarker(int lastMediaId) async => marker = lastMediaId;
}

class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({this.completed = false, this.completeBlocker});

  bool completed;
  int completeCalls = 0;
  final Completer<void>? completeBlocker;

  @override
  bool? get cachedCompletion => completed;

  @override
  Future<void> complete() async {
    completeCalls++;
    await completeBlocker?.future;
    completed = true;
  }

  @override
  Future<bool> isCompleted() async => completed;
}

class FakeIncomingShareSource implements IncomingShareSource {
  FakeIncomingShareSource({this.initialMedia = const []});

  final List<IncomingSharedMedia> initialMedia;
  final StreamController<List<IncomingSharedMedia>> controller =
      StreamController.broadcast();
  int resetCount = 0;

  @override
  Future<List<IncomingSharedMedia>> getInitialMedia() async => initialMedia;

  @override
  Stream<List<IncomingSharedMedia>> get mediaStream => controller.stream;

  @override
  Future<void> reset() async {
    resetCount++;
  }

  void emit(List<IncomingSharedMedia> media) => controller.add(media);

  Future<void> close() => controller.close();
}

class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository({List<Category> categories = const []})
    : _categories = [...categories];

  final List<Category> _categories;
  final Map<int, Set<int>> _associations = {};
  int moveCallCount = 0;

  @override
  Future<Category> createCategory(String name) async {
    return createRootCategory(name);
  }

  @override
  Future<Category> createRootCategory(String name) {
    return _createCategory(name, null);
  }

  @override
  Future<Category> createSubcategory({
    required int parentId,
    required String name,
  }) async {
    if (await findCategoryById(parentId) == null) {
      throw const CategoryHierarchyException(
        CategoryHierarchyError.parentNotFound,
      );
    }
    return _createCategory(name, parentId);
  }

  Future<Category> _createCategory(String name, int? parentId) async {
    final visible = name.trim();
    const normalizer = TextNormalizer();
    final normalized = normalizer.normalize(visible);
    if (normalized.isEmpty) {
      throw const CategoryValidationException(CategoryValidationError.empty);
    }
    if (visible.length > 40) {
      throw const CategoryValidationException(CategoryValidationError.tooLong);
    }
    if (_categories.any(
      (category) =>
          category.parentId == parentId &&
          category.normalizedName == normalized,
    )) {
      throw const CategoryValidationException(
        CategoryValidationError.duplicate,
      );
    }
    final category = Category(
      id: _categories.length + 1,
      name: visible,
      normalizedName: normalized,
      createdAt: DateTime(2025),
      parentId: parentId,
    );
    _categories.add(category);
    return category;
  }

  @override
  Future<Category?> findCategoryById(int id) async {
    final matches = _categories.where((category) => category.id == id);
    return matches.isEmpty ? null : matches.single;
  }

  @override
  Future<List<Category>> loadRootCategories() async =>
      _ordered(_categories.where((category) => category.parentId == null));

  @override
  Future<List<CategorySummary>> loadRootCategorySummaries() async {
    return _summariesFor(await loadRootCategories());
  }

  @override
  Future<List<Category>> loadChildCategories(int parentId) async =>
      _ordered(_categories.where((category) => category.parentId == parentId));

  @override
  Future<List<CategorySummary>> loadChildCategorySummaries(int parentId) async {
    return _summariesFor(await loadChildCategories(parentId));
  }

  List<CategorySummary> _summariesFor(List<Category> categories) {
    final existingMediaIds = mediaItems.map((item) => item.id).toSet();
    return [
      for (final category in categories)
        CategorySummary(
          category: category,
          mediaCount: _associations.entries
              .where(
                (entry) =>
                    existingMediaIds.contains(entry.key) &&
                    entry.value.contains(category.id),
              )
              .length,
          childCount: _categories
              .where((item) => item.parentId == category.id)
              .length,
        ),
    ];
  }

  List<Category> _ordered(Iterable<Category> categories) =>
      categories.toList()..sort(
        (first, second) =>
            first.normalizedName.compareTo(second.normalizedName) != 0
            ? first.normalizedName.compareTo(second.normalizedName)
            : first.id.compareTo(second.id),
      );

  @override
  Future<List<Category>> loadAncestors(int categoryId) async {
    final category = await findCategoryById(categoryId);
    if (category == null) {
      throw const CategoryHierarchyException(
        CategoryHierarchyError.categoryNotFound,
      );
    }
    final result = <Category>[];
    var parentId = category.parentId;
    final visited = <int>{categoryId};
    while (parentId != null) {
      if (!visited.add(parentId)) {
        throw const CategoryHierarchyException(CategoryHierarchyError.cycle);
      }
      final parent = await findCategoryById(parentId);
      if (parent == null) {
        throw const CategoryHierarchyException(
          CategoryHierarchyError.parentNotFound,
        );
      }
      result.add(parent);
      parentId = parent.parentId;
    }
    return result.reversed.toList();
  }

  @override
  Future<CategoryPath> loadPath(int categoryId) async {
    final category = await findCategoryById(categoryId);
    if (category == null) {
      throw const CategoryHierarchyException(
        CategoryHierarchyError.categoryNotFound,
      );
    }
    return CategoryPath([...await loadAncestors(categoryId), category]);
  }

  @override
  Future<List<Category>> loadDescendants(int categoryId) async {
    if (await findCategoryById(categoryId) == null) {
      throw const CategoryHierarchyException(
        CategoryHierarchyError.categoryNotFound,
      );
    }
    final result = <Category>[];
    final pending = <Category>[
      ...(await loadChildCategories(categoryId)).reversed,
    ];
    final visited = <int>{categoryId};
    while (pending.isNotEmpty) {
      final category = pending.removeLast();
      if (!visited.add(category.id)) {
        throw const CategoryHierarchyException(CategoryHierarchyError.cycle);
      }
      result.add(category);
      pending.addAll((await loadChildCategories(category.id)).reversed);
    }
    return result;
  }

  @override
  Future<bool> hasChildren(int categoryId) async =>
      _categories.any((category) => category.parentId == categoryId);

  @override
  Future<bool> wouldCreateCycle({
    required int categoryId,
    required int? parentId,
  }) async {
    if (parentId == null) return false;
    return categoryId == parentId ||
        (await loadDescendants(
          categoryId,
        )).any((category) => category.id == parentId);
  }

  @override
  Future<Category> moveCategory(
    Category category, {
    required int? parentId,
  }) async {
    moveCallCount++;
    if (await findCategoryById(category.id) == null) {
      throw const CategoryHierarchyException(
        CategoryHierarchyError.categoryNotFound,
      );
    }
    if (parentId != null && await findCategoryById(parentId) == null) {
      throw const CategoryHierarchyException(
        CategoryHierarchyError.parentNotFound,
      );
    }
    if (await wouldCreateCycle(categoryId: category.id, parentId: parentId)) {
      throw CategoryHierarchyException(
        parentId == category.id
            ? CategoryHierarchyError.selfParent
            : CategoryHierarchyError.cycle,
      );
    }
    if (_categories.any(
      (item) =>
          item.id != category.id &&
          item.parentId == parentId &&
          item.normalizedName == category.normalizedName,
    )) {
      throw const CategoryValidationException(
        CategoryValidationError.duplicate,
      );
    }
    final moved = Category(
      id: category.id,
      name: category.name,
      normalizedName: category.normalizedName,
      createdAt: category.createdAt,
      parentId: parentId,
    );
    _categories[_categories.indexWhere((item) => item.id == category.id)] =
        moved;
    return moved;
  }

  @override
  Future<List<CategorySummary>> loadCategories() async {
    return _summariesFor(_categories);
  }

  @override
  Future<List<Category>> loadForMedia(int mediaItemId) async {
    final ids = _associations[mediaItemId] ?? const <int>{};
    return _categories.where((category) => ids.contains(category.id)).toList();
  }

  @override
  Future<void> replaceForMedia(int mediaItemId, Set<int> categoryIds) async {
    _associations[mediaItemId] = {...categoryIds};
  }

  @override
  Future<Category> renameCategory(Category category, String name) async {
    final visible = name.trim();
    const normalizer = TextNormalizer();
    final normalized = normalizer.normalize(visible);
    if (normalized.isEmpty) {
      throw const CategoryValidationException(CategoryValidationError.empty);
    }
    if (visible.length > 40) {
      throw const CategoryValidationException(CategoryValidationError.tooLong);
    }
    if (_categories.any(
      (item) =>
          item.id != category.id &&
          item.parentId == category.parentId &&
          item.normalizedName == normalized,
    )) {
      throw const CategoryValidationException(
        CategoryValidationError.duplicate,
      );
    }
    final renamed = Category(
      id: category.id,
      name: visible,
      normalizedName: normalized,
      createdAt: category.createdAt,
      parentId: category.parentId,
    );
    final index = _categories.indexWhere((item) => item.id == category.id);
    _categories[index] = renamed;
    return renamed;
  }

  @override
  Future<void> deleteCategory(int categoryId) async {
    if (await hasChildren(categoryId)) {
      throw const CategoryHierarchyException(
        CategoryHierarchyError.hasChildren,
      );
    }
    _categories.removeWhere((category) => category.id == categoryId);
    for (final ids in _associations.values) {
      ids.remove(categoryId);
    }
  }

  @override
  Future<List<MediaItem>> loadMediaForCategory(int categoryId) async {
    final mediaIds = _associations.entries
        .where((entry) => entry.value.contains(categoryId))
        .map((entry) => entry.key)
        .toSet();
    return mediaItems
        .where(
          (item) =>
              mediaIds.contains(item.id) &&
              (item.privatePath == null ||
                  File(item.privatePath!).existsSync()),
        )
        .toList()
      ..sort(compareMediaItemsRecentFirst);
  }

  List<MediaItem> mediaItems = [];
}

class MemoryRecentFolderIdStore implements RecentFolderIdStore {
  MemoryRecentFolderIdStore([List<int> ids = const []]) : ids = [...ids];

  List<int> ids;
  Object? loadError;

  @override
  Future<List<int>> loadIds() async {
    if (loadError case final error?) throw error;
    return [...ids];
  }

  @override
  Future<void> saveIds(List<int> ids) async => this.ids = [...ids];
}

class FailingCategoryRepository extends FakeCategoryRepository {
  FailingCategoryRepository({
    this.failFind = false,
    this.failChildren = false,
    this.failMedia = false,
  });

  final bool failFind;
  final bool failChildren;
  final bool failMedia;

  @override
  Future<Category?> findCategoryById(int id) {
    if (failFind) return Future.error(Exception('falha privada'));
    return super.findCategoryById(id);
  }

  @override
  Future<List<CategorySummary>> loadChildCategorySummaries(int parentId) {
    if (failChildren) return Future.error(Exception('falha privada'));
    return super.loadChildCategorySummaries(parentId);
  }

  @override
  Future<List<MediaItem>> loadMediaForCategory(int categoryId) {
    if (failMedia) return Future.error(Exception('falha privada'));
    return super.loadMediaForCategory(categoryId);
  }
}

class ControlledCategoryRepository extends FakeCategoryRepository {
  bool failCreate = false;
  bool failMove = false;
  Object? moveFailure;
  Completer<void>? createBlocker;
  Completer<void>? moveBlocker;
  int createOperationCalls = 0;
  int moveOperationCalls = 0;

  @override
  Future<Category> createRootCategory(String name) async {
    createOperationCalls++;
    await createBlocker?.future;
    if (failCreate) throw Exception('falha privada');
    return super.createRootCategory(name);
  }

  @override
  Future<Category> createSubcategory({
    required int parentId,
    required String name,
  }) async {
    createOperationCalls++;
    await createBlocker?.future;
    if (failCreate) throw Exception('falha privada');
    return super.createSubcategory(parentId: parentId, name: name);
  }

  @override
  Future<Category> moveCategory(
    Category category, {
    required int? parentId,
  }) async {
    moveOperationCalls++;
    await moveBlocker?.future;
    if (moveFailure != null) throw moveFailure!;
    if (failMove) throw Exception('falha privada');
    return super.moveCategory(category, parentId: parentId);
  }
}

Future<void> openFirstScreenshot(WidgetTester tester) async {
  final tile = find.byKey(const ValueKey('screenshot-tile-1'));
  await tester.scrollUntilVisible(
    tile,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(tile);
  await tester.pump();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> _openMoveDialog(WidgetTester tester, int categoryId) async {
  final tile = find.byKey(ValueKey('category-tile-$categoryId'));
  await tester.ensureVisible(tile);
  await tester.tap(
    find.descendant(of: tile, matching: find.byType(PopupMenuButton<String>)),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mover'));
  await tester.pumpAndSettle();
}

Future<void> _selectMoveDestination(WidgetTester tester, int? parentId) async {
  await tester.tap(find.byKey(const Key('choose-move-destination')));
  await tester.pumpAndSettle();
  await tester.tap(
    parentId == null
        ? find.byKey(const Key('destination-root'))
        : find.byKey(Key('destination-$parentId')),
  );
  await tester.pumpAndSettle();
}

Future<void> _moveCategoryFromManagement(
  WidgetTester tester,
  int categoryId,
  int? parentId,
) async {
  await _openMoveDialog(tester, categoryId);
  await _selectMoveDestination(tester, parentId);
  await tester.tap(find.byKey(const Key('confirm-category-move')));
  await tester.pumpAndSettle();
}

Future<void> openAddTagDialog(WidgetTester tester) async {
  final action = find.byKey(const Key('add-tag-button'));
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<void> tapRemoveFromMemoShot(WidgetTester tester) async {
  final action = find.text('Remover do MemoShot');
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<void> tapDetailAction(WidgetTester tester, String label) async {
  final action = find.text(label);
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pump();
}

class FakeOriginalMediaViewer implements OriginalMediaViewer {
  FakeOriginalMediaViewer(this.result);

  final OriginalMediaOpenResult result;
  final List<int> openedIds = [];

  @override
  Future<OriginalMediaOpenResult> open(MediaItem mediaItem) async {
    openedIds.add(mediaItem.id);
    return result;
  }
}

class FakeMediaItemRepository implements PagedMediaItemRepository {
  FakeMediaItemRepository({
    List<MediaItem> initialItems = const [],
    bool failRemoval = false,
    Map<int, String> recognizedTexts = const {},
    Map<String, Completer<List<ScreenshotSearchResult>>> searchCompleters =
        const {},
    Object? searchError,
    Object? loadError,
    bool failFilteredLoad = false,
    bool failNextPage = false,
    Set<String> rejectedPaths = const {},
  }) : this._(
         initialItems,
         failRemoval,
         recognizedTexts,
         searchCompleters,
         searchError,
         loadError,
         failFilteredLoad,
         failNextPage,
         rejectedPaths,
       );

  FakeMediaItemRepository._(
    List<MediaItem> initialItems,
    this.failRemoval,
    Map<int, String> recognizedTexts,
    this._searchCompleters,
    this._searchError,
    this._loadError,
    this._failFilteredLoad,
    this.failNextPage,
    Set<String> rejectedPaths,
  ) : _items = [...initialItems],
      _sourcePaths = initialItems
          .map((item) => item.privatePath)
          .whereType<String>()
          .toSet(),
      _rejectedPaths = {...rejectedPaths},
      _recognizedTexts = {...recognizedTexts};

  final List<MediaItem> _items;
  final Set<String> _sourcePaths;
  final Set<String> _rejectedPaths;
  final bool failRemoval;
  final Map<int, String> _recognizedTexts;
  final Map<String, Completer<List<ScreenshotSearchResult>>> _searchCompleters;
  final Object? _searchError;
  Object? _loadError;
  final bool _failFilteredLoad;
  bool failNextPage;
  Map<int, Set<int>> tagAssociations = {};
  final List<String> searchQueries = [];
  int loadCallCount = 0;
  int removeCallCount = 0;
  int searchCallCount = 0;
  final List<MediaPageRequest> pageRequests = [];
  int get itemCount => _items.length;

  @override
  Future<MediaPage<MediaItem>> loadMediaPage([
    MediaPageRequest request = const MediaPageRequest(),
  ]) async {
    pageRequests.add(request);
    if (request.cursor != null && failNextPage) {
      throw StateError('Falha privada na próxima página');
    }
    final tagId = request.tagIds.firstOrNull;
    final items = await loadAvailableItems(tagId: tagId);
    return _mediaPage(items, request);
  }

  @override
  Future<MediaPage<MediaItem>> loadMediaPageByTags(MediaPageRequest request) {
    return loadMediaPage(request);
  }

  @override
  Future<MediaPage<ScreenshotSearchResult>> searchMediaPage(
    String query, [
    MediaPageRequest request = const MediaPageRequest(),
  ]) async {
    final results = await searchRecognizedText(
      query,
      tagId: request.tagIds.firstOrNull,
    );
    final filtered = _afterCursor(
      results,
      request,
      (result) => result.mediaItem,
    );
    final visible = filtered.take(request.effectivePageSize).toList();
    return MediaPage(
      items: visible,
      nextCursor: filtered.length > visible.length && visible.isNotEmpty
          ? MediaPage.cursorFor(visible.last.mediaItem)
          : null,
    );
  }

  @override
  Future<MediaPage<ScreenshotSearchResult>> searchMediaPageByTags(
    String query,
    MediaPageRequest request,
  ) => searchMediaPage(query, request);

  @override
  Future<int> countMediaItems({Set<int> tagIds = const {}}) async {
    return (await loadAvailableItems(tagId: tagIds.firstOrNull)).length;
  }

  MediaPage<MediaItem> _mediaPage(
    List<MediaItem> items,
    MediaPageRequest request,
  ) {
    final filtered = _afterCursor(items, request, (item) => item);
    final visible = filtered.take(request.effectivePageSize).toList();
    return MediaPage(
      items: visible,
      nextCursor: filtered.length > visible.length && visible.isNotEmpty
          ? MediaPage.cursorFor(visible.last)
          : null,
    );
  }

  List<T> _afterCursor<T>(
    List<T> items,
    MediaPageRequest request,
    MediaItem Function(T item) mediaOf,
  ) {
    final cursor = request.cursor;
    if (cursor == null) return items;
    return items.where((value) {
      final item = mediaOf(value);
      final comparison = item.effectiveCapturedAt.compareTo(cursor.capturedAt);
      return comparison < 0 || (comparison == 0 && item.id < cursor.id);
    }).toList();
  }

  @override
  Future<MediaItem?> loadById(int mediaItemId) async =>
      _items.where((item) => item.id == mediaItemId).firstOrNull;

  @override
  Future<ImportResult> importScreenshots(
    List<SelectedScreenshot> screenshots, {
    ImportOrigin origin = ImportOrigin.picker,
  }) async {
    final imported = <MediaItem>[];
    var duplicateCount = 0;
    var rejectedCount = 0;
    for (final screenshot in screenshots) {
      if (_rejectedPaths.contains(screenshot.path)) {
        rejectedCount++;
        continue;
      }
      if (!_sourcePaths.add(screenshot.path)) {
        duplicateCount++;
        continue;
      }
      final item = createMediaItem(
        _items.length + 1,
        screenshot.path,
        importOrigin: origin,
        capturedAt: screenshot.capturedAt,
      );
      _items.insert(0, item);
      imported.add(item);
    }
    return ImportResult(
      importedItems: imported,
      duplicateCount: duplicateCount,
      rejectedCount: rejectedCount,
    );
  }

  @override
  Future<List<MediaItem>> loadAvailableItems({int? tagId}) async {
    loadCallCount++;
    if (_loadError != null) throw _loadError!;
    if (tagId != null && _failFilteredLoad) {
      throw StateError('Falha privada ao filtrar');
    }
    final items = tagId == null
        ? [..._items]
        : _items
              .where(
                (item) => tagAssociations[item.id]?.contains(tagId) ?? false,
              )
              .toList();
    return items..sort(compareMediaItemsRecentFirst);
  }

  @override
  Future<void> removeItem(MediaItem item) async {
    removeCallCount++;
    if (failRemoval) {
      throw StateError('Falha privada simulada');
    }
    if (item.privatePath case final path?) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }
    _items.removeWhere((candidate) => candidate.id == item.id);
    _recognizedTexts.remove(item.id);
  }

  @override
  Future<List<ScreenshotSearchResult>> searchRecognizedText(
    String query, {
    int? tagId,
    int limit = 100,
  }) async {
    const normalizer = TextNormalizer();
    const snippetBuilder = SearchSnippetBuilder();
    final normalizedQuery = normalizer.normalize(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }
    searchCallCount++;
    searchQueries.add(normalizedQuery);
    if (_searchError != null) {
      throw _searchError;
    }
    final controlled =
        _searchCompleters['${tagId ?? 'all'}:$normalizedQuery'] ??
        _searchCompleters[normalizedQuery];
    if (controlled != null) {
      return controlled.future;
    }
    final results = <ScreenshotSearchResult>[];
    for (final item in _items) {
      final text = _recognizedTexts[item.id];
      if (text != null &&
          (tagId == null ||
              (tagAssociations[item.id]?.contains(tagId) ?? false)) &&
          normalizer.normalize(text).contains(normalizedQuery) &&
          (item.privatePath == null || File(item.privatePath!).existsSync())) {
        results.add(
          ScreenshotSearchResult(
            mediaItem: item,
            snippet: snippetBuilder.build(text, query),
          ),
        );
      }
    }
    results.sort(
      (first, second) =>
          compareMediaItemsRecentFirst(first.mediaItem, second.mediaItem),
    );
    return results.take(limit).toList(growable: false);
  }

  void setRecognizedText(int mediaItemId, String text) {
    _recognizedTexts[mediaItemId] = text;
  }

  @override
  Future<void> close() async {}
}

class FakeOcrRepository implements OcrRepository {
  FakeOcrRepository({
    Map<int, OcrResult> initialResults = const {},
    this.texts = const [],
    this.error,
    this.processCompleter,
  }) : _results = {...initialResults};

  final Map<int, OcrResult> _results;
  final List<String> texts;
  final Object? error;
  final Completer<OcrResult>? processCompleter;
  int processCallCount = 0;

  @override
  Future<OcrResult?> loadFor(int mediaItemId) async => _results[mediaItemId];

  @override
  Future<OcrResult> process(MediaItem mediaItem) async {
    processCallCount++;
    if (error != null) {
      throw error!;
    }
    if (processCompleter != null) {
      final completed = await processCompleter!.future;
      _results[mediaItem.id] = completed;
      return completed;
    }
    final result = OcrResult(
      mediaItemId: mediaItem.id,
      fullText: texts[processCallCount - 1],
      engine: 'Serviço falso',
      engineVersion: 'teste',
      processedAt: DateTime(2026),
    );
    _results[mediaItem.id] = result;
    return result;
  }
}

class FakeOcrQueue implements OcrQueue {
  FakeOcrQueue(
    this._repository, {
    Map<int, OcrItemState> initialStates = const {},
    this.recoveryCompleter,
  }) : _states = {...initialStates};

  final FakeOcrRepository _repository;
  final Map<int, OcrItemState> _states;
  final Completer<void>? recoveryCompleter;
  final StreamController<int> _changes = StreamController<int>.broadcast();
  int retryCallCount = 0;

  @override
  Stream<int> get changes => _changes.stream;

  @override
  Future<OcrItemState> loadState(int mediaItemId) async {
    final explicit = _states[mediaItemId];
    if (explicit != null) {
      return explicit;
    }
    final result = await _repository.loadFor(mediaItemId);
    if (result == null) {
      return OcrItemState.notScheduled;
    }
    return result.fullText.isEmpty
        ? OcrItemState.completedWithoutText
        : OcrItemState.completedWithText;
  }

  @override
  Future<void> recoverAndStart() async {
    await recoveryCompleter?.future;
  }

  @override
  Future<void> retry(MediaItem mediaItem) async {
    final current = await loadState(mediaItem.id);
    if (current == OcrItemState.pending || current == OcrItemState.processing) {
      return;
    }
    retryCallCount++;
    _setState(mediaItem.id, OcrItemState.pending);
    unawaited(_run(mediaItem));
  }

  Future<void> _run(MediaItem mediaItem) async {
    _setState(mediaItem.id, OcrItemState.processing);
    try {
      final result = await _repository.process(mediaItem);
      _setState(
        mediaItem.id,
        result.fullText.isEmpty
            ? OcrItemState.completedWithoutText
            : OcrItemState.completedWithText,
      );
    } catch (_) {
      _setState(mediaItem.id, OcrItemState.failed);
    }
  }

  void _setState(int mediaItemId, OcrItemState state) {
    _states[mediaItemId] = state;
    if (!_changes.isClosed) {
      _changes.add(mediaItemId);
    }
  }

  void emitState(int mediaItemId, OcrItemState state) {
    _setState(mediaItemId, state);
  }

  @override
  void signal() {}

  @override
  Future<void> close() => _changes.close();
}

class FakeClassificationQueue implements ClassificationQueue {
  final StreamController<int> _changes = StreamController<int>.broadcast();

  @override
  Stream<int> get changes => _changes.stream;

  void emit(int mediaItemId) => _changes.add(mediaItemId);

  @override
  Future<void> recoverAndStart() async {}

  @override
  void signal() {}

  @override
  Future<void> close() => _changes.close();
}

class FakeReprocessingClassificationQueue extends FakeClassificationQueue
    implements IndividualClassificationReprocessor {
  FakeReprocessingClassificationQueue({
    this.status = IndividualReprocessStatus.applied,
  });

  final IndividualReprocessStatus status;
  final List<int> reprocessedIds = [];

  @override
  Future<IndividualReprocessResult> reprocess(MediaItem mediaItem) async {
    reprocessedIds.add(mediaItem.id);
    return IndividualReprocessResult(status);
  }
}

MediaItem createMediaItem(
  int id,
  String path, {
  DateTime? importedAt,
  ImportOrigin importOrigin = ImportOrigin.picker,
  DateTime? capturedAt,
}) {
  return MediaItem(
    id: id,
    privatePath: path,
    internalName: 'screenshot_$id.png',
    mimeType: 'image/png',
    mediaHash: 'hash-secreto',
    importedAt: importedAt ?? DateTime(2026),
    capturedAt: capturedAt,
    sourceMode: 'photoPicker',
    status: 'ready',
    importOrigin: importOrigin,
  );
}

MediaItem createReferencedMediaItem(int id) => MediaItem(
  id: id,
  location: MediaStoreReferenceLocation(
    sourceKey: 'external_primary:$id',
    mediaStoreId: id,
    volumeName: 'external_primary',
    contentUri: 'content://media/external_primary/images/media/$id',
  ),
  mimeType: 'image/png',
  importedAt: DateTime(2026),
  sourceMode: 'mediaStoreReference',
  status: 'ready',
  importOrigin: ImportOrigin.picker,
);

class _UnavailableMediaStoreGateway implements MediaStoreContentGateway {
  @override
  Future<ReferencedMediaAvailability> checkAvailability(
    MediaStoreReferenceLocation location,
  ) async => ReferencedMediaAvailability.unavailable;

  @override
  Future<ReferencedMediaThumbnail> loadThumbnail(
    MediaStoreReferenceLocation location,
  ) async => const ReferencedMediaThumbnail(
    availability: ReferencedMediaAvailability.unavailable,
  );
}

int compareMediaItemsRecentFirst(MediaItem first, MediaItem second) {
  final byCapture = second.effectiveCapturedAt.compareTo(
    first.effectiveCapturedAt,
  );
  if (byCapture != 0) return byCapture;
  final byImport = second.importedAt.compareTo(first.importedAt);
  if (byImport != 0) return byImport;
  return second.id.compareTo(first.id);
}

OcrResult createOcrResult(int mediaItemId, String text) {
  return OcrResult(
    mediaItemId: mediaItemId,
    fullText: text,
    engine: 'Serviço falso',
    engineVersion: 'teste',
    processedAt: DateTime(2026),
  );
}

class FakeScreenshotPicker implements ScreenshotPicker {
  FakeScreenshotPicker({
    this.selections = const [],
    this.lostSelections = const [],
    this.pickCompleter,
    this.error,
  });

  final List<SelectedScreenshot> selections;
  final List<SelectedScreenshot> lostSelections;
  final Completer<List<SelectedScreenshot>>? pickCompleter;
  final Object? error;
  int pickCallCount = 0;
  int retrieveCallCount = 0;

  @override
  Future<List<SelectedScreenshot>> pickScreenshots() async {
    pickCallCount++;
    if (error != null) {
      throw error!;
    }
    return pickCompleter?.future ?? selections;
  }

  @override
  Future<List<SelectedScreenshot>> retrieveLostScreenshots() async {
    retrieveCallCount++;
    return lostSelections;
  }
}

File createTestImage(Directory directory, String name) {
  const minimalPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
  return File('${directory.path}/$name')
    ..writeAsBytesSync(base64Decode(minimalPng));
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contexto/app/contexto_app.dart';
import 'package:contexto/core/media/screenshot_picker.dart';
import 'package:contexto/core/sharing/incoming_share_source.dart';
import 'package:contexto/core/theme/app_theme.dart';
import 'package:contexto/core/text/search_snippet_builder.dart';
import 'package:contexto/core/text/text_normalizer.dart';
import 'package:contexto/features/categories/data/category_repository.dart';
import 'package:contexto/features/categories/domain/category.dart';
import 'package:contexto/features/library/data/media_item_repository.dart';
import 'package:contexto/features/library/domain/media_item.dart';
import 'package:contexto/features/library/domain/selected_screenshot.dart';
import 'package:contexto/features/library/domain/screenshot_search_result.dart';
import 'package:contexto/features/ocr/data/ocr_repository.dart';
import 'package:contexto/features/ocr/domain/ocr_result.dart';
import 'package:contexto/features/processing/data/ocr_queue_processor.dart';
import 'package:contexto/features/processing/domain/processing_job.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'contexto_widget_test_',
    );
  });

  tearDown(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    temporaryDirectory.deleteSync(recursive: true);
  });

  testWidgets('exibe a tela inicial funcional do Contexto', (tester) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pump();

    expect(find.text('Contexto'), findsOneWidget);
    expect(find.text('Organização inteligente'), findsOneWidget);
    expect(find.text('Organize e encontre seus prints'), findsOneWidget);
    expect(find.text('Pesquisar screenshots'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Recentes'), findsOneWidget);
    expect(find.text('0 itens'), findsOneWidget);
    expect(find.text('Categorias'), findsOneWidget);
    expect(find.text('0 categorias'), findsOneWidget);
    expect(find.text('Importar screenshots'), findsOneWidget);
    expect(find.text('Processamento local'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('habilita importação e pesquisa local', (tester) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pump();

    final searchField = tester.widget<TextField>(find.byType(TextField));
    final importButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Selecionar imagens'),
    );

    expect(searchField.enabled, isTrue);
    expect(searchField.textInputAction, TextInputAction.search);
    expect(importButton.onPressed, isNotNull);
  });

  testWidgets('cancelar seleção não altera a biblioteca', (tester) async {
    final picker = FakeScreenshotPicker();
    await tester.pumpWidget(buildTestApp(picker));
    await tester.pump();

    await tester.tap(find.text('Selecionar imagens'));
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

    await tester.tap(find.text('Selecionar imagens'));
    await tester.pump();

    expect(find.text('1 item'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Salvo neste dispositivo.'), findsOneWidget);
    expect(find.text('0 categorias'), findsOneWidget);
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

    await tester.tap(find.text('Selecionar imagens'));
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

    await tester.tap(find.text('Selecionar imagens'));
    await tester.pump();
    expect(find.text('Este screenshot já está na biblioteca.'), findsOneWidget);
    await tester.tap(find.text('Selecionar imagens'));
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

    await tester.tap(find.text('Selecionar imagens'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);

    completer.complete(const []);
    await tester.pump();
    expect(find.text('Selecionar imagens'), findsOneWidget);
  });

  testWidgets('exibe mensagem discreta quando a seleção falha', (tester) async {
    final picker = FakeScreenshotPicker(error: Exception('falha privada'));
    await tester.pumpWidget(buildTestApp(picker));
    await tester.pump();

    await tester.tap(find.text('Selecionar imagens'));
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
        createMediaItem(1, image.path, importedAt: DateTime(2026, 1, 2, 3, 4)),
      ],
    );
    await tester.pumpWidget(
      buildTestApp(FakeScreenshotPicker(), repository: repository),
    );
    await tester.pump();

    await openFirstScreenshot(tester);

    expect(find.text('Detalhes do screenshot'), findsOneWidget);
    expect(find.text('02 de janeiro de 2026, às 03:04'), findsOneWidget);
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
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
  });

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

    await tapRemoveFromContexto(tester);
    expect(find.text('Remover do Contexto?'), findsOneWidget);
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

    await tapRemoveFromContexto(tester);
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
    expect(find.text('Biblioteca'), findsOneWidget);
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
    await tapRemoveFromContexto(tester);
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

  testWidgets('Home mostra todos os estados persistentes de OCR', (
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

    expect(find.text('Aguardando'), findsOneWidget);
    expect(find.text('Processando'), findsOneWidget);
    expect(find.text('Texto extraído'), findsOneWidget);
    expect(find.text('Sem texto'), findsOneWidget);
    expect(find.text('Falha'), findsOneWidget);
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

    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Selecionar imagens'), findsOneWidget);
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
    expect(find.text('Nenhum screenshot encontrado.'), findsOneWidget);
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
    expect(find.text('Nenhum screenshot encontrado.'), findsOneWidget);

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

    await tester.tap(find.text('Selecionar imagens'));
    await tester.pump();
    expect(find.text('Nenhum screenshot encontrado.'), findsOneWidget);

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

    await tapRemoveFromContexto(tester);
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(find.text('0 resultados para “termo”'), findsOneWidget);
    expect(find.text('Nenhum screenshot encontrado.'), findsOneWidget);
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
    expect(find.text('Processamento local'), findsOneWidget);
  });

  testWidgets('bloco Categorias abre tela com estado vazio', (tester) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pump();

    expect(find.text('0 categorias'), findsOneWidget);
    await tester.tap(find.byKey(const Key('categories-summary')));
    await tester.pumpAndSettle();

    expect(find.text('Categorias'), findsOneWidget);
    expect(find.text('Nenhuma categoria criada.'), findsOneWidget);
    expect(find.text('Nova categoria'), findsOneWidget);
  });

  testWidgets('criar categoria atualiza lista e contador da Home', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
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
    expect(find.text('0 screenshots'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 categoria'), findsOneWidget);
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
    expect(find.text('Essa categoria já existe.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byKey(const Key('save-category-button')));
    await tester.pump();
    expect(find.text('Informe um nome para a categoria.'), findsOneWidget);
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
    expect(find.text('Nenhum screenshot nesta categoria.'), findsOneWidget);
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

    expect(find.text('1 screenshot'), findsOneWidget);
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

    expect(find.text('0 screenshots'), findsOneWidget);
    expect(find.text('Nenhum screenshot nesta categoria.'), findsOneWidget);
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

    expect(find.text('Nenhum screenshot nesta categoria.'), findsOneWidget);
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
    await tapRemoveFromContexto(tester);
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum screenshot nesta categoria.'), findsOneWidget);
    expect(find.text('0 screenshots'), findsOneWidget);
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
    expect(find.text('Essa categoria já existe.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('rename-category-field')),
      'Projetos',
    );
    await tester.tap(find.byKey(const Key('save-category-rename')));
    await tester.pumpAndSettle();
    expect(find.text('Projetos'), findsOneWidget);
    expect(find.text(first.name), findsNothing);
  });

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
    await tester.tap(find.text('Excluir categoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Manter'), findsOneWidget);
    expect(media.itemCount, 1);
    expect(image.existsSync(), isTrue);
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
    await tester.tap(find.text('Excluir categoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-category-deletion')));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma categoria criada.'), findsOneWidget);
    expect(media.itemCount, 1);
    expect(image.existsSync(), isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('0 categorias'), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-tile-1')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('screenshot-tile-1')));
    await tester.tap(find.byKey(const ValueKey('screenshot-tile-1')));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma categoria atribuída.'), findsOneWidget);
  });

  testWidgets('observação sobre o menu Compartilhar aparece na importação', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(FakeScreenshotPicker()));
    await tester.pump();

    expect(
      find.text('Você também pode enviar imagens pelo menu Compartilhar.'),
      findsOneWidget,
    );
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
      expect(find.text('Screenshot adicionado ao Contexto.'), findsOneWidget);
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
    expect(find.text('2 screenshots adicionados ao Contexto.'), findsOneWidget);
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

    expect(find.text('Esta imagem já estava no Contexto.'), findsOneWidget);
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
      find.text('1 imagem adicionada e 1 já estava no Contexto.'),
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
    expect(find.text('Compartilhado com o Contexto'), findsOneWidget);
  });
}

Widget buildTestApp(
  ScreenshotPicker picker, {
  FakeMediaItemRepository? repository,
  FakeOcrRepository? ocrRepository,
  FakeOcrQueue? ocrQueue,
  FakeCategoryRepository? categoryRepository,
  IncomingShareSource? incomingShareSource,
}) {
  final resolvedOcrRepository = ocrRepository ?? FakeOcrRepository();
  final resolvedMediaRepository = repository ?? FakeMediaItemRepository();
  final resolvedCategoryRepository =
      categoryRepository ?? FakeCategoryRepository();
  resolvedCategoryRepository.mediaItems = resolvedMediaRepository._items;
  return ContextoApp(
    screenshotPicker: picker,
    mediaRepository: resolvedMediaRepository,
    ocrRepository: resolvedOcrRepository,
    ocrQueue: ocrQueue ?? FakeOcrQueue(resolvedOcrRepository),
    categoryRepository: resolvedCategoryRepository,
    incomingShareSource: incomingShareSource ?? FakeIncomingShareSource(),
  );
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

  @override
  Future<Category> createCategory(String name) async {
    final visible = name.trim();
    const normalizer = TextNormalizer();
    final normalized = normalizer.normalize(visible);
    if (normalized.isEmpty) {
      throw const CategoryValidationException(CategoryValidationError.empty);
    }
    if (visible.length > 40) {
      throw const CategoryValidationException(CategoryValidationError.tooLong);
    }
    if (_categories.any((category) => category.normalizedName == normalized)) {
      throw const CategoryValidationException(
        CategoryValidationError.duplicate,
      );
    }
    final category = Category(
      id: _categories.length + 1,
      name: visible,
      normalizedName: normalized,
      createdAt: DateTime(2025),
    );
    _categories.add(category);
    return category;
  }

  @override
  Future<List<CategorySummary>> loadCategories() async {
    final existingMediaIds = mediaItems.map((item) => item.id).toSet();
    return [
      for (final category in _categories)
        CategorySummary(
          category: category,
          mediaCount: _associations.entries
              .where(
                (entry) =>
                    existingMediaIds.contains(entry.key) &&
                    entry.value.contains(category.id),
              )
              .length,
        ),
    ];
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
      (item) => item.id != category.id && item.normalizedName == normalized,
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
    );
    final index = _categories.indexWhere((item) => item.id == category.id);
    _categories[index] = renamed;
    return renamed;
  }

  @override
  Future<void> deleteCategory(int categoryId) async {
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
              mediaIds.contains(item.id) && File(item.privatePath).existsSync(),
        )
        .toList()
      ..sort((first, second) => second.importedAt.compareTo(first.importedAt));
  }

  List<MediaItem> mediaItems = [];
}

Future<void> openFirstScreenshot(WidgetTester tester) async {
  final tile = find.byKey(const ValueKey('screenshot-tile-1'));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> tapRemoveFromContexto(WidgetTester tester) async {
  final action = find.text('Remover do Contexto');
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

class FakeMediaItemRepository implements MediaItemRepository {
  FakeMediaItemRepository({
    List<MediaItem> initialItems = const [],
    bool failRemoval = false,
    Map<int, String> recognizedTexts = const {},
    Map<String, Completer<List<ScreenshotSearchResult>>> searchCompleters =
        const {},
    Object? searchError,
    Set<String> rejectedPaths = const {},
  }) : this._(
         initialItems,
         failRemoval,
         recognizedTexts,
         searchCompleters,
         searchError,
         rejectedPaths,
       );

  FakeMediaItemRepository._(
    List<MediaItem> initialItems,
    this.failRemoval,
    Map<int, String> recognizedTexts,
    this._searchCompleters,
    this._searchError,
    Set<String> rejectedPaths,
  ) : _items = [...initialItems],
      _sourcePaths = {for (final item in initialItems) item.privatePath},
      _rejectedPaths = {...rejectedPaths},
      _recognizedTexts = {...recognizedTexts};

  final List<MediaItem> _items;
  final Set<String> _sourcePaths;
  final Set<String> _rejectedPaths;
  final bool failRemoval;
  final Map<int, String> _recognizedTexts;
  final Map<String, Completer<List<ScreenshotSearchResult>>> _searchCompleters;
  final Object? _searchError;
  final List<String> searchQueries = [];
  int loadCallCount = 0;
  int removeCallCount = 0;
  int searchCallCount = 0;
  int get itemCount => _items.length;

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
  Future<List<MediaItem>> loadAvailableItems() async {
    loadCallCount++;
    return [..._items];
  }

  @override
  Future<void> removeItem(MediaItem item) async {
    removeCallCount++;
    if (failRemoval) {
      throw StateError('Falha privada simulada');
    }
    final file = File(item.privatePath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    _items.removeWhere((candidate) => candidate.id == item.id);
    _recognizedTexts.remove(item.id);
  }

  @override
  Future<List<ScreenshotSearchResult>> searchRecognizedText(
    String query, {
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
    final controlled = _searchCompleters[normalizedQuery];
    if (controlled != null) {
      return controlled.future;
    }
    final results = <ScreenshotSearchResult>[];
    for (final item in _items) {
      final text = _recognizedTexts[item.id];
      if (text != null &&
          normalizer.normalize(text).contains(normalizedQuery) &&
          File(item.privatePath).existsSync()) {
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
          second.mediaItem.importedAt.compareTo(first.mediaItem.importedAt),
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

MediaItem createMediaItem(
  int id,
  String path, {
  DateTime? importedAt,
  ImportOrigin importOrigin = ImportOrigin.picker,
}) {
  return MediaItem(
    id: id,
    privatePath: path,
    internalName: 'screenshot_$id.png',
    mimeType: 'image/png',
    mediaHash: 'hash-secreto',
    importedAt: importedAt ?? DateTime(2026),
    sourceMode: 'photoPicker',
    status: 'ready',
    importOrigin: importOrigin,
  );
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

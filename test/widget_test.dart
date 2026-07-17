import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contexto/app/contexto_app.dart';
import 'package:contexto/core/media/screenshot_picker.dart';
import 'package:contexto/core/theme/app_theme.dart';
import 'package:contexto/features/library/domain/selected_screenshot.dart';
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
    await tester.pumpWidget(
      ContextoApp(screenshotPicker: FakeScreenshotPicker()),
    );
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

  testWidgets('habilita importação e mantém pesquisa desabilitada', (
    tester,
  ) async {
    await tester.pumpWidget(
      ContextoApp(screenshotPicker: FakeScreenshotPicker()),
    );
    await tester.pump();

    final searchField = tester.widget<TextField>(find.byType(TextField));
    final importButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Selecionar imagens'),
    );

    expect(searchField.enabled, isFalse);
    expect(importButton.onPressed, isNotNull);
  });

  testWidgets('cancelar seleção não altera a biblioteca', (tester) async {
    final picker = FakeScreenshotPicker();
    await tester.pumpWidget(ContextoApp(screenshotPicker: picker));
    await tester.pump();

    await tester.tap(find.text('Selecionar imagens'));
    await tester.pump();

    expect(picker.pickCallCount, 1);
    expect(find.text('0 itens'), findsOneWidget);
    expect(find.byKey(const Key('session-screenshot-grid')), findsNothing);
  });

  testWidgets('mostra uma imagem selecionada e atualiza o contador', (
    tester,
  ) async {
    final image = createTestImage(temporaryDirectory, 'uma.png');
    final picker = FakeScreenshotPicker(
      selections: [SelectedScreenshot(path: image.path)],
    );
    await tester.pumpWidget(ContextoApp(screenshotPicker: picker));
    await tester.pump();

    await tester.tap(find.text('Selecionar imagens'));
    await tester.pump();

    expect(find.text('1 item'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('somente nesta sessão'), findsOneWidget);
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
    await tester.pumpWidget(ContextoApp(screenshotPicker: picker));
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
    await tester.pumpWidget(ContextoApp(screenshotPicker: picker));
    await tester.pump();

    await tester.tap(find.text('Selecionar imagens'));
    await tester.pump();
    await tester.tap(find.text('Selecionar imagens'));
    await tester.pump();

    expect(find.text('1 item'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('exibe carregamento enquanto o seletor processa', (tester) async {
    final completer = Completer<List<SelectedScreenshot>>();
    final picker = FakeScreenshotPicker(pickCompleter: completer);
    await tester.pumpWidget(ContextoApp(screenshotPicker: picker));
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
    await tester.pumpWidget(ContextoApp(screenshotPicker: picker));
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

    await tester.pumpWidget(ContextoApp(screenshotPicker: picker));
    await tester.pump();

    expect(picker.retrieveCallCount, 1);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('mantém o tema claro com brilho de plataforma escuro', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      ContextoApp(screenshotPicker: FakeScreenshotPicker()),
    );
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

    await tester.pumpWidget(
      ContextoApp(screenshotPicker: FakeScreenshotPicker()),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Processamento local'), findsOneWidget);
  });
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

import 'package:contexto/app/contexto_app.dart';
import 'package:contexto/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exibe a tela inicial funcional do Contexto', (tester) async {
    await tester.pumpWidget(const ContextoApp());

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

  testWidgets('mantém pesquisa, importação e configurações indisponíveis', (
    tester,
  ) async {
    await tester.pumpWidget(const ContextoApp());

    final searchField = tester.widget<TextField>(find.byType(TextField));
    final importButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Selecionar imagens'),
    );
    final settingsButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.settings_outlined),
    );

    expect(searchField.enabled, isFalse);
    expect(importButton.onPressed, isNull);
    expect(settingsButton.onPressed, isNull);
  });

  testWidgets('mantém o tema claro com brilho de plataforma escuro', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const ContextoApp());

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

    await tester.pumpWidget(const ContextoApp());

    expect(tester.takeException(), isNull);
    expect(find.text('Processamento local'), findsOneWidget);
  });
}

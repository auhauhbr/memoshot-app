import 'package:contexto/core/text/search_snippet_builder.dart';
import 'package:contexto/core/text/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const normalizer = TextNormalizer();

  test('normaliza maiúsculas, acentos e cedilha', () {
    expect(normalizer.normalize('AÇÃO, Código e João'), 'acao, codigo e joao');
  });

  test('normaliza espaços repetidos e quebras de linha', () {
    expect(
      normalizer.normalize('  uma\n\t consulta   local  '),
      'uma consulta local',
    );
  });

  test('trata consulta vazia ou somente com espaços como vazia', () {
    expect(normalizer.normalize(''), isEmpty);
    expect(normalizer.normalize(' \n\t  '), isEmpty);
  });

  test('mantém texto já normalizado', () {
    expect(
      normalizer.normalize('texto ja normalizado'),
      'texto ja normalizado',
    );
  });

  test('preserva números e símbolos relevantes', () {
    expect(normalizer.normalize('RTX  4050'), 'rtx 4050');
    expect(normalizer.normalize(r'R$  180'), r'r$ 180');
  });

  test('remove marcas diacríticas combinantes', () {
    expect(normalizer.normalize('Jo\u0061\u0303o'), 'joao');
  });

  test(
    'gera trecho curto ao redor da correspondência usando texto original',
    () {
      const builder = SearchSnippetBuilder(maxLength: 55);
      final snippet = builder.build(
        'Este início é longo e sem relevância antes do código promocional '
            'especial que deve aparecer no trecho final.',
        'codigo',
      );

      expect(snippet, contains('código'));
      expect(snippet.length, lessThanOrEqualTo(57));
      expect(snippet, isNot(contains('codigo')));
    },
  );
}

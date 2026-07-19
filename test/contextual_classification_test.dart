import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/visual/local_visual_analyzer.dart';
import 'package:memoshot/features/classification/domain/contextual_classification.dart';

void main() {
  const engine = ContextualClassificationEngine();

  group('origem provável', () {
    final cases = <String, ProbableOrigin>{
      'amazon.com.br teclado comprar': ProbableOrigin.amazon,
      'mercadolivre.com produto frete': ProbableOrigin.mercadoLivre,
      'mercadopago.com pagamento realizado': ProbableOrigin.mercadoPago,
      'linkedin.com vaga recrutador': ProbableOrigin.linkedIn,
      'github.com pull request flutter': ProbableOrigin.gitHub,
      'instagram.com seguidores reels': ProbableOrigin.instagram,
      'WhatsApp online digite uma mensagem': ProbableOrigin.whatsapp,
      'Chrome exemplo.com produto': ProbableOrigin.browser,
    };
    for (final entry in cases.entries) {
      test(entry.value.name, () {
        expect(engine.classify(ocrText: entry.key).origin.value, entry.value);
      });
    }

    test('palavra genérica não decide origem', () {
      expect(
        engine.classify(ocrText: 'comprar uma lembrança').origin.value,
        ProbableOrigin.unknown,
      );
    });
  });

  test('relógio isolado permanece no OCR mas não gera Horário ou Eventos', () {
    const text = '16:20';
    final result = engine.classify(ocrText: text);

    expect(text, contains('16:20'));
    expect(result.signals.hasTime, isTrue);
    expect(result.signals.hasContextualTime, isFalse);
    expect(
      result.destination.tags.map((tag) => tag.name),
      isNot(contains('Horário')),
    );
    expect(result.destination.root, isNull);
  });

  test('horário de entrevista e de partida é contextual', () {
    expect(
      engine
          .classify(ocrText: 'Entrevista dia 20/07 às 16:20')
          .signals
          .hasContextualTime,
      isTrue,
    );
    expect(
      engine
          .classify(ocrText: 'Partida da copa às 16:20 placar 2 x 1')
          .signals
          .hasContextualTime,
      isTrue,
    );
  });

  test('preço de produto não significa pagamento', () {
    final result = engine.classify(
      ocrText: 'amazon.com.br teclado mecânico R\$ 259,90 comprar carrinho',
    );

    expect(result.destination.root, 'Produtos');
    expect(result.signals.hasProductPrice, isTrue);
    expect(result.signals.hasTransactionEvidence, isFalse);
    expect(result.destination.tags.map((tag) => tag.name), contains('Produto'));
    expect(
      result.destination.tags.map((tag) => tag.name),
      isNot(contains('Pagamento')),
    );
  });

  test('comprovante Pix possui evidência real de transação', () {
    final result = engine.classify(
      ocrText:
          'Comprovante Pix enviado pagamento realizado favorecido autenticação R\$ 90,00',
    );

    expect(result.destination.persistedName, 'Documentos / Comprovantes');
    expect(result.signals.hasTransactionEvidence, isTrue);
    expect(
      result.destination.tags.map((tag) => tag.name),
      containsAll(['Comprovante', 'Pagamento']),
    );
  });

  group('casos contextuais', () {
    test('livro na Amazon prioriza assunto sobre origem', () {
      final result = engine.classify(
        ocrText:
            'amazon.com.br livro capa comum autor editora R\$ 25,93 comprar',
        visualAnalysis: _visual('book'),
      );
      expect(result.destination.persistedName, 'Livros / Capas');
      expect(result.origin.value, ProbableOrigin.amazon);
      expect(
        result.destination.tags.map((tag) => tag.name),
        containsAll(['Amazon', 'Livro']),
      );
      expect(
        result.destination.tags.map((tag) => tag.name),
        isNot(contains('Pagamento')),
      );
    });

    test('curso em conversa vai para Estudos', () {
      final result = engine.classify(
        ocrText:
            'WhatsApp online mensagem curso aula módulo videoaula responder',
      );
      expect(result.destination.persistedName, 'Estudos / Cursos');
      expect(result.origin.value, ProbableOrigin.whatsapp);
    });

    test('capa recebida no WhatsApp continua sendo Livro', () {
      final result = engine.classify(
        ocrText: 'WhatsApp online mensagem livro autor editora',
        visualAnalysis: _visual('book'),
      );
      expect(result.destination.persistedName, 'Livros / Capas');
      expect(result.origin.value, ProbableOrigin.whatsapp);
    });

    test('vaga LinkedIn', () {
      expect(
        engine
            .classify(ocrText: 'linkedin.com vaga recrutador processo seletivo')
            .destination
            .persistedName,
        'Carreira / Vagas',
      );
    });

    test('teclado e carro em resultado do Google continuam Produtos', () {
      final keyboard = engine.classify(
        ocrText: 'google.com/search teclado mecânico modelo preço comprar',
      );
      final car = engine.classify(
        ocrText: 'resultados da pesquisa carro modelo preço oferta',
      );
      expect(keyboard.destination.root, 'Produtos');
      expect(
        keyboard.destination.tags.map((tag) => tag.name),
        contains('Teclado'),
      );
      expect(car.destination.root, 'Produtos');
      expect(car.destination.tags.map((tag) => tag.name), contains('Carro'));
      expect(keyboard.origin.value, ProbableOrigin.browser);
    });

    test('código e documento usam somente catálogo oficial', () {
      expect(
        engine
            .classify(ocrText: 'Flutter exception stack trace código')
            .destination
            .persistedName,
        'Desenvolvimento / Erros',
      );
      expect(
        engine
            .classify(ocrText: 'Documento contrato protocolo CPF')
            .destination
            .root,
        'Documentos',
      );
    });

    test('tabela de futebol', () {
      final result = engine.classify(
        ocrText: 'Copa campeonato partida placar Brasil 2 x 1 tabela',
      );
      expect(result.destination.root, 'Esportes');
      expect(
        result.destination.tags.map((tag) => tag.name),
        containsAll(['Tabela', 'Futebol']),
      );
    });

    test('imagem sem texto e label genérico não cria pasta', () {
      final result = engine.classify(
        ocrText: '',
        visualAnalysis: _visual('screenshot'),
      );
      expect(result.destination.root, isNull);
      expect(result.destination.tags, isEmpty);
    });
  });

  test('catálogo limita profundidade, nomes e etiquetas', () {
    expect(ContextualFolderCatalog.parse('Livros / Capas'), (
      'Livros',
      'Capas',
    ));
    expect(ContextualFolderCatalog.parse('Livros / Capas / Autor'), isNull);
    expect(ContextualFolderCatalog.parse('Amazon / Produtos'), isNull);
    expect(ContextualTagCatalog.contains('font'), isFalse);
    final result = engine.classify(
      ocrText:
          'amazon.com.br produto teclado notebook carro comprar carrinho preço',
    );
    expect(
      result.destination.tags.length,
      lessThanOrEqualTo(maximumContextualTags),
    );
  });
}

VisualAnalysisResult _visual(String key) => VisualAnalysisResult(
  labels: [VisualLabel(key: key, confidence: 0.95)],
  analyzerVersion: 'test',
);

import 'package:memoshot/features/classification/domain/classification_models.dart';
import 'package:memoshot/features/classification/domain/local_classification_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = LocalClassificationEngine();

  group('entradas sem sinais', () {
    test('texto vazio não produz sugestão', () {
      final result = engine.classify(const ClassificationInput(ocrText: ''));

      expect(result.hasSuggestion, isFalse);
      expect(result.suggestedCategoryName, isNull);
      expect(result.suggestedTags, isEmpty);
      expect(result.confidence, 0);
      expect(result.evidence, isEmpty);
    });

    test('texto somente com espaços não produz sugestão', () {
      final result = engine.classify(
        const ClassificationInput(ocrText: '  \n\t  '),
      );

      expect(result.hasSuggestion, isFalse);
    });

    test('texto curto sem sinal relevante não produz sugestão', () {
      final result = engine.classify(
        const ClassificationInput(ocrText: 'Olá!'),
      );

      expect(result.hasSuggestion, isFalse);
    });
  });

  group('categorias iniciais', () {
    test('sugere Carreira para entrevista com recrutadora', () {
      final result = classify(
        engine,
        'A recrutadora enviou uma vaga e marcou entrevista pelo WhatsApp.',
      );

      expect(result.suggestedCategoryName, 'Carreira');
      expect(tagNames(result), containsAll(['Entrevista', 'Vaga', 'WhatsApp']));
    });

    test('sugere Estudos para aula, curso e prova', () {
      final result = classify(
        engine,
        'Aula do curso da faculdade com exercício para a prova.',
      );

      expect(result.suggestedCategoryName, 'Estudos');
      expect(tagNames(result), contains('Curso'));
    });

    test('sugere Compras para produto com preço e desconto', () {
      final result = classify(
        engine,
        'Produto no carrinho com preço promocional e desconto no frete.',
      );

      expect(result.suggestedCategoryName, 'Compras');
      expect(tagNames(result), containsAll(['Produto', 'Promoção']));
    });

    test('sugere Finanças para comprovante de Pix', () {
      final result = classify(
        engine,
        'Comprovante de pagamento Pix, transferência concluída e saldo atual.',
      );

      expect(result.suggestedCategoryName, 'Finanças');
      expect(tagNames(result), containsAll(['Pagamento', 'Documento']));
    });

    test('sugere Conversas para mensagem de WhatsApp', () {
      final result = classify(
        engine,
        'WhatsApp: nova mensagem de áudio. Preciso responder a conversa.',
      );

      expect(result.suggestedCategoryName, 'Conversas');
      expect(tagNames(result), containsAll(['WhatsApp', 'Precisa responder']));
    });

    test('sugere Desenvolvimento para erro Flutter no terminal', () {
      final result = classify(
        engine,
        'Flutter exception no terminal: erro ao executar o código da API.',
      );

      expect(result.suggestedCategoryName, 'Desenvolvimento');
      expect(tagNames(result), containsAll(['Código', 'Erro']));
    });

    test('sugere Documentos para contrato e assinatura', () {
      final result = classify(
        engine,
        'Documento: contrato aguardando assinatura e número de protocolo.',
      );

      expect(result.suggestedCategoryName, 'Documentos');
      expect(tagNames(result), contains('Documento'));
    });

    test('sugere Viagens para reserva de hotel', () {
      final result = classify(
        engine,
        'Reserva de hotel confirmada. Check-in antes do voo e embarque.',
      );

      expect(result.suggestedCategoryName, 'Viagens');
    });

    test('múltiplos sinais reforçam a confiança da categoria', () {
      final single = classify(engine, 'Entrevista agendada.');
      final reinforced = classify(
        engine,
        'Entrevista da vaga com recrutadora durante processo seletivo.',
      );

      expect(single.suggestedCategoryName, 'Carreira');
      expect(reinforced.suggestedCategoryName, 'Carreira');
      expect(reinforced.confidence, greaterThan(single.confidence));
    });
  });

  group('ambiguidade e determinismo', () {
    test('termo banco isolado não sugere categoria', () {
      final result = classify(engine, 'Banco');

      expect(result.suggestedCategoryName, isNull);
    });

    test('conflito fraco e próximo não sugere categoria', () {
      final result = classify(engine, 'Curso e produto.');

      expect(result.suggestedCategoryName, isNull);
      expect(tagNames(result), containsAll(['Curso', 'Produto']));
    });

    test('empate forte usa ordem estável do catálogo', () {
      final result = classify(
        engine,
        'Curso prova exercício. Produto comprar desconto.',
      );

      expect(result.suggestedCategoryName, 'Estudos');
    });

    test('banco de dados supera banco financeiro com sinais técnicos', () {
      final result = classify(
        engine,
        'SQL query e tabela no banco de dados, com saldo e pagamento no banco.',
      );

      expect(result.suggestedCategoryName, 'Desenvolvimento');
      expect(tagNames(result), containsAll(['Código', 'Pagamento']));
    });

    test('etiqueta pode ser sugerida sem categoria', () {
      final result = classify(engine, 'Acesse https://memoshot.exemplo/app');

      expect(result.suggestedCategoryName, isNull);
      expect(tagNames(result), ['Link']);
    });

    test('etiquetas não se repetem mesmo com palavra repetida', () {
      final result = classify(
        engine,
        'entrevista entrevista ENTREVISTA entrevista',
      );

      expect(
        tagNames(result).where((name) => name == 'Entrevista'),
        hasLength(1),
      );
      final evidence = result.suggestedTags
          .singleWhere((tag) => tag.name == 'Entrevista')
          .evidence;
      expect(evidence.single.count, 1);
    });

    test('etiquetas usam ordenação determinística', () {
      final result = classify(
        engine,
        'Acesse https://exemplo.com em 21/07/2026 às 14h30.',
      );

      expect(tagNames(result), ['Link', 'Data', 'Horário']);
    });

    test('mesma entrada sempre produz exatamente o mesmo resultado', () {
      const input = ClassificationInput(
        ocrText: 'Vaga Flutter com entrevista em 21/07/2026 às 09:30.',
        originalFileName: 'Screenshot_WhatsApp.png',
        sourceMimeType: 'image/png',
      );

      final first = engine.classify(input);
      final second = engine.classify(input);

      expect(second, first);
      expect(second.hashCode, first.hashCode);
    });
  });

  group('sinais estruturais', () {
    test('detecta URL', () {
      final result = classify(engine, 'Veja www.exemplo.com/oferta?id=2');

      expect(tagNames(result), contains('Link'));
      expect(result.evidence, hasRule('pattern.url'));
    });

    test('detecta e-mail', () {
      final result = classify(engine, 'Contato: pessoa.teste+app@exemplo.com');

      expect(tagNames(result), contains('Contato'));
      expect(result.evidence, hasRule('pattern.email'));
    });

    test('detecta data brasileira', () {
      final result = classify(engine, 'Evento confirmado para 7/09/2026.');

      expect(tagNames(result), contains('Data'));
      expect(result.evidence, hasRule('pattern.date'));
    });

    test('detecta horário', () {
      final result = classify(engine, 'Começa às 08:45 e termina 14h30.');

      expect(tagNames(result), contains('Horário'));
      expect(result.evidence, hasRule('pattern.time'));
    });

    test('detecta valor monetário em reais', () {
      final result = classify(engine, 'Total: R\$ 1.299,90');

      expect(tagNames(result), contains('Pagamento'));
      expect(result.evidence, hasRule('pattern.brl'));
    });

    test('detecta telefone brasileiro aproximado', () {
      final result = classify(engine, 'Ligue para +55 (81) 99999-1234.');

      expect(tagNames(result), contains('Contato'));
      expect(result.evidence, hasRule('pattern.phone'));
    });

    test('evidências estruturais não expõem valores sensíveis', () {
      const email = 'segredo@empresa.com';
      const phone = '81999991234';
      const amount = r'R$ 8.450,00';
      final result = classify(engine, '$email $phone $amount');
      final structural = result.evidence.where(
        (item) => item.type == ClassificationEvidenceType.pattern,
      );

      expect(structural, isNotEmpty);
      for (final evidence in structural) {
        expect(evidence.safeMatch, isNull);
        expect(evidence.description, isNot(contains(email)));
        expect(evidence.description, isNot(contains(phone)));
        expect(evidence.description, isNot(contains(amount)));
      }
    });

    test('nome de arquivo pode fornecer origem sem expor nome completo', () {
      final result = engine.classify(
        const ClassificationInput(
          ocrText: 'conteúdo neutro',
          originalFileName: 'Screenshot_WhatsApp_conversa-privada.png',
        ),
      );

      expect(tagNames(result), contains('WhatsApp'));
      expect(
        result.evidence.map((item) => item.description).join(' '),
        isNot(contains('conversa-privada')),
      );
    });
  });

  group('normalização, robustez e modelos', () {
    test('trata acentos, caixa e espaços repetidos', () {
      final result = classify(
        engine,
        '  RECRUTADORA   marcou\nENTREVISTA para estágio  ',
      );

      expect(result.suggestedCategoryName, 'Carreira');
      expect(tagNames(result), containsAll(['Entrevista', 'Vaga']));
    });

    test('caracteres especiais não lançam exceção', () {
      final result = classify(
        engine,
        r'✨ [] {} <> !!! ??? C# / Flutter :: exception $$$',
      );

      expect(result.suggestedCategoryName, 'Desenvolvimento');
    });

    test('texto grande conclui normalmente', () {
      final largeText =
          '${List.filled(25000, 'conteúdo neutro').join(' ')} '
          'Flutter exception terminal';

      final result = classify(engine, largeText);

      expect(result.suggestedCategoryName, 'Desenvolvimento');
    });

    test('confianças permanecem limitadas entre zero e um', () {
      final result = classify(
        engine,
        'vaga recrutadora entrevista currículo candidatura processo seletivo '
        'LinkedIn salário estágio urgente responder 21/07/2026 14h30',
      );

      expect(result.confidence, inInclusiveRange(0, 1));
      for (final tag in result.suggestedTags) {
        expect(tag.confidence, inInclusiveRange(0, 1));
        for (final evidence in tag.evidence) {
          expect(evidence.weight, inInclusiveRange(0, 1));
        }
      }
    });

    test('modelos limitam confiança e expõem listas imutáveis', () {
      final evidence = ClassificationEvidence(
        ruleId: 'teste',
        type: ClassificationEvidenceType.keyword,
        description: 'Evidência de teste.',
        weight: 2,
      );
      final suggestion = ClassificationSuggestion(
        suggestedCategoryName: null,
        suggestedTags: [
          SuggestedTag(name: 'Teste', confidence: -1, evidence: [evidence]),
        ],
        confidence: 3,
        evidence: [evidence],
      );

      expect(suggestion.confidence, 1);
      expect(suggestion.suggestedTags.single.confidence, 0);
      expect(evidence.weight, 1);
      expect(
        () => suggestion.suggestedTags.add(
          SuggestedTag(name: 'Outra', confidence: 1, evidence: const []),
        ),
        throwsUnsupportedError,
      );
    });
  });
}

ClassificationSuggestion classify(
  LocalClassificationEngine engine,
  String text,
) {
  return engine.classify(ClassificationInput(ocrText: text));
}

List<String> tagNames(ClassificationSuggestion suggestion) {
  return suggestion.suggestedTags.map((tag) => tag.name).toList();
}

Matcher hasRule(String ruleId) {
  return contains(
    isA<ClassificationEvidence>().having(
      (evidence) => evidence.ruleId,
      'ruleId',
      ruleId,
    ),
  );
}

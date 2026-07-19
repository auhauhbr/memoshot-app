import '../../../core/text/text_normalizer.dart';
import '../../../core/visual/local_visual_analyzer.dart';
import 'classification_models.dart';

const contextualExistingDestinationThreshold = 0.82;
const contextualNewDestinationThreshold = 0.90;
const contextualDestinationMargin = 0.15;
const contextualTagThreshold = 0.75;
const maximumContextualTags = 4;

enum ProbableOrigin {
  whatsapp,
  amazon,
  mercadoLivre,
  mercadoPago,
  linkedIn,
  instagram,
  gitHub,
  browser,
  unknown,
}

enum VisualContentType {
  conversation,
  productPage,
  bookCover,
  bookExcerpt,
  resultTable,
  code,
  document,
  receipt,
  post,
  productImage,
  genericInterface,
}

enum ContentSubject {
  books,
  products,
  career,
  studies,
  sports,
  development,
  documents,
  finance,
  conversations,
  unknown,
}

final class ContextualDimension<T> {
  const ContextualDimension({required this.value, required this.confidence});

  final T value;
  final double confidence;
}

final class ContextualSignals {
  const ContextualSignals({
    required this.hasCurrencyValue,
    required this.hasProductPrice,
    required this.hasPaymentEvidence,
    required this.hasTransactionEvidence,
    required this.hasDate,
    required this.hasTime,
    required this.hasContextualTime,
    required this.hasScore,
    required this.hasTitle,
    required this.hasBrand,
    required this.hasDomain,
    required this.hasProbableApp,
    required this.hasStrongNegative,
  });

  final bool hasCurrencyValue;
  final bool hasProductPrice;
  final bool hasPaymentEvidence;
  final bool hasTransactionEvidence;
  final bool hasDate;
  final bool hasTime;
  final bool hasContextualTime;
  final bool hasScore;
  final bool hasTitle;
  final bool hasBrand;
  final bool hasDomain;
  final bool hasProbableApp;
  final bool hasStrongNegative;
}

final class ContextualDestination {
  ContextualDestination({
    required this.root,
    this.subfolder,
    required this.confidence,
    required this.margin,
    required List<SuggestedTag> tags,
  }) : tags = List.unmodifiable(tags);

  final String? root;
  final String? subfolder;
  final double confidence;
  final double margin;
  final List<SuggestedTag> tags;

  bool get isCatalogued => root != null;

  String? get persistedName => root == null
      ? null
      : subfolder == null
      ? root
      : '$root / $subfolder';
}

final class ContextualClassificationResult {
  ContextualClassificationResult({
    required this.origin,
    required this.visualType,
    required this.subject,
    required this.destination,
    required this.signals,
    required List<ClassificationEvidence> evidence,
  }) : evidence = List.unmodifiable(evidence);

  final ContextualDimension<ProbableOrigin> origin;
  final ContextualDimension<VisualContentType> visualType;
  final ContextualDimension<ContentSubject> subject;
  final ContextualDestination destination;
  final ContextualSignals signals;
  final List<ClassificationEvidence> evidence;

  ClassificationSuggestion toSuggestion() => ClassificationSuggestion(
    suggestedCategoryName: destination.persistedName,
    suggestedTags: destination.tags,
    confidence: destination.confidence,
    evidence: evidence,
  );
}

class ContextualFolderCatalog {
  const ContextualFolderCatalog._();

  static const roots = <String>{
    'Livros',
    'Carreira',
    'Estudos',
    'Documentos',
    'Desenvolvimento',
    'Produtos',
    'Esportes',
    'Conversas',
    'Outros',
  };

  static const children = <String, Set<String>>{
    'Livros': {'Capas', 'Trechos'},
    'Carreira': {'Vagas', 'Entrevistas'},
    'Estudos': {'Cursos', 'Materiais'},
    'Documentos': {'Comprovantes'},
    'Desenvolvimento': {'Código', 'Erros'},
    'Produtos': {},
    'Esportes': {},
    'Conversas': {},
    'Outros': {},
  };

  static bool accepts(String root, String? child) {
    if (!roots.contains(root)) return false;
    return child == null || children[root]!.contains(child);
  }

  static (String, String?)? parse(String? value) {
    if (value == null) return null;
    final parts = value.split('/').map((part) => part.trim()).toList();
    if (parts.isEmpty || parts.length > 2) return null;
    final root = _official(roots, parts.first);
    if (root == null) return null;
    final child = parts.length == 1
        ? null
        : _official(children[root]!, parts.last);
    if (parts.length == 2 && child == null) return null;
    return (root, child);
  }

  static String? _official(Iterable<String> values, String candidate) {
    final normalized = const TextNormalizer().normalize(candidate);
    return values.where((value) {
      return const TextNormalizer().normalize(value) == normalized;
    }).firstOrNull;
  }
}

class ContextualTagCatalog {
  const ContextualTagCatalog._();

  static const names = <String>{
    'WhatsApp',
    'Amazon',
    'Mercado Livre',
    'Mercado Pago',
    'LinkedIn',
    'Instagram',
    'GitHub',
    'Navegador',
    'Produto',
    'Livro',
    'Conversa',
    'Código',
    'Documento',
    'Comprovante',
    'Pagamento',
    'Horário',
    'Tabela',
    'Vaga',
    'Curso',
    'Carro',
    'Notebook',
    'Teclado',
    'Peça mecânica',
    'Futebol',
  };

  static bool contains(String value) {
    final normalized = const TextNormalizer().normalize(value);
    return names.any(
      (name) => const TextNormalizer().normalize(name) == normalized,
    );
  }
}

class ContextualClassificationEngine {
  const ContextualClassificationEngine({
    this.normalizer = const TextNormalizer(),
  });

  final TextNormalizer normalizer;

  ContextualClassificationResult classify({
    required String ocrText,
    VisualAnalysisResult? visualAnalysis,
  }) {
    final text = ' ${normalizer.normalize(ocrText)} ';
    final visual = <String, double>{
      for (final label in visualAnalysis?.labels ?? const <VisualLabel>[])
        label.key: label.confidence,
    };
    final origin = _detectOrigin(text);
    final currency = _currencyPattern.hasMatch(ocrText);
    final productContext =
        _hasAny(text, _productTerms) ||
        _isMarketplace(origin.value) ||
        _hasVisual(visual, _productVisualLabels);
    final paymentEvidence = _hasAny(text, _paymentTerms);
    final transactionEvidence =
        paymentEvidence && _hasAny(text, _transactionTerms);
    final hasTime = _timePattern.hasMatch(ocrText);
    final contextualTime = hasTime && _hasAny(text, _timeContextTerms);
    final hasScore =
        _scorePattern.hasMatch(ocrText) && _hasAny(text, _sportsTerms);
    final signals = ContextualSignals(
      hasCurrencyValue: currency,
      hasProductPrice: currency && productContext && !transactionEvidence,
      hasPaymentEvidence: paymentEvidence,
      hasTransactionEvidence: transactionEvidence,
      hasDate: _datePattern.hasMatch(ocrText),
      hasTime: hasTime,
      hasContextualTime: contextualTime,
      hasScore: hasScore,
      hasTitle: _hasAny(text, const [' titulo ', ' autor ', ' modelo ']),
      hasBrand: origin.value != ProbableOrigin.unknown,
      hasDomain: _domainPattern.hasMatch(ocrText),
      hasProbableApp: origin.value != ProbableOrigin.unknown,
      hasStrongNegative:
          (currency && productContext && !transactionEvidence) ||
          (hasTime && !contextualTime),
    );

    final scores = <_DestinationScore>[];
    void score(String root, String? child, Iterable<double> weights) {
      final confidence = _combine(weights);
      if (confidence > 0) {
        scores.add(_DestinationScore(root, child, confidence));
      }
    }

    final bookWeights = <double>[
      for (final term in _bookTerms)
        if (text.contains(term.$1)) term.$2,
      if (_hasVisual(visual, _bookVisualLabels)) 0.68,
    ];
    final isExcerpt = _hasAny(text, const [
      ' trecho ',
      ' capitulo ',
      ' pagina ',
      ' paragrafo ',
    ]);
    score('Livros', isExcerpt ? 'Trechos' : 'Capas', bookWeights);

    final careerWeights = <double>[
      for (final term in _careerTerms)
        if (text.contains(term.$1)) term.$2,
      if (origin.value == ProbableOrigin.linkedIn) 0.38,
    ];
    score(
      'Carreira',
      text.contains(' entrevista ') ? 'Entrevistas' : 'Vagas',
      careerWeights,
    );

    final studiesWeights = <double>[
      for (final term in _studyTerms)
        if (text.contains(term.$1)) term.$2,
    ];
    score(
      'Estudos',
      _hasAny(text, const [' curso ', ' aula ', ' modulo ', ' videoaula '])
          ? 'Cursos'
          : 'Materiais',
      studiesWeights,
    );

    final documentWeights = <double>[
      for (final term in _documentTerms)
        if (text.contains(term.$1)) term.$2,
      if (_hasVisual(visual, const {'receipt'})) 0.70,
      if (transactionEvidence) 0.62,
    ];
    score(
      'Documentos',
      transactionEvidence || text.contains(' comprovante ')
          ? 'Comprovantes'
          : null,
      documentWeights,
    );

    final developmentWeights = <double>[
      for (final term in _developmentTerms)
        if (text.contains(term.$1)) term.$2,
    ];
    score(
      'Desenvolvimento',
      _hasAny(text, const [' erro ', ' exception ', ' stack trace ', ' falha '])
          ? 'Erros'
          : 'Código',
      developmentWeights,
    );

    final productWeights = <double>[
      for (final term in _weightedProductTerms)
        if (text.contains(term.$1)) term.$2,
      if (_isMarketplace(origin.value)) 0.48,
      if (_hasVisual(visual, _productVisualLabels)) 0.62,
      if (currency && productContext) 0.34,
    ];
    score('Produtos', null, productWeights);

    final sportsWeights = <double>[
      for (final term in _weightedSportsTerms)
        if (text.contains(term.$1)) term.$2,
      if (hasScore) 0.72,
      if (_hasVisual(visual, _sportsVisualLabels)) 0.58,
    ];
    score('Esportes', null, sportsWeights);

    final conversationWeights = <double>[
      if (origin.value == ProbableOrigin.whatsapp) 0.48,
      for (final term in _conversationTerms)
        if (text.contains(term.$1)) term.$2,
    ];
    score('Conversas', null, conversationWeights);

    scores.sort((first, second) {
      final confidence = second.confidence.compareTo(first.confidence);
      return confidence != 0
          ? confidence
          : first.persistedName.compareTo(second.persistedName);
    });
    final best = scores.firstOrNull;
    final second = scores.length > 1 ? scores[1] : null;
    final margin = best == null
        ? 0.0
        : (best.confidence - (second?.confidence ?? 0)).clamp(0, 1).toDouble();

    final subject = _subjectFor(best?.root);
    final type = _typeFor(
      text: text,
      visual: visual,
      origin: origin.value,
      destination: best,
      transactionEvidence: transactionEvidence,
      hasScore: hasScore,
    );
    final tags = _tagsFor(
      text: text,
      visual: visual,
      origin: origin,
      type: type,
      transactionEvidence: transactionEvidence,
      contextualTime: contextualTime,
      hasScore: hasScore,
    );
    final evidence = <ClassificationEvidence>[
      if (best != null)
        ClassificationEvidence(
          ruleId: 'context.destination.${_key(best.root)}',
          type: ClassificationEvidenceType.pattern,
          description: 'Destino pertence ao catálogo contextual.',
          weight: best.confidence,
        ),
      if (best?.child case final child?)
        ClassificationEvidence(
          ruleId: 'context.destination.${_key(best!.root)}.${_key(child)}',
          type: ClassificationEvidenceType.pattern,
          description: 'Subpasta pertence ao catálogo contextual.',
          weight: best.confidence,
        ),
      ClassificationEvidence(
        ruleId: 'context.destination.margin',
        type: ClassificationEvidenceType.pattern,
        description: 'Margem técnica entre os destinos candidatos.',
        weight: margin,
      ),
      if (currency && productContext && !transactionEvidence)
        ClassificationEvidence(
          ruleId: 'context.negative.price_not_payment',
          type: ClassificationEvidenceType.pattern,
          description: 'Preço de produto não representa pagamento.',
          weight: 1,
        ),
      if (hasTime && !contextualTime)
        ClassificationEvidence(
          ruleId: 'context.negative.isolated_time',
          type: ClassificationEvidenceType.pattern,
          description: 'Horário isolado não influencia a organização.',
          weight: 1,
        ),
      if (origin.value != ProbableOrigin.unknown)
        ClassificationEvidence(
          ruleId: 'context.origin.${origin.value.name}',
          type: ClassificationEvidenceType.pattern,
          description: 'Origem provável detectada por assinatura controlada.',
          weight: origin.confidence,
        ),
    ];
    return ContextualClassificationResult(
      origin: origin,
      visualType: type,
      subject: ContextualDimension(
        value: subject,
        confidence: best?.confidence ?? 0,
      ),
      destination: ContextualDestination(
        root: best?.root,
        subfolder: best?.child,
        confidence: best?.confidence ?? 0,
        margin: margin,
        tags: tags,
      ),
      signals: signals,
      evidence: evidence,
    );
  }

  ContextualDimension<ProbableOrigin> _detectOrigin(String text) {
    final candidates = <ContextualDimension<ProbableOrigin>>[];
    void add(ProbableOrigin origin, double confidence) {
      candidates.add(
        ContextualDimension(value: origin, confidence: confidence),
      );
    }

    if (text.contains(' amazon.com') || text.contains(' amazon.com.br')) {
      add(ProbableOrigin.amazon, 0.98);
    } else if (text.contains(' amazon ') && _hasAny(text, _productTerms)) {
      add(ProbableOrigin.amazon, 0.86);
    }
    if (text.contains(' mercadolivre.com') ||
        text.contains(' mercado livre ') && _hasAny(text, _productTerms)) {
      add(ProbableOrigin.mercadoLivre, 0.94);
    }
    if (text.contains(' mercadopago.com') ||
        text.contains(' mercado pago ') && _hasAny(text, _paymentTerms)) {
      add(ProbableOrigin.mercadoPago, 0.95);
    }
    if (text.contains(' linkedin.com') ||
        text.contains(' linkedin ') && _hasAny(text, _careerContextTerms)) {
      add(ProbableOrigin.linkedIn, 0.94);
    }
    if (text.contains(' github.com') ||
        text.contains(' github ') && _hasAny(text, _developmentContextTerms)) {
      add(ProbableOrigin.gitHub, 0.95);
    }
    if (text.contains(' instagram.com') ||
        text.contains(' instagram ') &&
            _hasAny(text, const [
              ' seguir ',
              ' seguidores ',
              ' publicacao ',
              ' reels ',
            ])) {
      add(ProbableOrigin.instagram, 0.92);
    }
    if (text.contains(' whatsapp ') &&
        _hasAny(text, const [
          ' mensagem ',
          ' online ',
          ' visto por ultimo ',
          ' audio ',
          ' digite uma mensagem ',
          ' responder ',
        ])) {
      add(ProbableOrigin.whatsapp, 0.93);
    }
    if (text.contains(' google.com/search') ||
        text.contains(' resultados da pesquisa ') ||
        _hasAny(text, const [' brave ', ' chrome ']) &&
            _domainPattern.hasMatch(text)) {
      add(ProbableOrigin.browser, 0.86);
    }
    if (candidates.isEmpty) {
      return const ContextualDimension(
        value: ProbableOrigin.unknown,
        confidence: 0,
      );
    }
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates.first;
  }

  ContextualDimension<VisualContentType> _typeFor({
    required String text,
    required Map<String, double> visual,
    required ProbableOrigin origin,
    required _DestinationScore? destination,
    required bool transactionEvidence,
    required bool hasScore,
  }) {
    if (transactionEvidence || destination?.child == 'Comprovantes') {
      return const ContextualDimension(
        value: VisualContentType.receipt,
        confidence: 0.90,
      );
    }
    if (destination?.child == 'Capas') {
      return ContextualDimension(
        value: VisualContentType.bookCover,
        confidence: destination!.confidence,
      );
    }
    if (destination?.child == 'Trechos') {
      return ContextualDimension(
        value: VisualContentType.bookExcerpt,
        confidence: destination!.confidence,
      );
    }
    if (hasScore || destination?.root == 'Esportes') {
      return ContextualDimension(
        value: VisualContentType.resultTable,
        confidence: destination?.confidence ?? 0.75,
      );
    }
    if (destination?.root == 'Produtos') {
      return ContextualDimension(
        value: _isMarketplace(origin)
            ? VisualContentType.productPage
            : VisualContentType.productImage,
        confidence: destination!.confidence,
      );
    }
    if (destination?.root == 'Desenvolvimento') {
      return ContextualDimension(
        value: VisualContentType.code,
        confidence: destination!.confidence,
      );
    }
    if (destination?.root == 'Documentos') {
      return ContextualDimension(
        value: VisualContentType.document,
        confidence: destination!.confidence,
      );
    }
    if (origin == ProbableOrigin.whatsapp &&
        _hasAny(text, _conversationTerms.map((term) => term.$1))) {
      return const ContextualDimension(
        value: VisualContentType.conversation,
        confidence: 0.82,
      );
    }
    if (origin == ProbableOrigin.instagram) {
      return const ContextualDimension(
        value: VisualContentType.post,
        confidence: 0.80,
      );
    }
    return ContextualDimension(
      value: VisualContentType.genericInterface,
      confidence: _hasVisual(visual, const {'text', 'font', 'screenshot'})
          ? 0.40
          : 0,
    );
  }

  List<SuggestedTag> _tagsFor({
    required String text,
    required Map<String, double> visual,
    required ContextualDimension<ProbableOrigin> origin,
    required ContextualDimension<VisualContentType> type,
    required bool transactionEvidence,
    required bool contextualTime,
    required bool hasScore,
  }) {
    final values = <String, double>{};
    void add(String name, double confidence) {
      if (!ContextualTagCatalog.contains(name) ||
          confidence < contextualTagThreshold) {
        return;
      }
      final previous = values[name];
      if (previous == null || confidence > previous) values[name] = confidence;
    }

    final originName = switch (origin.value) {
      ProbableOrigin.whatsapp => 'WhatsApp',
      ProbableOrigin.amazon => 'Amazon',
      ProbableOrigin.mercadoLivre => 'Mercado Livre',
      ProbableOrigin.mercadoPago => 'Mercado Pago',
      ProbableOrigin.linkedIn => 'LinkedIn',
      ProbableOrigin.instagram => 'Instagram',
      ProbableOrigin.gitHub => 'GitHub',
      ProbableOrigin.browser => 'Navegador',
      ProbableOrigin.unknown => null,
    };
    if (originName != null) add(originName, origin.confidence);
    final typeName = switch (type.value) {
      VisualContentType.conversation => 'Conversa',
      VisualContentType.productPage ||
      VisualContentType.productImage => 'Produto',
      VisualContentType.bookCover || VisualContentType.bookExcerpt => 'Livro',
      VisualContentType.resultTable => 'Tabela',
      VisualContentType.code => 'Código',
      VisualContentType.document => 'Documento',
      VisualContentType.receipt => 'Comprovante',
      _ => null,
    };
    if (typeName != null) add(typeName, type.confidence);
    if (transactionEvidence) add('Pagamento', 0.90);
    if (contextualTime) add('Horário', 0.78);
    if (_hasAny(text, _careerContextTerms)) add('Vaga', 0.82);
    if (_hasAny(text, const [' curso ', ' aula ', ' modulo ', ' videoaula '])) {
      add('Curso', 0.82);
    }
    if (hasScore || _hasVisual(visual, const {'soccer', 'football'})) {
      add('Futebol', hasScore ? 0.88 : 0.76);
    }
    if (_hasAny(text, const [' teclado ', ' keyboard ']) ||
        _hasVisual(visual, const {'computer keyboard', 'keyboard'})) {
      add('Teclado', 0.88);
    }
    if (_hasAny(text, const [' notebook ', ' laptop ']) ||
        _hasVisual(visual, const {'laptop'})) {
      add('Notebook', 0.86);
    }
    if (_hasAny(text, const [' carro ', ' veiculo ', ' automovel ']) ||
        _hasVisual(visual, const {'car', 'vehicle'})) {
      add('Carro', 0.84);
    }
    final sorted = values.entries.toList()
      ..sort((a, b) {
        final confidence = b.value.compareTo(a.value);
        return confidence != 0 ? confidence : a.key.compareTo(b.key);
      });
    return sorted
        .take(maximumContextualTags)
        .map((entry) {
          final evidence = ClassificationEvidence(
            ruleId: 'context.tag.${_key(entry.key)}',
            type: ClassificationEvidenceType.pattern,
            description: 'Etiqueta pertence ao catálogo contextual.',
            weight: entry.value,
          );
          return SuggestedTag(
            name: entry.key,
            confidence: entry.value,
            evidence: [evidence],
          );
        })
        .toList(growable: false);
  }

  ContentSubject _subjectFor(String? root) => switch (root) {
    'Livros' => ContentSubject.books,
    'Produtos' => ContentSubject.products,
    'Carreira' => ContentSubject.career,
    'Estudos' => ContentSubject.studies,
    'Esportes' => ContentSubject.sports,
    'Desenvolvimento' => ContentSubject.development,
    'Documentos' => ContentSubject.documents,
    'Conversas' => ContentSubject.conversations,
    _ => ContentSubject.unknown,
  };

  bool _hasAny(String text, Iterable<String> terms) => terms.any(text.contains);

  bool _hasVisual(Map<String, double> labels, Set<String> allowlist) => labels
      .entries
      .any((entry) => allowlist.contains(entry.key) && entry.value >= 0.55);

  bool _isMarketplace(ProbableOrigin origin) =>
      origin == ProbableOrigin.amazon || origin == ProbableOrigin.mercadoLivre;

  double _combine(Iterable<double> weights) {
    var remaining = 1.0;
    for (final weight in weights) {
      remaining *= 1 - weight.clamp(0, 1);
    }
    return (1 - remaining).clamp(0, 1).toDouble();
  }

  String _key(String value) => normalizer.normalize(value).replaceAll(' ', '_');
}

final class _DestinationScore {
  const _DestinationScore(this.root, this.child, this.confidence);

  final String root;
  final String? child;
  final double confidence;

  String get persistedName => child == null ? root : '$root / $child';
}

const _bookTerms = <(String, double)>[
  (' livro ', 0.62),
  (' capa comum ', 0.72),
  (' autor ', 0.42),
  (' editora ', 0.44),
  (' isbn ', 0.72),
  (' capitulo ', 0.46),
  (' trecho ', 0.62),
];
const _careerTerms = <(String, double)>[
  (' vaga ', 0.68),
  (' entrevista ', 0.72),
  (' recrutador ', 0.52),
  (' recrutadora ', 0.52),
  (' candidatura ', 0.52),
  (' processo seletivo ', 0.66),
];
const _studyTerms = <(String, double)>[
  (' curso ', 0.68),
  (' aula ', 0.56),
  (' modulo ', 0.58),
  (' videoaula ', 0.68),
  (' material didatico ', 0.62),
  (' exercicio ', 0.48),
];
const _documentTerms = <(String, double)>[
  (' comprovante ', 0.76),
  (' documento ', 0.62),
  (' contrato ', 0.64),
  (' protocolo ', 0.56),
  (' cpf ', 0.54),
  (' cnpj ', 0.54),
];
const _developmentTerms = <(String, double)>[
  (' codigo ', 0.68),
  (' exception ', 0.72),
  (' stack trace ', 0.78),
  (' github ', 0.54),
  (' pull request ', 0.62),
  (' flutter ', 0.58),
  (' terminal ', 0.52),
  (' sql ', 0.60),
];
const _weightedProductTerms = <(String, double)>[
  (' produto ', 0.62),
  (' comprar ', 0.58),
  (' carrinho ', 0.62),
  (' preco ', 0.54),
  (' frete ', 0.48),
  (' teclado ', 0.70),
  (' notebook ', 0.70),
  (' carro ', 0.62),
  (' modelo ', 0.36),
];
const _weightedSportsTerms = <(String, double)>[
  (' futebol ', 0.68),
  (' partida ', 0.56),
  (' campeonato ', 0.58),
  (' copa ', 0.52),
  (' placar ', 0.68),
  (' classificacao ', 0.42),
  (' tabela ', 0.36),
  (' time ', 0.32),
];
const _conversationTerms = <(String, double)>[
  (' mensagem ', 0.52),
  (' conversa ', 0.58),
  (' responder ', 0.50),
  (' audio ', 0.42),
  (' online ', 0.34),
];
const _productTerms = <String>[
  ' produto ',
  ' comprar ',
  ' carrinho ',
  ' preco ',
  ' frete ',
  ' oferta ',
  ' teclado ',
  ' notebook ',
  ' carro ',
];
const _paymentTerms = <String>[
  ' pago ',
  ' pagamento realizado ',
  ' comprovante ',
  ' pix enviado ',
  ' pix recebido ',
  ' transferencia ',
  ' transacao ',
  ' favorecido ',
  ' autenticacao ',
  ' codigo de operacao ',
  ' debito concluido ',
];
const _transactionTerms = <String>[
  ' realizado ',
  ' concluido ',
  ' enviado ',
  ' recebido ',
  ' comprovante ',
  ' favorecido ',
  ' autenticacao ',
  ' operacao ',
  ' transacao ',
];
const _timeContextTerms = <String>[
  ' reuniao ',
  ' entrevista ',
  ' aula ',
  ' partida ',
  ' evento ',
  ' agendamento ',
  ' horario de atendimento ',
  ' saida ',
  ' chegada ',
];
const _sportsTerms = <String>[
  ' futebol ',
  ' partida ',
  ' campeonato ',
  ' copa ',
  ' placar ',
  ' time ',
  ' selecao ',
];
const _careerContextTerms = <String>[
  ' vaga ',
  ' entrevista ',
  ' candidatura ',
  ' recrutador ',
  ' emprego ',
];
const _developmentContextTerms = <String>[
  ' codigo ',
  ' commit ',
  ' pull request ',
  ' repository ',
  ' issue ',
];
const _bookVisualLabels = <String>{'book', 'book cover'};
const _productVisualLabels = <String>{
  'product',
  'car',
  'vehicle',
  'laptop',
  'computer keyboard',
  'keyboard',
  'electronics',
};
const _sportsVisualLabels = <String>{'sports', 'soccer', 'football', 'stadium'};
final _currencyPattern = RegExp(
  r'(?:R\$\s*\d{1,3}(?:\.\d{3})*(?:,\d{2})?|\b\d+(?:,\d{2})?\s*reais\b)',
  caseSensitive: false,
);
final _timePattern = RegExp(
  r'\b(?:[01]?\d|2[0-3])(?:h(?:[0-5]\d)?|:[0-5]\d)\b',
  caseSensitive: false,
);
final _datePattern = RegExp(
  r'\b(?:0?[1-9]|[12]\d|3[01])[/.-](?:0?[1-9]|1[0-2])(?:[/.-](?:\d{2}|\d{4}))?\b',
);
final _scorePattern = RegExp(r'\b\d{1,2}\s*[-x×]\s*\d{1,2}\b');
final _domainPattern = RegExp(
  r'\b(?:[a-z0-9-]+\.)+(?:com|com\.br|org|net|dev|io)\b',
  caseSensitive: false,
);

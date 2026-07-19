import '../../../core/text/text_normalizer.dart';
import 'classification_models.dart';

class LocalClassificationTagCatalog {
  const LocalClassificationTagCatalog._();

  static const names = <String>{
    'Entrevista',
    'Vaga',
    'Curso',
    'Código',
    'Erro',
    'Produto',
    'Promoção',
    'Pagamento',
    'Documento',
    'Data',
    'Horário',
    'Link',
    'WhatsApp',
    'GitHub',
    'Contato',
    'Urgente',
    'Precisa responder',
    'Certificado',
  };

  static final Set<String> _normalizedNames = {
    for (final name in names) const TextNormalizer().normalize(name),
  };

  static bool contains(String name) {
    return _normalizedNames.contains(const TextNormalizer().normalize(name));
  }
}

/// Motor local baseado apenas em regras explícitas.
///
/// Cada sinal contribui uma única vez. A força combinada usa
/// `1 - produto(1 - peso)`, portanto evidências independentes reforçam uma
/// sugestão sem ultrapassar 1. O valor é somente a força das regras locais,
/// não uma probabilidade ou medida científica de precisão.
///
/// Para adicionar uma categoria ou termo, altere os catálogos constantes no
/// fim deste arquivo. O motor não usa IA, APIs, banco ou repositórios e não
/// aplica nem persiste o resultado produzido.
class LocalClassificationEngine {
  const LocalClassificationEngine({this.normalizer = const TextNormalizer()});

  static const double _categoryThreshold = 0.40;
  static const double _tagThreshold = 0.40;
  static const double _weakConflictCeiling = 0.72;
  static const double _closeScoreDifference = 0.10;

  final TextNormalizer normalizer;

  ClassificationSuggestion classify(ClassificationInput input) {
    final normalizedText = normalizer.normalize(input.ocrText);
    if (normalizedText.isEmpty) return ClassificationSuggestion.empty();

    final searchableText = _searchable(normalizedText);
    final words = searchableText.trim().split(' ').where((word) {
      return word.isNotEmpty;
    }).toSet();
    final structuralSignals = _detectStructuralSignals(input.ocrText);
    final metadataSignals = _detectMetadataSignals(input.originalFileName);
    final externalSignals = [...structuralSignals, ...metadataSignals];

    final categoryScores = <_ScoredCategory>[];
    final allEvidence = <String, ClassificationEvidence>{};
    for (var index = 0; index < _categoryRules.length; index++) {
      final rule = _categoryRules[index];
      final evidence = _termEvidence(
        searchableText: searchableText,
        words: words,
        terms: rule.terms,
        rulePrefix: 'category.${rule.id}',
        description: rule.description,
      );
      if (evidence.isEmpty) continue;
      for (final item in evidence) {
        allEvidence[item.ruleId] = item;
      }
      categoryScores.add(
        _ScoredCategory(
          name: rule.name,
          confidence: _combine(evidence.map((item) => item.weight)),
          evidence: evidence,
          catalogIndex: index,
        ),
      );
    }
    categoryScores.sort(_compareCategories);

    final selectedCategory = _selectCategory(categoryScores);
    for (final signal in externalSignals) {
      allEvidence[signal.evidence.ruleId] = signal.evidence;
    }

    final tagsByName = <String, SuggestedTag>{};
    for (final rule in _tagRules) {
      final evidence = <ClassificationEvidence>[
        ..._termEvidence(
          searchableText: searchableText,
          words: words,
          terms: rule.terms,
          rulePrefix: 'tag.${rule.id}',
          description: rule.description,
        ),
        for (final signal in externalSignals)
          if (rule.signalIds.contains(signal.id)) signal.evidence,
      ];
      if (evidence.isEmpty) continue;
      final confidence = _combine(evidence.map((item) => item.weight));
      if (confidence < _tagThreshold) continue;
      tagsByName[rule.name] = SuggestedTag(
        name: rule.name,
        confidence: confidence,
        evidence: _sortedEvidence(evidence),
      );
      for (final item in evidence) {
        allEvidence[item.ruleId] = item;
      }
    }

    final tags = tagsByName.values.toList(growable: false)
      ..sort((first, second) {
        final byConfidence = second.confidence.compareTo(first.confidence);
        return byConfidence != 0
            ? byConfidence
            : first.name.compareTo(second.name);
      });
    final confidence =
        selectedCategory?.confidence ??
        (tags.isEmpty ? 0.0 : tags.first.confidence);

    return ClassificationSuggestion(
      suggestedCategoryName: selectedCategory?.name,
      suggestedTags: tags,
      confidence: confidence,
      evidence: _sortedEvidence(allEvidence.values),
    );
  }

  _ScoredCategory? _selectCategory(List<_ScoredCategory> scores) {
    if (scores.isEmpty || scores.first.confidence < _categoryThreshold) {
      return null;
    }
    if (scores.length == 1) return scores.first;
    final first = scores.first;
    final second = scores[1];
    final isWeakAndClose =
        first.confidence < _weakConflictCeiling &&
        first.confidence - second.confidence < _closeScoreDifference;
    return isWeakAndClose ? null : first;
  }

  List<ClassificationEvidence> _termEvidence({
    required String searchableText,
    required Set<String> words,
    required List<_WeightedTerm> terms,
    required String rulePrefix,
    required String description,
  }) {
    final evidence = <ClassificationEvidence>[];
    for (final term in terms) {
      if (!_containsTerm(searchableText, words, term.value)) continue;
      evidence.add(
        ClassificationEvidence(
          ruleId: '$rulePrefix.${term.id}',
          type: ClassificationEvidenceType.keyword,
          description: description,
          weight: term.weight,
          safeMatch: term.displayName,
          count: 1,
        ),
      );
    }
    return evidence;
  }

  List<_DetectedSignal> _detectStructuralSignals(String originalText) {
    final signals = <_DetectedSignal>[];
    _addPatternSignal(
      signals,
      originalText,
      id: 'pattern.url',
      pattern: _urlPattern,
      description: 'Encontrou um endereço de internet.',
      weight: 0.78,
    );
    _addPatternSignal(
      signals,
      originalText,
      id: 'pattern.email',
      pattern: _emailPattern,
      description: 'Encontrou um endereço de e-mail.',
      weight: 0.62,
    );
    _addPatternSignal(
      signals,
      originalText,
      id: 'pattern.date',
      pattern: _datePattern,
      description: 'Encontrou uma data no texto.',
      weight: 0.68,
    );
    _addPatternSignal(
      signals,
      originalText,
      id: 'pattern.time',
      pattern: _timePattern,
      description: 'Encontrou um horário no texto.',
      weight: 0.68,
    );
    _addPatternSignal(
      signals,
      originalText,
      id: 'pattern.brl',
      pattern: _brlPattern,
      description: 'Encontrou um valor monetário em reais.',
      weight: 0.46,
    );
    _addPatternSignal(
      signals,
      originalText,
      id: 'pattern.phone',
      pattern: _phonePattern,
      description: 'Encontrou um possível telefone brasileiro.',
      weight: 0.66,
    );
    return signals;
  }

  List<_DetectedSignal> _detectMetadataSignals(String? originalFileName) {
    if (originalFileName == null || originalFileName.trim().isEmpty) {
      return const [];
    }
    final normalizedName = normalizer.normalize(originalFileName);
    final signals = <_DetectedSignal>[];
    for (final origin in const [
      ('metadata.whatsapp', 'whatsapp', 'O nome do arquivo indica WhatsApp.'),
      ('metadata.github', 'github', 'O nome do arquivo indica GitHub.'),
    ]) {
      if (!normalizedName.contains(origin.$2)) continue;
      signals.add(
        _DetectedSignal(
          id: origin.$1,
          evidence: ClassificationEvidence(
            ruleId: origin.$1,
            type: ClassificationEvidenceType.metadata,
            description: origin.$3,
            weight: 0.48,
            safeMatch: origin.$2,
            count: 1,
          ),
        ),
      );
    }
    return signals;
  }

  void _addPatternSignal(
    List<_DetectedSignal> target,
    String text, {
    required String id,
    required RegExp pattern,
    required String description,
    required double weight,
  }) {
    final matches = pattern.allMatches(text).length;
    if (matches == 0) return;
    target.add(
      _DetectedSignal(
        id: id,
        evidence: ClassificationEvidence(
          ruleId: id,
          type: ClassificationEvidenceType.pattern,
          description: description,
          weight: weight,
          count: matches,
        ),
      ),
    );
  }

  String _searchable(String normalizedText) {
    return ' ${normalizedText.replaceAll(_termSeparatorPattern, ' ')} '
        .replaceAll(_repeatedSpacePattern, ' ');
  }

  bool _containsTerm(String text, Set<String> words, String term) {
    return term.contains(' ') ? text.contains(' $term ') : words.contains(term);
  }

  double _combine(Iterable<double> weights) {
    var remaining = 1.0;
    for (final weight in weights) {
      remaining *= 1 - weight.clamp(0, 1);
    }
    return (1 - remaining).clamp(0, 1).toDouble();
  }

  List<ClassificationEvidence> _sortedEvidence(
    Iterable<ClassificationEvidence> evidence,
  ) {
    final unique = <String, ClassificationEvidence>{
      for (final item in evidence) item.ruleId: item,
    };
    final sorted = unique.values.toList(growable: false)
      ..sort((first, second) => first.ruleId.compareTo(second.ruleId));
    return sorted;
  }

  int _compareCategories(_ScoredCategory first, _ScoredCategory second) {
    final byConfidence = second.confidence.compareTo(first.confidence);
    return byConfidence != 0
        ? byConfidence
        : first.catalogIndex.compareTo(second.catalogIndex);
  }
}

class _WeightedTerm {
  const _WeightedTerm(this.id, this.value, this.weight, [String? displayName])
    : displayName = displayName ?? value;

  final String id;
  final String value;
  final double weight;
  final String displayName;
}

class _CategoryRule {
  const _CategoryRule({
    required this.id,
    required this.name,
    required this.description,
    required this.terms,
  });

  final String id;
  final String name;
  final String description;
  final List<_WeightedTerm> terms;
}

class _TagRule {
  const _TagRule({
    required this.id,
    required this.name,
    required this.description,
    this.terms = const [],
    this.signalIds = const {},
  });

  final String id;
  final String name;
  final String description;
  final List<_WeightedTerm> terms;
  final Set<String> signalIds;
}

class _ScoredCategory {
  const _ScoredCategory({
    required this.name,
    required this.confidence,
    required this.evidence,
    required this.catalogIndex,
  });

  final String name;
  final double confidence;
  final List<ClassificationEvidence> evidence;
  final int catalogIndex;
}

class _DetectedSignal {
  const _DetectedSignal({required this.id, required this.evidence});

  final String id;
  final ClassificationEvidence evidence;
}

const _categoryRules = <_CategoryRule>[
  _CategoryRule(
    id: 'career',
    name: 'Carreira',
    description: 'Encontrou termos relacionados a processos seletivos.',
    terms: [
      _WeightedTerm('job', 'vaga', 0.34),
      _WeightedTerm('recruiter_m', 'recrutador', 0.48),
      _WeightedTerm('recruiter_f', 'recrutadora', 0.48),
      _WeightedTerm('interview', 'entrevista', 0.52),
      _WeightedTerm('resume', 'curriculo', 0.42, 'currículo'),
      _WeightedTerm('application', 'candidatura', 0.42),
      _WeightedTerm('selection', 'processo seletivo', 0.54),
      _WeightedTerm('linkedin', 'linkedin', 0.34, 'LinkedIn'),
      _WeightedTerm('salary', 'salario', 0.24, 'salário'),
      _WeightedTerm('internship', 'estagio', 0.36, 'estágio'),
    ],
  ),
  _CategoryRule(
    id: 'studies',
    name: 'Estudos',
    description: 'Encontrou termos relacionados a estudos.',
    terms: [
      _WeightedTerm('class', 'aula', 0.36),
      _WeightedTerm('course', 'curso', 0.44),
      _WeightedTerm('exercise', 'exercicio', 0.42, 'exercício'),
      _WeightedTerm('exam', 'prova', 0.44),
      _WeightedTerm('college', 'faculdade', 0.42),
      _WeightedTerm('activity', 'atividade', 0.30),
      _WeightedTerm('chapter', 'capitulo', 0.34, 'capítulo'),
      _WeightedTerm('summary', 'resumo', 0.34),
      _WeightedTerm('certificate', 'certificado', 0.42),
    ],
  ),
  _CategoryRule(
    id: 'shopping',
    name: 'Compras',
    description: 'Encontrou termos relacionados a compras.',
    terms: [
      _WeightedTerm('buy', 'comprar', 0.44),
      _WeightedTerm('product', 'produto', 0.44),
      _WeightedTerm('price', 'preco', 0.38, 'preço'),
      _WeightedTerm('discount', 'desconto', 0.42),
      _WeightedTerm('sale', 'promocao', 0.42, 'promoção'),
      _WeightedTerm('shipping', 'frete', 0.34),
      _WeightedTerm('cart', 'carrinho', 0.40),
      _WeightedTerm('order', 'pedido', 0.32),
      _WeightedTerm('delivery', 'entrega', 0.30),
    ],
  ),
  _CategoryRule(
    id: 'finance',
    name: 'Finanças',
    description: 'Encontrou termos relacionados a finanças.',
    terms: [
      _WeightedTerm('pix', 'pix', 0.58, 'Pix'),
      _WeightedTerm('payment', 'pagamento', 0.48),
      _WeightedTerm('bill', 'boleto', 0.52),
      _WeightedTerm('invoice', 'fatura', 0.48),
      _WeightedTerm('bank', 'banco', 0.18),
      _WeightedTerm('transfer', 'transferencia', 0.46, 'transferência'),
      _WeightedTerm('balance', 'saldo', 0.34),
      _WeightedTerm('due', 'vencimento', 0.34),
    ],
  ),
  _CategoryRule(
    id: 'conversations',
    name: 'Conversas',
    description: 'Encontrou termos relacionados a conversas.',
    terms: [
      _WeightedTerm('whatsapp', 'whatsapp', 0.50, 'WhatsApp'),
      _WeightedTerm('message', 'mensagem', 0.42),
      _WeightedTerm('conversation', 'conversa', 0.44),
      _WeightedTerm('audio', 'audio', 0.32, 'áudio'),
      _WeightedTerm('call', 'chamada', 0.36),
      _WeightedTerm('answered', 'respondeu', 0.40),
      _WeightedTerm('answer', 'responder', 0.42),
    ],
  ),
  _CategoryRule(
    id: 'development',
    name: 'Desenvolvimento',
    description: 'Encontrou termos relacionados a desenvolvimento de software.',
    terms: [
      _WeightedTerm('code', 'codigo', 0.46, 'código'),
      _WeightedTerm('commit', 'commit', 0.44),
      _WeightedTerm('pull_request', 'pull request', 0.50),
      _WeightedTerm('github', 'github', 0.46, 'GitHub'),
      _WeightedTerm('error', 'erro', 0.42),
      _WeightedTerm('exception', 'exception', 0.50),
      _WeightedTerm('terminal', 'terminal', 0.42),
      _WeightedTerm('api', 'api', 0.40, 'API'),
      _WeightedTerm('flutter', 'flutter', 0.48, 'Flutter'),
      _WeightedTerm('javascript', 'javascript', 0.46, 'JavaScript'),
      _WeightedTerm('python', 'python', 0.46, 'Python'),
      _WeightedTerm('csharp', 'c#', 0.46, 'C#'),
      _WeightedTerm('database', 'banco de dados', 0.56),
      _WeightedTerm('sql', 'sql', 0.52, 'SQL'),
      _WeightedTerm('query', 'query', 0.44),
      _WeightedTerm('table', 'tabela', 0.26),
    ],
  ),
  _CategoryRule(
    id: 'documents',
    name: 'Documentos',
    description: 'Encontrou termos relacionados a documentos.',
    terms: [
      _WeightedTerm('cpf', 'cpf', 0.50, 'CPF'),
      _WeightedTerm('cnpj', 'cnpj', 0.50, 'CNPJ'),
      _WeightedTerm('contract', 'contrato', 0.48),
      _WeightedTerm('document', 'documento', 0.44),
      _WeightedTerm('receipt', 'comprovante', 0.48),
      _WeightedTerm('protocol', 'protocolo', 0.42),
      _WeightedTerm('signature', 'assinatura', 0.40),
    ],
  ),
  _CategoryRule(
    id: 'travel',
    name: 'Viagens',
    description: 'Encontrou termos relacionados a viagens.',
    terms: [
      _WeightedTerm('ticket', 'passagem', 0.44),
      _WeightedTerm('flight', 'voo', 0.48),
      _WeightedTerm('hotel', 'hotel', 0.36),
      _WeightedTerm('reservation', 'reserva', 0.42),
      _WeightedTerm('checkin', 'check in', 0.46, 'check-in'),
      _WeightedTerm('airport', 'aeroporto', 0.44),
      _WeightedTerm('boarding', 'embarque', 0.44),
    ],
  ),
];

const _tagRules = <_TagRule>[
  _TagRule(
    id: 'urgent',
    name: 'Urgente',
    description: 'Encontrou indicação de urgência.',
    terms: [
      _WeightedTerm('urgent', 'urgente', 0.78),
      _WeightedTerm('priority', 'prioridade', 0.52),
      _WeightedTerm('deadline', 'prazo', 0.42),
    ],
  ),
  _TagRule(
    id: 'needs_reply',
    name: 'Precisa responder',
    description: 'Encontrou indicação de resposta pendente.',
    terms: [
      _WeightedTerm('needs_reply', 'precisa responder', 0.78),
      _WeightedTerm('reply', 'responder', 0.68),
      _WeightedTerm('awaiting', 'aguardo retorno', 0.62),
      _WeightedTerm('confirm', 'pode confirmar', 0.54),
    ],
  ),
  _TagRule(
    id: 'interview',
    name: 'Entrevista',
    description: 'Encontrou a palavra “entrevista”.',
    terms: [_WeightedTerm('interview', 'entrevista', 0.82)],
  ),
  _TagRule(
    id: 'job',
    name: 'Vaga',
    description: 'Encontrou indicação de vaga ou candidatura.',
    terms: [
      _WeightedTerm('job', 'vaga', 0.76),
      _WeightedTerm('selection', 'processo seletivo', 0.72),
      _WeightedTerm('application', 'candidatura', 0.62),
      _WeightedTerm('internship', 'estagio', 0.52, 'estágio'),
    ],
  ),
  _TagRule(
    id: 'course',
    name: 'Curso',
    description: 'Encontrou indicação de curso ou aula.',
    terms: [
      _WeightedTerm('course', 'curso', 0.72),
      _WeightedTerm('class', 'aula', 0.52),
      _WeightedTerm('college', 'faculdade', 0.50),
    ],
  ),
  _TagRule(
    id: 'certificate',
    name: 'Certificado',
    description: 'Encontrou a palavra “certificado”.',
    terms: [_WeightedTerm('certificate', 'certificado', 0.80)],
  ),
  _TagRule(
    id: 'code',
    name: 'Código',
    description: 'Encontrou indicação de código de software.',
    terms: [
      _WeightedTerm('code', 'codigo', 0.76, 'código'),
      _WeightedTerm('terminal', 'terminal', 0.50),
      _WeightedTerm('flutter', 'flutter', 0.56, 'Flutter'),
      _WeightedTerm('python', 'python', 0.54, 'Python'),
      _WeightedTerm('sql', 'sql', 0.54, 'SQL'),
    ],
  ),
  _TagRule(
    id: 'error',
    name: 'Erro',
    description: 'Encontrou uma mensagem de erro.',
    terms: [
      _WeightedTerm('error', 'erro', 0.78),
      _WeightedTerm('exception', 'exception', 0.84),
      _WeightedTerm('failure', 'falha', 0.62),
    ],
  ),
  _TagRule(
    id: 'product',
    name: 'Produto',
    description: 'Encontrou indicação de produto ou compra.',
    terms: [
      _WeightedTerm('product', 'produto', 0.74),
      _WeightedTerm('buy', 'comprar', 0.62),
      _WeightedTerm('price', 'preco', 0.56, 'preço'),
      _WeightedTerm('cart', 'carrinho', 0.54),
    ],
  ),
  _TagRule(
    id: 'sale',
    name: 'Promoção',
    description: 'Encontrou indicação de promoção ou desconto.',
    terms: [
      _WeightedTerm('sale', 'promocao', 0.82, 'promoção'),
      _WeightedTerm('discount', 'desconto', 0.72),
    ],
  ),
  _TagRule(
    id: 'payment',
    name: 'Pagamento',
    description: 'Encontrou indicação de pagamento.',
    terms: [
      _WeightedTerm('pix', 'pix', 0.84, 'Pix'),
      _WeightedTerm('payment', 'pagamento', 0.78),
      _WeightedTerm('bill', 'boleto', 0.80),
      _WeightedTerm('invoice', 'fatura', 0.72),
    ],
    signalIds: {'pattern.brl'},
  ),
  _TagRule(
    id: 'document',
    name: 'Documento',
    description: 'Encontrou indicação de documento.',
    terms: [
      _WeightedTerm('document', 'documento', 0.74),
      _WeightedTerm('contract', 'contrato', 0.70),
      _WeightedTerm('receipt', 'comprovante', 0.74),
      _WeightedTerm('cpf', 'cpf', 0.66, 'CPF'),
      _WeightedTerm('cnpj', 'cnpj', 0.66, 'CNPJ'),
      _WeightedTerm('protocol', 'protocolo', 0.60),
    ],
  ),
  _TagRule(
    id: 'date',
    name: 'Data',
    description: 'Encontrou uma data no texto.',
    signalIds: {'pattern.date'},
  ),
  _TagRule(
    id: 'time',
    name: 'Horário',
    description: 'Encontrou um horário no texto.',
    signalIds: {'pattern.time'},
  ),
  _TagRule(
    id: 'link',
    name: 'Link',
    description: 'Encontrou um endereço de internet.',
    signalIds: {'pattern.url'},
  ),
  _TagRule(
    id: 'whatsapp',
    name: 'WhatsApp',
    description: 'Encontrou indicação de WhatsApp.',
    terms: [_WeightedTerm('whatsapp', 'whatsapp', 0.82, 'WhatsApp')],
    signalIds: {'metadata.whatsapp'},
  ),
  _TagRule(
    id: 'github',
    name: 'GitHub',
    description: 'Encontrou indicação de GitHub.',
    terms: [_WeightedTerm('github', 'github', 0.82, 'GitHub')],
    signalIds: {'metadata.github'},
  ),
  _TagRule(
    id: 'contact',
    name: 'Contato',
    description: 'Encontrou informação de contato.',
    signalIds: {'pattern.email', 'pattern.phone'},
  ),
];

final _termSeparatorPattern = RegExp(r'[^a-z0-9+#]+');
final _repeatedSpacePattern = RegExp(r'\s+');
final _urlPattern = RegExp(
  r'\b(?:https?://|www\.)[^\s<>()]+',
  caseSensitive: false,
);
final _emailPattern = RegExp(
  r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
  caseSensitive: false,
);
final _datePattern = RegExp(
  r'\b(?:0?[1-9]|[12]\d|3[01])[/.-](?:0?[1-9]|1[0-2])(?:[/.-](?:\d{2}|\d{4}))?\b',
);
final _timePattern = RegExp(
  r'\b(?:[01]?\d|2[0-3])(?:h(?:[0-5]\d)?|:[0-5]\d)\b',
  caseSensitive: false,
);
final _brlPattern = RegExp(
  r'(?:R\$\s*\d{1,3}(?:\.\d{3})*(?:,\d{2})?|\b\d+(?:,\d{2})?\s*reais\b)',
  caseSensitive: false,
);
final _phonePattern = RegExp(
  r'(?<!\d)(?:\+?55\s*)?(?:\(?[1-9]\d\)?[\s.-]*)?(?:9\d{4}|[2-8]\d{3})[\s.-]?\d{4}(?!\d)',
);

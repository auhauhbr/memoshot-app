import 'dart:math' as math;

import '../../../core/text/text_normalizer.dart';
import '../../../core/visual/local_visual_analyzer.dart';
import '../../library/domain/capture_app_context.dart';
import 'classification_models.dart';

const contextualExistingDestinationThreshold = 0.82;
const contextualNewDestinationThreshold = 0.90;
const contextualDestinationMargin = 0.15;
const contextualTagThreshold = 0.75;
const maximumContextualTags = 4;

enum SemanticSubject {
  books,
  career,
  studies,
  products,
  sports,
  conversations,
  documents,
  development,
  quotes,
  other,
  uncertain,
}

enum ContentForm {
  bookCover,
  bookExcerpt,
  quotation,
  productPage,
  socialMediaPost,
  chatList,
  chatMessage,
  jobPosting,
  article,
  scoreboard,
  sourceCode,
  errorScreen,
  receipt,
  document,
  genericImage,
  unknown,
}

enum ContentOrigin {
  conversation,
  amazon,
  reddit,
  instagram,
  linkedIn,
  gitHub,
  mercadoLivre,
  mercadoPago,
  web,
  localDocument,
  unknown,
}

enum ProbableIntent {
  read,
  learn,
  buy,
  apply,
  interview,
  reply,
  remember,
  prove,
  reference,
  unknown,
}

enum BookOrganization { singleFolder, detailed }

final class SemanticOrganizationPreferences {
  const SemanticOrganizationPreferences({
    this.bookOrganization = BookOrganization.singleFolder,
    this.quotesEnabled = false,
  });

  final BookOrganization bookOrganization;
  final bool quotesEnabled;
}

final class SemanticDestinationCandidate {
  const SemanticDestinationCandidate({
    required this.subject,
    required this.confidence,
  });

  final SemanticSubject subject;
  final double confidence;
}

final class SemanticScreenshotAnalysis {
  SemanticScreenshotAnalysis({
    required this.captureApp,
    required this.contentOrigin,
    required this.semanticSubject,
    required this.contentForm,
    required this.probableIntent,
    required List<SemanticDestinationCandidate> destinationCandidates,
    required this.semanticConfidence,
    required this.modelSource,
  }) : destinationCandidates = List.unmodifiable(destinationCandidates);

  final NormalizedCaptureAppKey? captureApp;
  final ContentOrigin contentOrigin;
  final SemanticSubject semanticSubject;
  final ContentForm contentForm;
  final ProbableIntent probableIntent;
  final List<SemanticDestinationCandidate> destinationCandidates;
  final double semanticConfidence;
  final String modelSource;

  /// Payload mínimo preparado para persistência futura. OCR, imagem, prompts e
  /// explicações deliberadamente não fazem parte deste contrato.
  Map<String, Object?> toPersistenceFields() => {
    'captureApp': captureApp?.name,
    'contentOrigin': contentOrigin.name,
    'semanticSubject': semanticSubject.name,
    'contentForm': contentForm.name,
    'probableIntent': probableIntent.name,
    'semanticConfidence': semanticConfidence,
    'modelSource': modelSource,
  };
}

final class SemanticClassificationCorrection {
  const SemanticClassificationCorrection({
    required this.previousCategory,
    required this.manualCategory,
    required this.correctedSubject,
    required this.correctedForm,
  });

  final String? previousCategory;
  final String manualCategory;
  final SemanticSubject correctedSubject;
  final ContentForm correctedForm;
}

final class SemanticScreenshotInput {
  const SemanticScreenshotInput({
    required this.normalizedOcr,
    required this.visualAnalysis,
    required this.captureAppContext,
    required this.allowedCatalog,
    required this.preferences,
  });

  final String normalizedOcr;
  final VisualAnalysisResult? visualAnalysis;
  final CaptureAppContext? captureAppContext;
  final Set<String> allowedCatalog;
  final SemanticOrganizationPreferences preferences;
}

abstract interface class SemanticScreenshotAnalyzer {
  SemanticScreenshotAnalysis analyze(SemanticScreenshotInput input);
}

abstract interface class LocalTextEmbeddingModel {
  List<double> encode(String normalizedText);

  String get modelSource;
}

/// Baseline pequeno da prova A. Ele transforma texto em um vetor de n-gramas e
/// compara o vetor completo com exemplos semânticos. Não soma palavras nem usa
/// o aplicativo capturado como classe de destino.
final class FeatureHashingTextEmbeddingModel
    implements LocalTextEmbeddingModel {
  const FeatureHashingTextEmbeddingModel({this.dimensions = 1024});

  final int dimensions;

  @override
  String get modelSource => 'local-feature-embedding-v1+mlkit-aux';

  @override
  List<double> encode(String normalizedText) {
    final result = List<double>.filled(dimensions, 0);
    final tokens = normalizedText
        .split(RegExp(r'\s+'))
        .where((token) => token.length > 1)
        .toList(growable: false);
    for (var index = 0; index < tokens.length; index++) {
      _add(result, tokens[index], 1);
      if (index + 1 < tokens.length) {
        _add(result, '${tokens[index]} ${tokens[index + 1]}', 0.65);
      }
      final padded = '^${tokens[index]}\$';
      for (var offset = 0; offset + 3 <= padded.length; offset++) {
        _add(result, padded.substring(offset, offset + 3), 0.18);
      }
    }
    final magnitude = math.sqrt(
      result.fold<double>(0, (sum, v) => sum + v * v),
    );
    if (magnitude > 0) {
      for (var index = 0; index < result.length; index++) {
        result[index] /= magnitude;
      }
    }
    return result;
  }

  void _add(List<double> vector, String feature, double weight) {
    var hash = 0x811c9dc5;
    for (final unit in feature.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    vector[hash % vector.length] += weight;
  }
}

final class LocalSemanticScreenshotAnalyzer
    implements SemanticScreenshotAnalyzer {
  LocalSemanticScreenshotAnalyzer({
    this.normalizer = const TextNormalizer(),
    this.embeddingModel = const FeatureHashingTextEmbeddingModel(),
  });

  final TextNormalizer normalizer;
  final LocalTextEmbeddingModel embeddingModel;

  late final Map<SemanticSubject, List<double>> _subjectVectors = {
    for (final entry in _subjectPrototypes.entries)
      entry.key: embeddingModel.encode(normalizer.normalize(entry.value)),
  };
  late final Map<ContentForm, List<double>> _formVectors = {
    for (final entry in _formPrototypes.entries)
      entry.key: embeddingModel.encode(normalizer.normalize(entry.value)),
  };

  @override
  SemanticScreenshotAnalysis analyze(SemanticScreenshotInput input) {
    final text = normalizer.normalize(input.normalizedOcr);
    final visualText =
        input.visualAnalysis?.labels
            .where((label) => label.confidence >= 0.55)
            .map((label) => label.key)
            .join(' ') ??
        '';
    final textVector = embeddingModel.encode(text);
    final visualVector = embeddingModel.encode(visualText);
    final subjectScores = <SemanticSubject, double>{
      for (final entry in _subjectVectors.entries)
        entry.key: _fusedSimilarity(textVector, visualVector, entry.value),
    };
    final ranked = subjectScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    final understood = text.isNotEmpty && best.value >= 0.04;
    var subject = understood ? best.key : SemanticSubject.uncertain;
    var confidence = understood
        ? (0.78 + best.value * 0.32).clamp(0, 0.99).toDouble()
        : 0.25;
    var form = _classifyForm(
      text: text,
      textVector: textVector,
      visualVector: visualVector,
      subject: subject,
      captureApp: input.captureAppContext?.normalizedAppKey,
    );
    final quoteSimilarity = subjectScores[SemanticSubject.quotes] ?? 0;
    if (understood &&
        (best.key == SemanticSubject.quotes ||
            (best.key == SemanticSubject.books && quoteSimilarity >= 0.04))) {
      form = ContentForm.quotation;
    }
    final origin = _contentOrigin(
      text,
      form: form,
      captureApp: input.captureAppContext?.normalizedAppKey,
    );

    // Uma citação só é Livro quando o texto também se aproxima do conceito de
    // obra/autoria. A conversa é apenas o meio pelo qual ela chegou.
    if (form == ContentForm.quotation) {
      final bookSimilarity = subjectScores[SemanticSubject.books] ?? 0;
      if (bookSimilarity >= 0.07 && bookSimilarity >= quoteSimilarity * 0.55) {
        subject = SemanticSubject.books;
        confidence = math.max(confidence, 0.86);
      } else {
        subject = SemanticSubject.quotes;
        confidence = math.max(confidence, 0.84);
      }
    }
    if (subject == SemanticSubject.career &&
        (form == ContentForm.chatList || form == ContentForm.chatMessage)) {
      form = ContentForm.jobPosting;
    }

    final candidates = understood
        ? ranked
              .where((entry) => entry.value >= 0.12)
              .take(3)
              .map(
                (entry) => SemanticDestinationCandidate(
                  subject: entry.key,
                  confidence: (0.45 + entry.value * 0.40)
                      .clamp(0, 0.99)
                      .toDouble(),
                ),
              )
              .toList(growable: false)
        : const <SemanticDestinationCandidate>[];
    final adjustedCandidates = <SemanticDestinationCandidate>[
      if (subject != SemanticSubject.uncertain)
        SemanticDestinationCandidate(subject: subject, confidence: confidence),
      for (final candidate in candidates)
        if (candidate.subject != subject) candidate,
    ].take(3).toList(growable: false);
    return SemanticScreenshotAnalysis(
      captureApp: input.captureAppContext?.normalizedAppKey,
      contentOrigin: origin,
      semanticSubject: subject,
      contentForm: form,
      probableIntent: _intent(subject, form, textVector),
      destinationCandidates: adjustedCandidates,
      semanticConfidence: confidence,
      modelSource: embeddingModel.modelSource,
    );
  }

  ContentForm _classifyForm({
    required String text,
    required List<double> textVector,
    required List<double> visualVector,
    required SemanticSubject subject,
    required NormalizedCaptureAppKey? captureApp,
  }) {
    if (text.isEmpty) return ContentForm.unknown;
    final ranked =
        _formVectors.entries
            .map(
              (entry) => MapEntry(
                entry.key,
                _fusedSimilarity(textVector, visualVector, entry.value),
              ),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final semanticForm = ranked.first.value >= 0.15
        ? ranked.first.key
        : ContentForm.unknown;
    if (subject == SemanticSubject.books) {
      if (semanticForm == ContentForm.quotation) return semanticForm;
      if (semanticForm == ContentForm.bookCover ||
          captureApp == NormalizedCaptureAppKey.amazon) {
        return ContentForm.bookCover;
      }
      return ContentForm.bookExcerpt;
    }
    if (subject == SemanticSubject.products) {
      if (captureApp == NormalizedCaptureAppKey.instagram) {
        return ContentForm.socialMediaPost;
      }
      return ContentForm.productPage;
    }
    if (subject == SemanticSubject.career) return ContentForm.jobPosting;
    if (subject == SemanticSubject.sports) return ContentForm.scoreboard;
    if (subject == SemanticSubject.development) {
      return semanticForm == ContentForm.errorScreen
          ? ContentForm.errorScreen
          : ContentForm.sourceCode;
    }
    if (subject == SemanticSubject.documents) {
      return semanticForm == ContentForm.receipt
          ? ContentForm.receipt
          : ContentForm.document;
    }
    if (semanticForm == ContentForm.quotation) return semanticForm;
    if (captureApp == NormalizedCaptureAppKey.whatsapp) {
      return semanticForm == ContentForm.chatList
          ? ContentForm.chatList
          : ContentForm.chatMessage;
    }
    return semanticForm;
  }

  double _fusedSimilarity(
    List<double> text,
    List<double> visual,
    List<double> prototype,
  ) => _cosine(text, prototype) * 0.88 + _cosine(visual, prototype) * 0.12;

  double _cosine(List<double> first, List<double> second) {
    var dot = 0.0;
    for (var index = 0; index < first.length; index++) {
      dot += first[index] * second[index];
    }
    return dot.clamp(0, 1).toDouble();
  }

  ContentOrigin _contentOrigin(
    String text, {
    required ContentForm form,
    required NormalizedCaptureAppKey? captureApp,
  }) {
    if (text.contains('amazon.com') || text.contains('amazonbrasil')) {
      return ContentOrigin.amazon;
    }
    if (text.contains('reddit.com') || text.contains(' r/')) {
      return ContentOrigin.reddit;
    }
    if (text.contains('linkedin.com')) return ContentOrigin.linkedIn;
    if (text.contains('github.com')) return ContentOrigin.gitHub;
    if (text.contains('mercadolivre.com')) return ContentOrigin.mercadoLivre;
    if (text.contains('mercadopago.com')) return ContentOrigin.mercadoPago;
    if (text.contains('whatsapp')) return ContentOrigin.conversation;
    if (captureApp == NormalizedCaptureAppKey.amazon) {
      return ContentOrigin.amazon;
    }
    if (captureApp == NormalizedCaptureAppKey.whatsapp) {
      return ContentOrigin.conversation;
    }
    if (form == ContentForm.chatList ||
        form == ContentForm.chatMessage ||
        (captureApp == NormalizedCaptureAppKey.whatsapp &&
            form == ContentForm.jobPosting)) {
      return ContentOrigin.conversation;
    }
    if (captureApp == NormalizedCaptureAppKey.instagram) {
      return ContentOrigin.instagram;
    }
    if (captureApp?.isBrowser == true) return ContentOrigin.web;
    return ContentOrigin.unknown;
  }

  ProbableIntent _intent(
    SemanticSubject subject,
    ContentForm form,
    List<double> textVector,
  ) {
    if (form == ContentForm.receipt) return ProbableIntent.prove;
    if (form == ContentForm.jobPosting) {
      final interview = _cosine(
        textVector,
        embeddingModel.encode(
          normalizer.normalize(
            'entrevista entrevistador recrutadora reunião entrevista técnica',
          ),
        ),
      );
      final vacancy = _cosine(
        textVector,
        embeddingModel.encode(
          normalizer.normalize(
            'discussão mercado trabalho recrutamento vagas oportunidade emprego requisitos',
          ),
        ),
      );
      return interview > vacancy + 0.03
          ? ProbableIntent.interview
          : ProbableIntent.apply;
    }
    if (form == ContentForm.productPage ||
        form == ContentForm.socialMediaPost &&
            subject == SemanticSubject.products) {
      return ProbableIntent.buy;
    }
    if (form == ContentForm.chatMessage || form == ContentForm.chatList) {
      return ProbableIntent.reply;
    }
    return switch (subject) {
      SemanticSubject.books => ProbableIntent.read,
      SemanticSubject.studies => ProbableIntent.learn,
      SemanticSubject.development ||
      SemanticSubject.documents => ProbableIntent.reference,
      SemanticSubject.uncertain => ProbableIntent.unknown,
      _ => ProbableIntent.remember,
    };
  }
}

const _subjectPrototypes = <SemanticSubject, String>{
  SemanticSubject.books:
      'obra literária livro romance autor editora capítulo página trecho leitura capa sinopse isbn',
  SemanticSubject.career:
      'emprego trabalho oportunidade profissional recrutamento candidatura seleção currículo entrevista vaga',
  SemanticSubject.studies:
      'estudo aprendizado aula curso exercício matéria prova professor conteúdo didático',
  SemanticSubject.products:
      'produto oferta loja preço comprar carrinho entrega promoção marca modelo venda',
  SemanticSubject.sports:
      'esporte jogo partida campeonato time placar resultado classificação futebol',
  SemanticSubject.conversations:
      'conversa contato mensagem grupo áudio responder chamada bate papo',
  SemanticSubject.documents:
      'documento recibo comprovante pagamento contrato protocolo nota fiscal transação',
  SemanticSubject.development:
      'programação código fonte terminal erro exception stack trace compilação github flutter',
  SemanticSubject.quotes:
      'citação frase reflexão pensamento aforismo mensagem inspiradora aspas',
};

const _formPrototypes = <ContentForm, String>{
  ContentForm.bookCover: 'capa título autor editora isbn edição livro',
  ContentForm.bookExcerpt:
      'página capítulo parágrafo trecho texto leitura livro',
  ContentForm.quotation:
      'frase entre aspas citação autoria reflexão trecho citado',
  ContentForm.productPage:
      'página produto preço comprar carrinho frete entrega',
  ContentForm.socialMediaPost:
      'publicação perfil seguidores curtir comentar compartilhar instagram',
  ContentForm.chatList: 'lista conversas grupos contatos mensagens recentes',
  ContentForm.chatMessage: 'mensagem conversa responder áudio online contato',
  ContentForm.jobPosting:
      'anúncio vaga candidatura requisitos emprego processo seletivo',
  ContentForm.article: 'artigo notícia título matéria publicação leitura',
  ContentForm.scoreboard: 'placar resultado partida time campeonato tabela',
  ContentForm.sourceCode: 'código função classe variável terminal programação',
  ContentForm.errorScreen:
      'erro exception stack trace falha terminal compilação',
  ContentForm.receipt:
      'comprovante pagamento transação valor favorecido autenticação pix',
  ContentForm.document: 'documento contrato protocolo formulário identificação',
};

final class SemanticDestination {
  const SemanticDestination({
    required this.root,
    this.subfolder,
    required this.confidence,
    required this.margin,
  });

  final String? root;
  final String? subfolder;
  final double confidence;
  final double margin;

  String? get persistedName => root == null
      ? null
      : subfolder == null
      ? root
      : '$root / $subfolder';
}

final class SemanticDestinationPolicy {
  const SemanticDestinationPolicy();

  SemanticDestination resolve({
    required SemanticScreenshotAnalysis analysis,
    required Set<String> allowedCatalog,
    required SemanticOrganizationPreferences preferences,
  }) {
    if (analysis.semanticSubject == SemanticSubject.uncertain) {
      return const SemanticDestination(root: null, confidence: 0.25, margin: 0);
    }
    var root = switch (analysis.semanticSubject) {
      SemanticSubject.books => 'Livros',
      SemanticSubject.career => 'Carreira',
      SemanticSubject.studies => 'Estudos',
      SemanticSubject.products => 'Produtos',
      SemanticSubject.sports => 'Esportes',
      SemanticSubject.conversations => 'Conversas',
      SemanticSubject.documents => 'Documentos',
      SemanticSubject.development => 'Desenvolvimento',
      SemanticSubject.quotes when preferences.quotesEnabled => 'Citações',
      SemanticSubject.other => 'Outros',
      _ => null,
    };
    if (root == null || !allowedCatalog.contains(root)) {
      return SemanticDestination(
        root: null,
        confidence: analysis.semanticConfidence,
        margin: 0,
      );
    }
    String? child;
    if (root == 'Livros' &&
        preferences.bookOrganization == BookOrganization.detailed) {
      child = switch (analysis.contentForm) {
        ContentForm.bookCover => 'Capas',
        ContentForm.bookExcerpt => 'Trechos',
        ContentForm.quotation => 'Citações',
        _ => null,
      };
    } else if (root == 'Carreira' &&
        analysis.contentForm == ContentForm.jobPosting) {
      child = analysis.probableIntent == ProbableIntent.interview
          ? 'Entrevistas'
          : 'Vagas';
    } else if (root == 'Documentos' &&
        analysis.contentForm == ContentForm.receipt) {
      child = 'Comprovantes';
    } else if (root == 'Desenvolvimento') {
      child = analysis.contentForm == ContentForm.errorScreen
          ? 'Erros'
          : 'Código';
    }
    if (child != null && !allowedCatalog.contains('$root / $child')) {
      child = null;
    }
    final second = analysis.destinationCandidates
        .where((candidate) => candidate.subject != analysis.semanticSubject)
        .map((candidate) => candidate.confidence)
        .firstOrNull;
    return SemanticDestination(
      root: root,
      subfolder: child,
      confidence: analysis.semanticConfidence,
      margin: (analysis.semanticConfidence - (second ?? 0))
          .clamp(0, 1)
          .toDouble(),
    );
  }
}

// Tipos legados mantidos na borda enquanto sugestões persistidas ainda usam o
// contrato anterior. O decisor, porém, é exclusivamente a análise semântica.
enum ProbableOrigin {
  whatsapp,
  amazon,
  mercadoLivre,
  mercadoPago,
  linkedIn,
  instagram,
  gitHub,
  browser,
  reddit,
  unknown,
}

enum VisualContentType {
  conversation,
  productPage,
  bookCover,
  bookExcerpt,
  quotation,
  resultTable,
  code,
  error,
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
  conversations,
  quotes,
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
    required this.analysis,
    required this.origin,
    required this.visualType,
    required this.subject,
    required this.destination,
    required this.signals,
    required this.captureAppContext,
    required List<ClassificationEvidence> evidence,
  }) : evidence = List.unmodifiable(evidence);
  final SemanticScreenshotAnalysis analysis;
  final ContextualDimension<ProbableOrigin> origin;
  final ContextualDimension<VisualContentType> visualType;
  final ContextualDimension<ContentSubject> subject;
  final ContextualDestination destination;
  final ContextualSignals signals;
  final CaptureAppContext? captureAppContext;
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
    'Livros': {'Capas', 'Trechos', 'Citações'},
    'Carreira': {'Vagas', 'Entrevistas'},
    'Estudos': {'Cursos', 'Materiais'},
    'Documentos': {'Comprovantes'},
    'Desenvolvimento': {'Código', 'Erros'},
    'Produtos': {},
    'Esportes': {},
    'Conversas': {},
    'Outros': {},
  };
  static Set<String> get paths => {
    ...roots,
    for (final entry in children.entries)
      for (final child in entry.value) '${entry.key} / $child',
  };
  static bool accepts(String root, String? child) =>
      roots.contains(root) &&
      (child == null || children[root]!.contains(child));
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
    return values
        .where((value) => const TextNormalizer().normalize(value) == normalized)
        .firstOrNull;
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
    'Reddit',
    'Produto',
    'Livro',
    'Conversa',
    'Código',
    'Documento',
    'Comprovante',
    'Pagamento',
    'Tabela',
    'Vaga',
    'Curso',
    'Futebol',
    'Citação',
    'Carro',
    'Notebook',
    'Teclado',
    'Peça mecânica',
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
    this.analyzer,
    this.destinationPolicy = const SemanticDestinationPolicy(),
    this.preferences = const SemanticOrganizationPreferences(),
  });

  final TextNormalizer normalizer;
  final SemanticScreenshotAnalyzer? analyzer;
  final SemanticDestinationPolicy destinationPolicy;
  final SemanticOrganizationPreferences preferences;

  ContextualClassificationResult classify({
    required String ocrText,
    VisualAnalysisResult? visualAnalysis,
    CaptureAppContext? captureAppContext,
  }) {
    final normalized = normalizer.normalize(ocrText);
    final analysis =
        (analyzer ?? LocalSemanticScreenshotAnalyzer(normalizer: normalizer))
            .analyze(
              SemanticScreenshotInput(
                normalizedOcr: normalized,
                visualAnalysis: visualAnalysis,
                captureAppContext: captureAppContext,
                allowedCatalog: ContextualFolderCatalog.paths,
                preferences: preferences,
              ),
            );
    final resolved = destinationPolicy.resolve(
      analysis: analysis,
      allowedCatalog: ContextualFolderCatalog.paths,
      preferences: preferences,
    );
    final tags = _tagsFor(analysis);
    final evidence = <ClassificationEvidence>[
      ClassificationEvidence(
        ruleId: 'semantic.model.${analysis.modelSource}',
        type: ClassificationEvidenceType.pattern,
        description: 'Análise semântica multimodal executada localmente.',
        weight: analysis.semanticConfidence,
      ),
      ClassificationEvidence(
        ruleId: 'context.destination.margin',
        type: ClassificationEvidenceType.pattern,
        description: 'Margem entre candidatos semânticos.',
        weight: resolved.margin,
      ),
    ];
    final signals = _signals(ocrText, normalized, analysis);
    return ContextualClassificationResult(
      analysis: analysis,
      origin: ContextualDimension(
        value: _legacyOrigin(analysis),
        confidence: analysis.contentOrigin == ContentOrigin.unknown ? 0 : 0.9,
      ),
      visualType: ContextualDimension(
        value: _legacyForm(analysis.contentForm),
        confidence: analysis.semanticConfidence,
      ),
      subject: ContextualDimension(
        value: _legacySubject(analysis.semanticSubject),
        confidence: analysis.semanticConfidence,
      ),
      destination: ContextualDestination(
        root: resolved.root,
        subfolder: resolved.subfolder,
        confidence: resolved.confidence,
        margin: resolved.margin,
        tags: tags,
      ),
      signals: signals,
      captureAppContext: captureAppContext,
      evidence: evidence,
    );
  }

  List<SuggestedTag> _tagsFor(SemanticScreenshotAnalysis analysis) {
    final values = <String>{};
    final originTag = switch (analysis.contentOrigin) {
      ContentOrigin.amazon => 'Amazon',
      ContentOrigin.reddit => 'Reddit',
      ContentOrigin.instagram => 'Instagram',
      ContentOrigin.linkedIn => 'LinkedIn',
      ContentOrigin.gitHub => 'GitHub',
      ContentOrigin.mercadoLivre => 'Mercado Livre',
      ContentOrigin.mercadoPago => 'Mercado Pago',
      ContentOrigin.web => 'Navegador',
      ContentOrigin.conversation => 'WhatsApp',
      _ => null,
    };
    if (originTag != null) values.add(originTag);
    final subjectTag = switch (analysis.semanticSubject) {
      SemanticSubject.books => 'Livro',
      SemanticSubject.products => 'Produto',
      SemanticSubject.career => 'Vaga',
      SemanticSubject.sports => 'Futebol',
      SemanticSubject.conversations => 'Conversa',
      SemanticSubject.documents => 'Documento',
      SemanticSubject.development => 'Código',
      SemanticSubject.quotes => 'Citação',
      SemanticSubject.studies => 'Curso',
      _ => null,
    };
    if (subjectTag != null) values.add(subjectTag);
    if (analysis.contentForm == ContentForm.receipt) values.add('Comprovante');
    if (analysis.contentForm == ContentForm.scoreboard) values.add('Tabela');
    return values
        .take(maximumContextualTags)
        .map((name) {
          final evidence = ClassificationEvidence(
            ruleId:
                'semantic.tag.${normalizer.normalize(name).replaceAll(' ', '_')}',
            type: ClassificationEvidenceType.pattern,
            description: 'Etiqueta derivada da análise estruturada.',
            weight: analysis.semanticConfidence,
          );
          return SuggestedTag(
            name: name,
            confidence: analysis.semanticConfidence,
            evidence: [evidence],
          );
        })
        .toList(growable: false);
  }

  ContextualSignals _signals(
    String raw,
    String normalized,
    SemanticScreenshotAnalysis analysis,
  ) {
    final currency = RegExp(r'(?:R\$|US\$|€)\s*\d').hasMatch(raw);
    final time = RegExp(r'\b(?:[01]?\d|2[0-3]):[0-5]\d\b').hasMatch(raw);
    final date = RegExp(
      r'\b\d{1,2}[/.-]\d{1,2}(?:[/.-]\d{2,4})?\b',
    ).hasMatch(raw);
    final score = RegExp(
      r'\b\d{1,2}\s*(?:x|-)\s*\d{1,2}\b',
      caseSensitive: false,
    ).hasMatch(raw);
    final transaction = analysis.contentForm == ContentForm.receipt;
    final product = analysis.semanticSubject == SemanticSubject.products;
    return ContextualSignals(
      hasCurrencyValue: currency,
      hasProductPrice: currency && product && !transaction,
      hasPaymentEvidence: transaction,
      hasTransactionEvidence: transaction,
      hasDate: date,
      hasTime: time,
      hasContextualTime:
          time &&
          (analysis.contentForm == ContentForm.jobPosting ||
              analysis.contentForm == ContentForm.scoreboard),
      hasScore: score && analysis.semanticSubject == SemanticSubject.sports,
      hasTitle: analysis.contentForm == ContentForm.bookCover,
      hasBrand: analysis.contentOrigin != ContentOrigin.unknown,
      hasDomain: normalized.contains('.com'),
      hasProbableApp: analysis.captureApp != null,
      hasStrongNegative:
          (currency && product && !transaction) ||
          (time && analysis.probableIntent == ProbableIntent.unknown),
    );
  }

  ProbableOrigin _legacyOrigin(SemanticScreenshotAnalysis analysis) {
    return switch (analysis.contentOrigin) {
      ContentOrigin.conversation => ProbableOrigin.whatsapp,
      ContentOrigin.amazon => ProbableOrigin.amazon,
      ContentOrigin.reddit => ProbableOrigin.reddit,
      ContentOrigin.instagram => ProbableOrigin.instagram,
      ContentOrigin.linkedIn => ProbableOrigin.linkedIn,
      ContentOrigin.gitHub => ProbableOrigin.gitHub,
      ContentOrigin.mercadoLivre => ProbableOrigin.mercadoLivre,
      ContentOrigin.mercadoPago => ProbableOrigin.mercadoPago,
      ContentOrigin.web => ProbableOrigin.browser,
      ContentOrigin.localDocument ||
      ContentOrigin.unknown => ProbableOrigin.unknown,
    };
  }

  VisualContentType _legacyForm(ContentForm form) => switch (form) {
    ContentForm.bookCover => VisualContentType.bookCover,
    ContentForm.bookExcerpt => VisualContentType.bookExcerpt,
    ContentForm.quotation => VisualContentType.quotation,
    ContentForm.productPage => VisualContentType.productPage,
    ContentForm.socialMediaPost => VisualContentType.post,
    ContentForm.chatList ||
    ContentForm.chatMessage ||
    ContentForm.jobPosting => VisualContentType.conversation,
    ContentForm.scoreboard => VisualContentType.resultTable,
    ContentForm.sourceCode => VisualContentType.code,
    ContentForm.errorScreen => VisualContentType.error,
    ContentForm.receipt => VisualContentType.receipt,
    ContentForm.document => VisualContentType.document,
    _ => VisualContentType.genericInterface,
  };

  ContentSubject _legacySubject(SemanticSubject subject) => switch (subject) {
    SemanticSubject.books => ContentSubject.books,
    SemanticSubject.products => ContentSubject.products,
    SemanticSubject.career => ContentSubject.career,
    SemanticSubject.studies => ContentSubject.studies,
    SemanticSubject.sports => ContentSubject.sports,
    SemanticSubject.development => ContentSubject.development,
    SemanticSubject.documents => ContentSubject.documents,
    SemanticSubject.conversations => ContentSubject.conversations,
    SemanticSubject.quotes => ContentSubject.quotes,
    _ => ContentSubject.unknown,
  };
}

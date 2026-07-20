import 'package:flutter_test/flutter_test.dart';
import 'package:memoshot/core/visual/local_visual_analyzer.dart';
import 'package:memoshot/features/classification/domain/contextual_classification.dart';
import 'package:memoshot/features/library/domain/capture_app_context.dart';

void main() {
  group('análise semântica multimodal local', () {
    final cases = <_SemanticCase>[
      _SemanticCase(
        name: 'trecho de livro recebido no WhatsApp',
        ocr:
            'Grupo de leitura. No capítulo oito o narrador recorda a infância. Trecho da obra de Ana Lima.',
        app: NormalizedCaptureAppKey.whatsapp,
        subject: SemanticSubject.books,
        form: ContentForm.bookExcerpt,
        origin: ContentOrigin.conversation,
        destination: 'Livros',
      ),
      _SemanticCase(
        name: 'capa de livro na Amazon aberta no Brave',
        ocr:
            'amazon.com.br A cidade invisível, romance de Ana Lima, capa comum, editora Horizonte, ISBN 1234',
        app: NormalizedCaptureAppKey.brave,
        subject: SemanticSubject.books,
        form: ContentForm.bookCover,
        origin: ContentOrigin.amazon,
        destination: 'Livros',
      ),
      _SemanticCase(
        name: 'citação literária em conversa',
        ocr:
            '“A memória também inventa caminhos.” Citação do romance A cidade invisível, de Ana Lima.',
        app: NormalizedCaptureAppKey.whatsapp,
        subject: SemanticSubject.books,
        form: ContentForm.quotation,
        origin: ContentOrigin.conversation,
        destination: 'Livros',
      ),
      _SemanticCase(
        name: 'grupos de vagas no WhatsApp',
        ocr:
            'Vagas Recife | Oportunidades de emprego | Processo seletivo para pessoa desenvolvedora | enviar currículo',
        app: NormalizedCaptureAppKey.whatsapp,
        subject: SemanticSubject.career,
        form: ContentForm.jobPosting,
        origin: ContentOrigin.conversation,
        destination: 'Carreira / Vagas',
      ),
      _SemanticCase(
        name: 'produto da Amazon publicado no Instagram',
        ocr:
            'amazonbrasil Publicação patrocinada. Fone sem fio em oferta, preço especial, confira o produto.',
        app: NormalizedCaptureAppKey.instagram,
        subject: SemanticSubject.products,
        form: ContentForm.socialMediaPost,
        origin: ContentOrigin.amazon,
        destination: 'Produtos',
      ),
      _SemanticCase(
        name: 'discussão de emprego no Reddit',
        ocr:
            'reddit.com r/brasilcarreiras Discussão: como está o mercado de trabalho e o recrutamento para novas vagas?',
        app: NormalizedCaptureAppKey.brave,
        subject: SemanticSubject.career,
        form: ContentForm.jobPosting,
        origin: ContentOrigin.reddit,
        destination: 'Carreira / Vagas',
      ),
      _SemanticCase(
        name: 'placar esportivo',
        ocr: 'Final do campeonato Brasil 2 x 1 Argentina placar e resultado',
        app: NormalizedCaptureAppKey.brave,
        subject: SemanticSubject.sports,
        form: ContentForm.scoreboard,
        origin: ContentOrigin.web,
        destination: 'Esportes',
      ),
      _SemanticCase(
        name: 'código fonte',
        ocr:
            'class UserRepository { Future<void> save() async {} } Flutter código fonte',
        app: NormalizedCaptureAppKey.brave,
        subject: SemanticSubject.development,
        form: ContentForm.sourceCode,
        origin: ContentOrigin.web,
        destination: 'Desenvolvimento / Código',
      ),
      _SemanticCase(
        name: 'comprovante',
        ocr:
            'Comprovante Pix pagamento realizado valor R\$ 90,00 favorecido Maria autenticação 123',
        app: NormalizedCaptureAppKey.mercadoPago,
        subject: SemanticSubject.documents,
        form: ContentForm.receipt,
        origin: ContentOrigin.unknown,
        destination: 'Documentos / Comprovantes',
      ),
      _SemanticCase(
        name: 'conversa genérica',
        ocr:
            'Marina online mensagem de áudio vamos conversar e responder depois',
        app: NormalizedCaptureAppKey.whatsapp,
        subject: SemanticSubject.conversations,
        form: ContentForm.chatMessage,
        origin: ContentOrigin.conversation,
        destination: 'Conversas',
      ),
    ];

    for (final semanticCase in cases) {
      test(semanticCase.name, () {
        final result = const ContextualClassificationEngine().classify(
          ocrText: semanticCase.ocr,
          captureAppContext: _captureContext(semanticCase.app),
          visualAnalysis: _visualFor(semanticCase.form),
        );

        expect(result.analysis.captureApp, semanticCase.app);
        expect(result.analysis.contentOrigin, semanticCase.origin);
        expect(result.analysis.semanticSubject, semanticCase.subject);
        expect(result.analysis.contentForm, semanticCase.form);
        expect(result.destination.persistedName, semanticCase.destination);
        expect(result.analysis.modelSource, contains('local'));
      });
    }

    test('imagem verdadeiramente ambígua fica uncertain e não vira Outros', () {
      final result = const ContextualClassificationEngine().classify(
        ocrText: '',
        visualAnalysis: _visual('screenshot'),
        captureAppContext: _captureContext(NormalizedCaptureAppKey.whatsapp),
      );

      expect(result.analysis.captureApp, NormalizedCaptureAppKey.whatsapp);
      expect(result.analysis.semanticSubject, SemanticSubject.uncertain);
      expect(result.destination.root, isNull);
      expect(result.toSuggestion().suggestedCategoryName, isNull);
    });

    test('aplicativo sozinho nunca define a pasta', () {
      final whatsapp = const ContextualClassificationEngine().classify(
        ocrText: '',
        captureAppContext: _captureContext(NormalizedCaptureAppKey.whatsapp),
      );
      final amazon = const ContextualClassificationEngine().classify(
        ocrText: '',
        captureAppContext: _captureContext(NormalizedCaptureAppKey.amazon),
      );

      expect(whatsapp.destination.root, isNull);
      expect(amazon.destination.root, isNull);
    });

    test('citação genérica usa Citações somente quando habilitada', () {
      final analyzer = LocalSemanticScreenshotAnalyzer();
      final analysis = analyzer.analyze(
        SemanticScreenshotInput(
          normalizedOcr:
              '“Faça hoje o que aproxima você dos seus sonhos.” frase inspiradora',
          visualAnalysis: null,
          captureAppContext: _captureContext(NormalizedCaptureAppKey.whatsapp),
          allowedCatalog: const {'Citações'},
          preferences: const SemanticOrganizationPreferences(
            quotesEnabled: true,
          ),
        ),
      );
      final destination = const SemanticDestinationPolicy().resolve(
        analysis: analysis,
        allowedCatalog: const {'Citações'},
        preferences: const SemanticOrganizationPreferences(quotesEnabled: true),
      );

      expect(analysis.semanticSubject, SemanticSubject.quotes);
      expect(analysis.contentForm, ContentForm.quotation);
      expect(destination.persistedName, 'Citações');
    });
  });

  group('política de organização de livros', () {
    test('preferência muda destino sem executar novamente a análise', () {
      final analyzer = LocalSemanticScreenshotAnalyzer();
      final analysis = analyzer.analyze(
        SemanticScreenshotInput(
          normalizedOcr: 'livro capa título autor editora isbn',
          visualAnalysis: _visual('book'),
          captureAppContext: _captureContext(NormalizedCaptureAppKey.amazon),
          allowedCatalog: ContextualFolderCatalog.paths,
          preferences: const SemanticOrganizationPreferences(),
        ),
      );
      const policy = SemanticDestinationPolicy();
      final single = policy.resolve(
        analysis: analysis,
        allowedCatalog: ContextualFolderCatalog.paths,
        preferences: const SemanticOrganizationPreferences(),
      );
      final detailed = policy.resolve(
        analysis: analysis,
        allowedCatalog: ContextualFolderCatalog.paths,
        preferences: const SemanticOrganizationPreferences(
          bookOrganization: BookOrganization.detailed,
        ),
      );

      expect(single.persistedName, 'Livros');
      expect(detailed.persistedName, 'Livros / Capas');
    });

    test('persistência mínima não contém OCR, imagem ou explicação', () {
      final analysis = LocalSemanticScreenshotAnalyzer().analyze(
        SemanticScreenshotInput(
          normalizedOcr: 'livro capítulo trecho autor',
          visualAnalysis: null,
          captureAppContext: _captureContext(NormalizedCaptureAppKey.whatsapp),
          allowedCatalog: ContextualFolderCatalog.paths,
          preferences: const SemanticOrganizationPreferences(),
        ),
      );

      expect(analysis.toPersistenceFields().keys, {
        'captureApp',
        'contentOrigin',
        'semanticSubject',
        'contentForm',
        'probableIntent',
        'semanticConfidence',
        'modelSource',
      });
    });
  });
}

final class _SemanticCase {
  const _SemanticCase({
    required this.name,
    required this.ocr,
    required this.app,
    required this.subject,
    required this.form,
    required this.origin,
    required this.destination,
  });

  final String name;
  final String ocr;
  final NormalizedCaptureAppKey app;
  final SemanticSubject subject;
  final ContentForm form;
  final ContentOrigin origin;
  final String destination;
}

VisualAnalysisResult _visualFor(ContentForm form) => switch (form) {
  ContentForm.bookCover || ContentForm.bookExcerpt => _visual('book'),
  ContentForm.productPage || ContentForm.socialMediaPost => _visual('product'),
  ContentForm.scoreboard => _visual('football'),
  ContentForm.receipt || ContentForm.document => _visual('document'),
  _ => _visual('text'),
};

VisualAnalysisResult _visual(String key) => VisualAnalysisResult(
  labels: [VisualLabel(key: key, confidence: 0.95)],
  analyzerVersion: 'test-auxiliary',
);

CaptureAppContext _captureContext(NormalizedCaptureAppKey key) =>
    CaptureAppContext(
      packageName: 'technical.package',
      normalizedAppKey: key,
      eventTimestamp: DateTime.utc(2026, 7, 19, 12),
      captureTimestamp: DateTime.utc(2026, 7, 19, 12, 0, 1),
      deltaMilliseconds: 1000,
      confidenceLevel: CaptureAppConfidence.high,
      createdAt: DateTime.utc(2026, 7, 19, 12, 0, 1),
    );

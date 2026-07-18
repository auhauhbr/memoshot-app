import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/automatic_import/automatic_screenshot_source.dart';
import '../../../core/automatic_import/method_channel_automatic_screenshot_source.dart';
import '../../../core/database/contexto_database.dart' show ContextoDatabase;
import '../../../core/media/image_picker_screenshot_picker.dart';
import '../../../core/media/screenshot_picker.dart';
import '../../../core/media/screenshot_storage.dart';
import '../../../core/ocr/ml_kit_text_recognition_service.dart';
import '../../../core/sharing/incoming_share_source.dart';
import '../../../core/sharing/receive_sharing_intent_source.dart';
import '../../../core/text/text_normalizer.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/data/category_store.dart';
import '../../categories/presentation/categories_page.dart';
import '../../library/data/media_item_repository.dart';
import '../../library/data/media_item_store.dart';
import '../../library/domain/media_item.dart';
import '../../library/domain/selected_screenshot.dart';
import '../../library/domain/screenshot_search_result.dart';
import '../../library/presentation/screenshot_detail_page.dart';
import '../../library/presentation/screenshot_grid.dart';
import '../../ocr/data/ocr_repository.dart';
import '../../ocr/data/ocr_result_store.dart';
import '../../processing/data/ocr_job_scheduler.dart';
import '../../processing/data/ocr_queue_processor.dart';
import '../../processing/data/processing_job_store.dart';
import '../../processing/domain/processing_job.dart';
import '../../sharing/shared_image_import_coordinator.dart';
import '../../automatic_import/automatic_screenshot_import_coordinator.dart';
import '../../automatic_import/data/automatic_import_settings_repository.dart';
import '../../tags/data/tag_repository.dart';
import '../../tags/data/tag_store.dart';
import '../../tags/presentation/tags_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.screenshotPicker,
    this.mediaRepository,
    this.ocrRepository,
    this.ocrQueue,
    this.categoryRepository,
    this.tagRepository,
    this.incomingShareSource,
    this.automaticScreenshotSource,
    this.automaticImportSettingsRepository,
  });

  final ScreenshotPicker? screenshotPicker;
  final MediaItemRepository? mediaRepository;
  final OcrRepository? ocrRepository;
  final OcrQueue? ocrQueue;
  final CategoryRepository? categoryRepository;
  final TagRepository? tagRepository;
  final IncomingShareSource? incomingShareSource;
  final AutomaticScreenshotSource? automaticScreenshotSource;
  final AutomaticImportSettingsRepository? automaticImportSettingsRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final ScreenshotPicker _screenshotPicker;
  late final MediaItemRepository _mediaRepository;
  late final OcrRepository _ocrRepository;
  late final OcrQueue _ocrQueue;
  late final CategoryRepository _categoryRepository;
  late final TagRepository _tagRepository;
  late final bool _ownsMediaRepository;
  ContextoDatabase? _ownedAuxiliaryDatabase;
  StreamSubscription<int>? _queueSubscription;
  late final SharedImageImportCoordinator _sharedImportCoordinator;
  late final AutomaticScreenshotImportCoordinator _automaticImportCoordinator;
  final TextEditingController _searchController = TextEditingController();
  final TextNormalizer _textNormalizer = const TextNormalizer();
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  final List<MediaItem> _mediaItems = [];
  final Map<int, OcrItemState> _ocrStates = {};
  List<ScreenshotSearchResult> _searchResults = const [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _searchActive = false;
  String? _errorMessage;
  String? _duplicateMessage;
  String? _searchErrorMessage;
  int _categoryCount = 0;
  int _tagCount = 0;
  AutomaticImportUiState _automaticImportState =
      AutomaticImportUiState.disabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screenshotPicker =
        widget.screenshotPicker ?? ImagePickerScreenshotPicker();
    _ownsMediaRepository = widget.mediaRepository == null;
    final database =
        widget.mediaRepository == null ||
            widget.ocrRepository == null ||
            widget.ocrQueue == null ||
            widget.categoryRepository == null ||
            widget.tagRepository == null ||
            widget.automaticImportSettingsRepository == null
        ? ContextoDatabase()
        : null;
    final jobStore = database == null
        ? null
        : DriftProcessingJobStore(database);
    final resultStore = database == null ? null : DriftOcrResultStore(database);
    _mediaRepository =
        widget.mediaRepository ??
        LocalMediaItemRepository(
          store: DriftMediaItemStore(database!),
          storage: PrivateScreenshotStorage(),
          ocrJobScheduler: LocalOcrJobScheduler(jobStore!),
        );
    _ocrRepository =
        widget.ocrRepository ??
        LocalOcrRepository(
          store: resultStore!,
          recognitionService: const MlKitTextRecognitionService(),
        );
    _ocrQueue =
        widget.ocrQueue ??
        LocalOcrQueueProcessor(
          jobStore: jobStore!,
          resultStore: resultStore!,
          recognitionService: const MlKitTextRecognitionService(),
        );
    _categoryRepository =
        widget.categoryRepository ??
        LocalCategoryRepository(store: DriftCategoryStore(database!));
    _tagRepository =
        widget.tagRepository ??
        LocalTagRepository(store: DriftTagStore(database!));
    final automaticSettingsRepository =
        widget.automaticImportSettingsRepository ??
        DriftAutomaticImportSettingsRepository(database!);
    if (!_ownsMediaRepository) {
      _ownedAuxiliaryDatabase = database;
    }
    _queueSubscription = _ocrQueue.changes.listen(_handleQueueChange);
    _sharedImportCoordinator = SharedImageImportCoordinator(
      source: widget.incomingShareSource ?? const ReceiveSharingIntentSource(),
      repository: _mediaRepository,
      onCompleted: _handleSharedImport,
      onError: _handleSharedImportError,
    );
    _automaticImportCoordinator = AutomaticScreenshotImportCoordinator(
      source:
          widget.automaticScreenshotSource ??
          const MethodChannelAutomaticScreenshotSource(),
      settingsRepository: automaticSettingsRepository,
      mediaRepository: _mediaRepository,
      onStateChanged: _handleAutomaticImportState,
      onImported: _handleAutomaticImport,
      onError: _handleAutomaticImportError,
    );
    _initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_sharedImportCoordinator.start());
      unawaited(_automaticImportCoordinator.initialize());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_automaticImportCoordinator.resume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchController.dispose();
    unawaited(_disposeResources());
    super.dispose();
  }

  Future<void> _disposeResources() async {
    await _automaticImportCoordinator.dispose();
    await _sharedImportCoordinator.dispose();
    await _queueSubscription?.cancel();
    await _ocrQueue.close();
    if (_ownsMediaRepository) {
      await _mediaRepository.close();
    } else if (_ownedAuxiliaryDatabase != null) {
      await _ownedAuxiliaryDatabase!.close();
    }
  }

  void _handleAutomaticImportState(AutomaticImportUiState state) {
    if (!mounted) return;
    setState(() => _automaticImportState = state);
  }

  Future<void> _handleAutomaticImport(ImportResult result) async {
    if (!mounted) return;
    await _reloadItemsIgnoringErrors();
    _ocrQueue.signal();
    if (_searchActive) await _searchNow();
    if (!mounted) return;
    if (result.importedItems.isEmpty) {
      if (result.rejectedCount > 0) _handleAutomaticImportError();
      return;
    }
    final count = result.importedItems.length;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            count == 1
                ? 'Screenshot importado automaticamente.'
                : '$count screenshots importados automaticamente.',
          ),
        ),
      );
  }

  void _handleAutomaticImportError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Não foi possível verificar novos screenshots.'),
        ),
      );
  }

  Future<void> _changeAutomaticImport(bool enabled) async {
    if (!enabled) {
      await _automaticImportCoordinator.disable();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ativar importação automática?'),
        content: const Text(
          'O Contexto precisará acessar suas imagens para identificar novos '
          'screenshots. Somente capturas novas serão importadas; imagens antigas '
          'não serão adicionadas. Todo o processamento permanece neste dispositivo '
          'e o recurso pode ser desligado a qualquer momento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _automaticImportCoordinator.enable();
  }

  Future<void> _handleSharedImport(ImportResult result) async {
    if (!mounted) return;
    await _reloadItemsIgnoringErrors();
    _ocrQueue.signal();
    if (_searchActive) await _searchNow();
    if (!mounted) return;
    final message = _sharedImportMessage(result);
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _handleSharedImportError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Não foi possível adicionar a imagem.')),
      );
  }

  String? _sharedImportMessage(ImportResult result) {
    final imported = result.importedItems.length;
    final duplicates = result.duplicateCount;
    final rejected = result.rejectedCount;
    if (imported == 0 && duplicates == 0 && rejected == 0) return null;
    if (imported == 0 && duplicates == 0) {
      return rejected == 1
          ? 'Não foi possível adicionar a imagem.'
          : 'Não foi possível adicionar as imagens.';
    }
    if (imported == 0) {
      return duplicates == 1
          ? 'Esta imagem já estava no Contexto.'
          : '$duplicates imagens já estavam no Contexto.';
    }
    if (duplicates == 0 && rejected == 0) {
      return imported == 1
          ? 'Screenshot adicionado ao Contexto.'
          : '$imported screenshots adicionados ao Contexto.';
    }
    final addedText =
        '$imported ${imported == 1 ? 'imagem adicionada' : 'imagens adicionadas'}';
    final parts = <String>[addedText];
    if (duplicates > 0) {
      parts.add(
        '$duplicates ${duplicates == 1 ? 'já estava' : 'já estavam'} no Contexto',
      );
    }
    if (rejected > 0) {
      parts.add(
        '$rejected ${rejected == 1 ? 'não pôde ser adicionada' : 'não puderam ser adicionadas'}',
      );
    }
    return '${parts.join(' e ')}.';
  }

  Future<void> _initialize() async {
    try {
      await _reloadItems();
      await _reloadCategoryCount();
      await _reloadTagCountIgnoringErrors();
      unawaited(_ocrQueue.recoverAndStart());
      final lost = await _screenshotPicker.retrieveLostScreenshots();
      if (lost.isNotEmpty) {
        await _importSelected(lost);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Não foi possível carregar a biblioteca.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickScreenshots() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _duplicateMessage = null;
    });

    try {
      await _importSelected(await _screenshotPicker.pickScreenshots());
    } catch (_) {
      await _reloadItemsIgnoringErrors();
      if (mounted) {
        setState(() {
          _errorMessage = 'Não foi possível importar as imagens.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _importSelected(List<SelectedScreenshot> selected) async {
    if (selected.isEmpty) {
      return;
    }

    final result = await _mediaRepository.importScreenshots(selected);
    for (final item in result.importedItems) {
      await _refreshOcrState(item.id);
    }
    _ocrQueue.signal();
    if (!mounted) {
      return;
    }
    setState(() {
      _mediaItems.insertAll(0, result.importedItems.reversed);
      _duplicateMessage = _duplicateText(result.duplicateCount);
    });
  }

  String? _duplicateText(int count) {
    if (count == 0) {
      return null;
    }
    if (count == 1) {
      return 'Este screenshot já está na biblioteca.';
    }
    return '$count screenshots já estavam na biblioteca.';
  }

  Future<void> _reloadItems() async {
    final items = await _mediaRepository.loadAvailableItems();
    final states = <int, OcrItemState>{};
    for (final item in items) {
      states[item.id] = await _ocrQueue.loadState(item.id);
    }
    if (mounted) {
      setState(() {
        _mediaItems
          ..clear()
          ..addAll(items);
        _ocrStates
          ..clear()
          ..addAll(states);
      });
    }
  }

  Future<OcrItemState?> _refreshOcrState(int mediaItemId) async {
    try {
      final state = await _ocrQueue.loadState(mediaItemId);
      if (mounted) {
        setState(() {
          _ocrStates[mediaItemId] = state;
        });
      }
      return state;
    } catch (_) {
      // Uma falha de leitura do estado não bloqueia a biblioteca.
      return null;
    }
  }

  Future<void> _handleQueueChange(int mediaItemId) async {
    final state = await _refreshOcrState(mediaItemId);
    if (_searchActive &&
        (state == OcrItemState.completedWithText ||
            state == OcrItemState.completedWithoutText)) {
      await _searchNow();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final normalized = _textNormalizer.normalize(value);
    final generation = ++_searchGeneration;
    if (normalized.isEmpty) {
      setState(() {
        _searchActive = false;
        _isSearching = false;
        _searchResults = const [];
        _searchErrorMessage = null;
      });
      return;
    }
    setState(() {
      _searchActive = true;
      _isSearching = true;
      _searchErrorMessage = null;
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_performSearch(value, generation)),
    );
  }

  void _submitSearch(String value) {
    _searchDebounce?.cancel();
    if (_textNormalizer.normalize(value).isEmpty) {
      _onSearchChanged(value);
      return;
    }
    final generation = ++_searchGeneration;
    setState(() {
      _searchActive = true;
      _isSearching = true;
      _searchErrorMessage = null;
    });
    unawaited(_performSearch(value, generation));
  }

  Future<void> _searchNow() async {
    final value = _searchController.text;
    if (_textNormalizer.normalize(value).isEmpty) {
      return;
    }
    final generation = ++_searchGeneration;
    await _performSearch(value, generation, showLoading: false);
  }

  Future<void> _performSearch(
    String query,
    int generation, {
    bool showLoading = true,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        _isSearching = true;
      });
    }
    try {
      final results = await _mediaRepository.searchRecognizedText(query);
      if (!mounted || generation != _searchGeneration) {
        return;
      }
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _searchErrorMessage = null;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) {
        return;
      }
      setState(() {
        _isSearching = false;
        _searchErrorMessage = 'Não foi possível realizar a pesquisa.';
      });
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchGeneration++;
    _searchController.clear();
    setState(() {
      _searchActive = false;
      _isSearching = false;
      _searchResults = const [];
      _searchErrorMessage = null;
    });
  }

  Future<void> _reloadItemsIgnoringErrors() async {
    try {
      await _reloadItems();
    } catch (_) {
      // A mensagem genérica da operação original continua sendo exibida.
    }
  }

  Future<void> _reloadCategoryCount() async {
    final categories = await _categoryRepository.loadCategories();
    if (mounted) setState(() => _categoryCount = categories.length);
  }

  Future<void> _reloadCategoryCountIgnoringErrors() async {
    try {
      await _reloadCategoryCount();
    } catch (_) {
      // Uma falha no contador não impede o uso da biblioteca.
    }
  }

  Future<void> _reloadTagCount() async {
    final tags = await _tagRepository.loadTagSummaries();
    if (mounted) setState(() => _tagCount = tags.length);
  }

  Future<void> _reloadTagCountIgnoringErrors() async {
    try {
      await _reloadTagCount();
    } catch (_) {
      // Uma falha no contador não impede o uso da biblioteca.
    }
  }

  Future<void> _openCategories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CategoriesPage(
          categoryRepository: _categoryRepository,
          mediaRepository: _mediaRepository,
          ocrRepository: _ocrRepository,
          ocrQueue: _ocrQueue,
          tagRepository: _tagRepository,
        ),
      ),
    );
    await _reloadCategoryCountIgnoringErrors();
  }

  Future<void> _openTags() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TagsPage(repository: _tagRepository)),
    );
    await _reloadTagCountIgnoringErrors();
  }

  Future<void> _openDetails(MediaItem item) async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ScreenshotDetailPage(
          mediaItem: item,
          mediaRepository: _mediaRepository,
          ocrRepository: _ocrRepository,
          ocrQueue: _ocrQueue,
          categoryRepository: _categoryRepository,
          tagRepository: _tagRepository,
        ),
      ),
    );
    await _reloadCategoryCountIgnoringErrors();
    if (removed == true) {
      await _reloadItemsIgnoringErrors();
      if (_searchActive) {
        await _searchNow();
      }
    } else {
      final state = await _refreshOcrState(item.id);
      if (_searchActive &&
          (state == OcrItemState.completedWithText ||
              state == OcrItemState.completedWithoutText)) {
        await _searchNow();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _AppHeader(),
                  const SizedBox(height: 18),
                  Text(
                    'Organize e encontre seus prints',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pesquise screenshots pelo conteúdo, sem depender da data '
                    'ou da pasta.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SearchField(
                    controller: _searchController,
                    showClearAction: _searchController.text.isNotEmpty,
                    onChanged: _onSearchChanged,
                    onSubmitted: _submitSearch,
                    onClear: _clearSearch,
                  ),
                  const SizedBox(height: 18),
                  const _SectionTitle('Biblioteca'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _LibrarySummary(
                          icon: Icons.access_time_outlined,
                          title: 'Recentes',
                          count:
                              '${_mediaItems.length} '
                              '${_mediaItems.length == 1 ? 'item' : 'itens'}',
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _LibrarySummary(
                          key: const Key('categories-summary'),
                          icon: Icons.folder_outlined,
                          title: 'Categorias',
                          count:
                              '$_categoryCount '
                              '${_categoryCount == 1 ? 'categoria' : 'categorias'}',
                          onTap: _openCategories,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LibrarySummary(
                          key: const Key('tags-summary'),
                          icon: Icons.label_outline,
                          title: 'Etiquetas',
                          count:
                              '$_tagCount '
                              '${_tagCount == 1 ? 'etiqueta' : 'etiquetas'}',
                          onTap: _openTags,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ImportCard(
                    isLoading: _isLoading,
                    errorMessage: _errorMessage,
                    infoMessage: _duplicateMessage,
                    onPressed: _isLoading ? null : _pickScreenshots,
                  ),
                  const SizedBox(height: 12),
                  _AutomaticImportCard(
                    state: _automaticImportState,
                    onChanged: _changeAutomaticImport,
                    onOpenSettings: () => unawaited(
                      _automaticImportCoordinator.openAppSettings(),
                    ),
                  ),
                  if (_searchActive) ...[
                    const SizedBox(height: 12),
                    _SearchSummary(
                      query: _searchController.text.trim(),
                      resultCount: _searchResults.length,
                      isSearching: _isSearching,
                      errorMessage: _searchErrorMessage,
                      hasPendingItems: _ocrStates.values.any(
                        (state) =>
                            state == OcrItemState.pending ||
                            state == OcrItemState.processing,
                      ),
                    ),
                    if (!_isSearching &&
                        _searchErrorMessage == null &&
                        _searchResults.isEmpty)
                      const _EmptySearchState()
                    else if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ScreenshotGrid(
                        mediaItems: _searchResults
                            .map((result) => result.mediaItem)
                            .toList(growable: false),
                        ocrStates: _ocrStates,
                        snippets: {
                          for (final result in _searchResults)
                            result.mediaItem.id: result.snippet,
                        },
                        onItemTap: _openDetails,
                      ),
                    ],
                  ] else if (_mediaItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ScreenshotGrid(
                      mediaItems: _mediaItems,
                      ocrStates: _ocrStates,
                      onItemTap: _openDetails,
                    ),
                  ],
                  const SizedBox(height: 12),
                  const _LocalProcessingInfo(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contexto',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Organização inteligente',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: null,
          tooltip: 'Configurações indisponíveis',
          icon: const Icon(Icons.settings_outlined),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.showClearAction,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool showClearAction;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: 'Pesquisar screenshots pelo texto reconhecido',
      child: TextField(
        controller: controller,
        enabled: true,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Pesquisar screenshots',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: showClearAction
              ? IconButton(
                  onPressed: onClear,
                  tooltip: 'Limpar pesquisa',
                  icon: const Icon(Icons.close, size: 19),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          isDense: true,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 21, color: colors.secondary),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                count,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  const _ImportCard({
    required this.isLoading,
    required this.errorMessage,
    required this.infoMessage,
    required this.onPressed,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 21,
                  color: colors.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Importar screenshots',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Selecione imagens do seu dispositivo',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'No dispositivo',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onPressed,
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Selecionar imagens'),
            ),
            const SizedBox(height: 8),
            Text(
              'Você também pode enviar imagens pelo menu Compartilhar.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
            if (infoMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                infoMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AutomaticImportCard extends StatelessWidget {
  const _AutomaticImportCard({
    required this.state,
    required this.onChanged,
    required this.onOpenSettings,
  });

  final AutomaticImportUiState state;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active = state == AutomaticImportUiState.active;
    final status = switch (state) {
      AutomaticImportUiState.disabled => 'Desativada',
      AutomaticImportUiState.active => 'Ativa',
      AutomaticImportUiState.accessRequired => 'Acesso às imagens necessário',
      AutomaticImportUiState.limitedAccess => 'Acesso limitado',
      AutomaticImportUiState.unavailable => 'Verificação indisponível',
    };

    return Card(
      key: const Key('automatic-import-card'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.screenshot_monitor_outlined,
                  color: colors.secondary,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Importação automática',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Adicione novos screenshots ao Contexto automaticamente.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Ativar importação automática',
                  child: Switch(
                    key: const Key('automatic-import-switch'),
                    value: active,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status,
              key: const Key('automatic-import-status'),
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    state == AutomaticImportUiState.accessRequired ||
                        state == AutomaticImportUiState.limitedAccess ||
                        state == AutomaticImportUiState.unavailable
                    ? colors.error
                    : colors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (state == AutomaticImportUiState.limitedAccess) ...[
              const SizedBox(height: 5),
              Text(
                'O Android autorizou apenas imagens escolhidas. Novos '
                'screenshots não podem ser acompanhados com segurança.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (state == AutomaticImportUiState.accessRequired ||
                state == AutomaticImportUiState.limitedAccess) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onOpenSettings,
                  child: const Text('Abrir configurações do aplicativo'),
                ),
              ),
            ],
            const SizedBox(height: 5),
            Text(
              'Com o app fechado, o Android pode capturar novos screenshots em '
              'segundo plano. O processamento será concluído quando o Contexto '
              'estiver disponível.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSummary extends StatelessWidget {
  const _SearchSummary({
    required this.query,
    required this.resultCount,
    required this.isSearching,
    required this.errorMessage,
    required this.hasPendingItems,
  });

  final String query;
  final int resultCount;
  final bool isSearching;
  final String? errorMessage;
  final bool hasPendingItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (isSearching)
                const SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                )
              else
                Icon(Icons.search, size: 17, color: colors.secondary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  isSearching
                      ? 'Pesquisando…'
                      : '$resultCount ${resultCount == 1 ? 'resultado' : 'resultados'} para “$query”',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (hasPendingItems) ...[
            const SizedBox(height: 6),
            Text(
              'Alguns screenshots ainda estão sendo processados.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(
            Icons.search_off_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 7),
          Text(
            'Nenhum screenshot encontrado.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalProcessingInfo extends StatelessWidget {
  const _LocalProcessingInfo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.smartphone_outlined, size: 19, color: colors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Processamento local',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Seus arquivos permanecem no dispositivo.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

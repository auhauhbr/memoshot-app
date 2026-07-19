import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../../core/automatic_import/automatic_screenshot_source.dart';
import '../../../core/automatic_import/method_channel_automatic_screenshot_source.dart';
import '../../../core/database/contexto_database.dart' show ContextoDatabase;
import '../../../core/media/image_picker_screenshot_picker.dart';
import '../../../core/media/screenshot_picker.dart';
import '../../../core/media/screenshot_storage.dart';
import '../../../core/media_store/existing_screenshot_scanner.dart';
import '../../../core/media_store/media_store_content.dart';
import '../../../core/ocr/ml_kit_text_recognition_service.dart';
import '../../../core/ocr/media_ocr_input.dart';
import '../../../core/sharing/incoming_share_source.dart';
import '../../../core/sharing/receive_sharing_intent_source.dart';
import '../../../core/text/text_normalizer.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/data/category_store.dart';
import '../../categories/data/recent_folder_repository.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/categories_page.dart';
import '../../categories/presentation/category_detail_page.dart';
import '../../classification/application/classification_composition.dart';
import '../../classification/application/classification_processor.dart';
import '../../classification/application/classification_queue_processor.dart';
import '../../classification/data/classification_suggestion_repository.dart';
import '../../existing_screenshots/application/existing_screenshot_inventory_coordinator.dart';
import '../../existing_screenshots/application/historical_archive_preparation_coordinator.dart';
import '../../existing_screenshots/application/historical_media_import_processor.dart';
import '../../existing_screenshots/data/existing_screenshot_candidate_repository.dart';
import '../../existing_screenshots/data/existing_screenshot_candidate_store.dart';
import '../../existing_screenshots/data/historical_media_import_job_store.dart';
import '../../existing_screenshots/data/historical_preparation_settings_repository.dart';
import '../../library/data/media_item_repository.dart';
import '../../library/data/media_item_store.dart';
import '../../library/domain/media_item.dart';
import '../../library/domain/media_page.dart';
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
import '../../settings/presentation/settings_page.dart';
import '../../tags/data/tag_repository.dart';
import '../../tags/data/tag_store.dart';
import '../../tags/domain/tag.dart';
import '../../tags/presentation/tag_filter_dialog.dart';
import '../../tags/presentation/tags_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.screenshotPicker,
    this.mediaRepository,
    this.ocrRepository,
    this.ocrQueue,
    this.classificationQueue,
    this.categoryRepository,
    this.recentFolderRepository,
    this.classificationSuggestionRepository,
    this.tagRepository,
    this.incomingShareSource,
    this.automaticScreenshotSource,
    this.automaticImportSettingsRepository,
    this.existingScreenshotInventoryCoordinator,
    this.historicalArchivePreparationCoordinator,
    this.mediaStoreContentGateway,
    this.mediaOcrInputResolver,
  });

  final ScreenshotPicker? screenshotPicker;
  final MediaItemRepository? mediaRepository;
  final OcrRepository? ocrRepository;
  final OcrQueue? ocrQueue;
  final ClassificationQueue? classificationQueue;
  final CategoryRepository? categoryRepository;
  final RecentFolderRepository? recentFolderRepository;
  final ClassificationSuggestionRepository? classificationSuggestionRepository;
  final TagRepository? tagRepository;
  final IncomingShareSource? incomingShareSource;
  final AutomaticScreenshotSource? automaticScreenshotSource;
  final AutomaticImportSettingsRepository? automaticImportSettingsRepository;
  final ExistingScreenshotInventoryCoordinator?
  existingScreenshotInventoryCoordinator;
  final HistoricalArchivePreparationCoordinator?
  historicalArchivePreparationCoordinator;
  final MediaStoreContentGateway? mediaStoreContentGateway;
  final MediaOcrInputResolver? mediaOcrInputResolver;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final ScreenshotPicker _screenshotPicker;
  late final MediaItemRepository _mediaRepository;
  late final OcrRepository _ocrRepository;
  late final OcrQueue _ocrQueue;
  ClassificationQueue? _classificationQueue;
  late final CategoryRepository _categoryRepository;
  late final RecentFolderRepository _recentFolderRepository;
  late final ClassificationSuggestionRepository _classificationRepository;
  late final TagRepository _tagRepository;
  late final bool _ownsMediaRepository;
  ContextoDatabase? _ownedAuxiliaryDatabase;
  ContextoDatabase? _ownedInventoryDatabase;
  StreamSubscription<int>? _queueSubscription;
  StreamSubscription<int>? _classificationQueueSubscription;
  StreamSubscription<void>? _historicalQueueSubscription;
  late final SharedImageImportCoordinator _sharedImportCoordinator;
  late final AutomaticScreenshotImportCoordinator _automaticImportCoordinator;
  late final AutomaticImportSettingsRepository _automaticSettingsRepository;
  late final ExistingScreenshotInventoryCoordinator
  _existingScreenshotInventoryCoordinator;
  HistoricalArchivePreparationCoordinator?
  _historicalArchivePreparationCoordinator;
  LocalHistoricalMediaImportProcessor? _historicalMediaImportProcessor;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextNormalizer _textNormalizer = const TextNormalizer();
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  final List<MediaItem> _mediaItems = [];
  final Map<int, OcrItemState> _ocrStates = {};
  List<ScreenshotSearchResult> _searchResults = const [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isLoadingNextPage = false;
  String? _nextPageErrorMessage;
  MediaPageCursor? _nextCursor;
  bool _searchActive = false;
  String? _errorMessage;
  bool _initialPageFailed = false;
  String? _duplicateMessage;
  String? _searchErrorMessage;
  Tag? _selectedTag;
  bool _isFiltering = false;
  String? _filterErrorMessage;
  List<CategorySummary> _categories = const [];
  bool _areCategoriesLoading = true;
  String? _categoriesErrorMessage;
  List<RecentFolder> _recentFolders = const [];
  int _recentFoldersGeneration = 0;
  AutomaticImportUiState _automaticImportState =
      AutomaticImportUiState.disabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screenshotPicker =
        widget.screenshotPicker ?? ImagePickerScreenshotPicker();
    final automaticScreenshotSource =
        widget.automaticScreenshotSource ??
        const MethodChannelAutomaticScreenshotSource();
    _ownsMediaRepository = widget.mediaRepository == null;
    final database =
        widget.mediaRepository == null ||
            widget.ocrRepository == null ||
            widget.ocrQueue == null ||
            widget.categoryRepository == null ||
            widget.classificationSuggestionRepository == null ||
            widget.tagRepository == null ||
            widget.automaticImportSettingsRepository == null
        ? ContextoDatabase()
        : null;
    final jobStore = database == null
        ? null
        : DriftProcessingJobStore(database);
    final resultStore = database == null ? null : DriftOcrResultStore(database);
    _classificationRepository =
        widget.classificationSuggestionRepository ??
        createLocalClassificationRepository(database!);
    _categoryRepository =
        widget.categoryRepository ??
        LocalCategoryRepository(store: DriftCategoryStore(database!));
    _recentFolderRepository =
        widget.recentFolderRepository ??
        LocalRecentFolderRepository(
          store: const MethodChannelRecentFolderIdStore(),
          categoryRepository: _categoryRepository,
        );
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
    _classificationQueue =
        widget.classificationQueue ??
        (database == null
            ? null
            : createLocalClassificationQueue(
                database: database,
                suggestionRepository: _classificationRepository,
                categoryRepository: _categoryRepository,
                mediaRepository: _mediaRepository,
                ocrRepository: _ocrRepository,
              ));
    _ocrQueue =
        widget.ocrQueue ??
        LocalOcrQueueProcessor(
          jobStore: jobStore!,
          resultStore: resultStore!,
          recognitionService: const MlKitTextRecognitionService(),
          inputResolver:
              widget.mediaOcrInputResolver ??
              (throw StateError('Resolver de entrada OCR não configurado.')),
          classificationJobScheduler: createLocalClassificationJobScheduler(
            database!,
          ),
          classificationQueue: _classificationQueue,
        );
    _tagRepository =
        widget.tagRepository ??
        LocalTagRepository(store: DriftTagStore(database!));
    _automaticSettingsRepository =
        widget.automaticImportSettingsRepository ??
        DriftAutomaticImportSettingsRepository(database!);
    if (widget.existingScreenshotInventoryCoordinator case final injected?) {
      _existingScreenshotInventoryCoordinator = injected;
    } else {
      final inventoryDatabase = database ?? ContextoDatabase();
      if (database == null) _ownedInventoryDatabase = inventoryDatabase;
      _existingScreenshotInventoryCoordinator =
          ExistingScreenshotInventoryCoordinator(
            permissionSource: automaticScreenshotSource,
            scanner: const MethodChannelExistingScreenshotScanner(),
            repository: LocalExistingScreenshotCandidateRepository(
              DriftExistingScreenshotCandidateStore(inventoryDatabase),
            ),
          );
    }
    if (widget.historicalArchivePreparationCoordinator case final injected?) {
      _historicalArchivePreparationCoordinator = injected;
    } else if (_mediaRepository
        case final MediaStoreReferenceMediaItemRepository referenceRepository) {
      var historicalDatabase = database ?? _ownedInventoryDatabase;
      if (historicalDatabase == null) {
        historicalDatabase = ContextoDatabase();
        _ownedInventoryDatabase = historicalDatabase;
      }
      const historicalSettings =
          MethodChannelHistoricalPreparationSettingsRepository();
      final historicalStore = DriftHistoricalMediaImportJobStore(
        historicalDatabase,
      );
      _historicalMediaImportProcessor = LocalHistoricalMediaImportProcessor(
        jobStore: historicalStore,
        mediaRepository: referenceRepository,
        settingsRepository: historicalSettings,
      );
      _historicalArchivePreparationCoordinator =
          HistoricalArchivePreparationCoordinator(
            jobStore: historicalStore,
            settingsRepository: historicalSettings,
            scheduler: historicalSettings,
            queue: _historicalMediaImportProcessor,
          );
    }
    _historicalQueueSubscription = _historicalArchivePreparationCoordinator
        ?.changes
        .listen((_) {
          unawaited(_reloadItemsIgnoringErrors());
        });
    if (!_ownsMediaRepository) {
      _ownedAuxiliaryDatabase = database;
    }
    _queueSubscription = _ocrQueue.changes.listen(_handleQueueChange);
    _classificationQueueSubscription = _classificationQueue?.changes.listen(
      _handleClassificationQueueChange,
    );
    _sharedImportCoordinator = SharedImageImportCoordinator(
      source: widget.incomingShareSource ?? const ReceiveSharingIntentSource(),
      repository: _mediaRepository,
      onCompleted: _handleSharedImport,
      onError: _handleSharedImportError,
    );
    _automaticImportCoordinator = AutomaticScreenshotImportCoordinator(
      source: automaticScreenshotSource,
      settingsRepository: _automaticSettingsRepository,
      mediaRepository: _mediaRepository,
      onStateChanged: _handleAutomaticImportState,
      onImported: _handleAutomaticImport,
      onError: _handleAutomaticImportError,
    );
    _initialize();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_sharedImportCoordinator.start());
      unawaited(_automaticImportCoordinator.initialize());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_automaticImportCoordinator.resume());
      unawaited(_classificationQueue?.recoverAndStart());
      unawaited(_reloadRecentFolders());
      unawaited(_historicalArchivePreparationCoordinator?.onAppResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    unawaited(_disposeResources());
    super.dispose();
  }

  Future<void> _disposeResources() async {
    await _automaticImportCoordinator.dispose();
    await _sharedImportCoordinator.dispose();
    await _queueSubscription?.cancel();
    await _classificationQueueSubscription?.cancel();
    await _historicalQueueSubscription?.cancel();
    await _ocrQueue.close();
    await _classificationQueue?.close();
    await _historicalMediaImportProcessor?.close();
    if (_ownsMediaRepository) {
      await _mediaRepository.close();
    } else if (_ownedAuxiliaryDatabase != null) {
      await _ownedAuxiliaryDatabase!.close();
    }
    await _ownedInventoryDatabase?.close();
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
          ? 'Esta imagem já estava no MemoShot.'
          : '$duplicates imagens já estavam no MemoShot.';
    }
    if (duplicates == 0 && rejected == 0) {
      return imported == 1
          ? 'Screenshot adicionado ao MemoShot.'
          : '$imported screenshots adicionados ao MemoShot.';
    }
    final addedText =
        '$imported ${imported == 1 ? 'imagem adicionada' : 'imagens adicionadas'}';
    final parts = <String>[addedText];
    if (duplicates > 0) {
      parts.add(
        '$duplicates ${duplicates == 1 ? 'já estava' : 'já estavam'} no MemoShot',
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
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _initialPageFailed = false;
      });
    }
    try {
      await _reloadItems();
      await _reloadCategories();
      unawaited(_reloadRecentFolders());
      await _reloadTagCountIgnoringErrors();
      unawaited(_ocrQueue.recoverAndStart());
      unawaited(_classificationQueue?.recoverAndStart());
      final lost = await _screenshotPicker.retrieveLostScreenshots();
      if (lost.isNotEmpty) {
        await _importSelected(lost);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Não foi possível carregar seus prints.';
          _initialPageFailed = true;
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
    setState(() => _duplicateMessage = _duplicateText(result.duplicateCount));
    await _refreshCurrentFirstPage();
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

  Future<void> _reloadItems({int? generation}) async {
    final tagId = _selectedTag?.id;
    final request = MediaPageRequest(tagIds: {?tagId});
    final repository = _mediaRepository;
    final previousItemCount = _mediaItems.length;
    var page = repository is PagedMediaItemRepository
        ? await repository.loadMediaPageByTags(request)
        : MediaPage<MediaItem>(
            items: await repository.loadAvailableItems(tagId: tagId),
            nextCursor: null,
          );
    final items = [...page.items];
    while (repository is PagedMediaItemRepository &&
        items.length < previousItemCount &&
        page.nextCursor != null) {
      page = await repository.loadMediaPageByTags(
        MediaPageRequest(cursor: page.nextCursor, tagIds: request.tagIds),
      );
      items.addAll(page.items);
    }
    final states = <int, OcrItemState>{};
    for (final item in items) {
      states[item.id] = await _ocrQueue.loadState(item.id);
    }
    if (mounted &&
        (generation == null || generation == _searchGeneration) &&
        tagId == _selectedTag?.id) {
      setState(() {
        _mediaItems
          ..clear()
          ..addAll(items);
        _ocrStates
          ..clear()
          ..addAll(states);
        _nextCursor = page.nextCursor;
        _nextPageErrorMessage = null;
        _isLoadingNextPage = false;
      });
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 600) {
      unawaited(_loadNextPage());
    }
  }

  Future<void> _loadNextPage() async {
    final cursor = _nextCursor;
    if (cursor == null || _isLoadingNextPage) return;
    final repository = _mediaRepository;
    if (repository is! PagedMediaItemRepository) return;
    final generation = _searchGeneration;
    final tagId = _selectedTag?.id;
    final query = _searchController.text;
    setState(() {
      _isLoadingNextPage = true;
      _nextPageErrorMessage = null;
    });
    try {
      final request = MediaPageRequest(cursor: cursor, tagIds: {?tagId});
      final MediaPageCursor? nextCursor;
      final List<MediaItem> pageItems;
      List<ScreenshotSearchResult>? searchItems;
      if (_searchActive) {
        final page = await repository.searchMediaPageByTags(query, request);
        searchItems = page.items;
        pageItems = page.items
            .map((item) => item.mediaItem)
            .toList(growable: false);
        nextCursor = page.nextCursor;
      } else {
        final page = await repository.loadMediaPageByTags(request);
        pageItems = page.items;
        nextCursor = page.nextCursor;
      }
      final states = await _loadOcrStates(pageItems);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        if (_searchActive) {
          final existing = _searchResults
              .map((item) => item.mediaItem.id)
              .toSet();
          _searchResults = [
            ..._searchResults,
            ...searchItems!.where((item) => existing.add(item.mediaItem.id)),
          ];
        } else {
          final existing = _mediaItems.map((item) => item.id).toSet();
          _mediaItems.addAll(pageItems.where((item) => existing.add(item.id)));
        }
        _ocrStates.addAll(states);
        _nextCursor = nextCursor;
        _isLoadingNextPage = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _isLoadingNextPage = false;
        _nextPageErrorMessage = 'Não foi possível carregar mais prints.';
      });
    }
  }

  Future<Map<int, OcrItemState>> _loadOcrStates(List<MediaItem> items) async {
    final states = <int, OcrItemState>{};
    for (final item in items) {
      states[item.id] = await _ocrQueue.loadState(item.id);
    }
    return states;
  }

  void _scrollToLibraryStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  Future<void> _refreshCurrentFirstPage() async {
    final generation = ++_searchGeneration;
    _nextCursor = null;
    _nextPageErrorMessage = null;
    _isLoadingNextPage = false;
    if (_searchActive) {
      await _performSearch(
        _searchController.text,
        generation,
        showLoading: false,
      );
    } else {
      await _reloadItems(generation: generation);
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
    if (state == OcrItemState.completedWithText ||
        state == OcrItemState.completedWithoutText) {
      await Future.wait([_reloadCategories(), _reloadTagCountIgnoringErrors()]);
    }
  }

  Future<void> _handleClassificationQueueChange(int mediaItemId) async {
    await Future.wait([_reloadCategories(), _reloadTagCountIgnoringErrors()]);
    if (_selectedTag != null) await _reloadItemsIgnoringErrors();
    if (_searchActive) await _searchNow();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final normalized = _textNormalizer.normalize(value);
    final generation = ++_searchGeneration;
    _nextCursor = null;
    _nextPageErrorMessage = null;
    _isLoadingNextPage = false;
    _scrollToLibraryStart();
    if (normalized.isEmpty) {
      setState(() {
        _searchActive = false;
        _isSearching = false;
        _searchResults = const [];
        _searchErrorMessage = null;
      });
      unawaited(_refreshLibraryForCurrentFilter(generation: generation));
      return;
    }
    setState(() {
      _searchActive = true;
      _isSearching = true;
      _searchResults = const [];
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
      _searchResults = const [];
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
      final tagId = _selectedTag?.id;
      final repository = _mediaRepository;
      final previousResultCount = _searchResults.length;
      var page = repository is PagedMediaItemRepository
          ? await repository.searchMediaPageByTags(
              query,
              MediaPageRequest(tagIds: {?tagId}),
            )
          : MediaPage<ScreenshotSearchResult>(
              items: await repository.searchRecognizedText(query, tagId: tagId),
              nextCursor: null,
            );
      final results = [...page.items];
      while (repository is PagedMediaItemRepository &&
          results.length < previousResultCount &&
          page.nextCursor != null) {
        page = await repository.searchMediaPageByTags(
          query,
          MediaPageRequest(cursor: page.nextCursor, tagIds: {?tagId}),
        );
        results.addAll(page.items);
      }
      if (!mounted || generation != _searchGeneration) {
        return;
      }
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _searchErrorMessage = null;
        _nextCursor = page.nextCursor;
        _nextPageErrorMessage = null;
        _isLoadingNextPage = false;
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
    final generation = ++_searchGeneration;
    _searchController.clear();
    _nextCursor = null;
    _nextPageErrorMessage = null;
    _isLoadingNextPage = false;
    _scrollToLibraryStart();
    setState(() {
      _searchActive = false;
      _isSearching = false;
      _searchResults = const [];
      _searchErrorMessage = null;
    });
    unawaited(_refreshLibraryForCurrentFilter(generation: generation));
  }

  Future<void> _refreshLibraryForCurrentFilter({int? generation}) async {
    final currentGeneration = generation ?? ++_searchGeneration;
    if (mounted) {
      setState(() {
        _isFiltering = true;
        _filterErrorMessage = null;
      });
    }
    try {
      await _reloadItems(generation: currentGeneration);
      if (!mounted || currentGeneration != _searchGeneration) return;
      setState(() => _isFiltering = false);
    } catch (_) {
      if (!mounted || currentGeneration != _searchGeneration) return;
      setState(() {
        _isFiltering = false;
        _filterErrorMessage = 'Não foi possível carregar os screenshots.';
      });
    }
  }

  Future<void> _openTagFilter() async {
    final selection = await showDialog<TagFilterSelection>(
      context: context,
      builder: (_) => TagFilterDialog(
        repository: _tagRepository,
        selectedTagId: _selectedTag?.id,
      ),
    );
    if (!mounted || selection == null) return;
    await _applyTagFilter(selection.tag);
  }

  Future<void> _applyTagFilter(Tag? tag) async {
    if (_selectedTag?.id == tag?.id) return;
    _searchDebounce?.cancel();
    _nextCursor = null;
    _nextPageErrorMessage = null;
    _isLoadingNextPage = false;
    _scrollToLibraryStart();
    setState(() {
      _selectedTag = tag;
      _filterErrorMessage = null;
      if (_textNormalizer.normalize(_searchController.text).isEmpty) {
        _mediaItems.clear();
      } else {
        _searchResults = const [];
      }
    });
    if (_textNormalizer.normalize(_searchController.text).isEmpty) {
      await _refreshLibraryForCurrentFilter();
    } else {
      final generation = ++_searchGeneration;
      setState(() {
        _searchActive = true;
        _isSearching = true;
        _searchErrorMessage = null;
      });
      await _performSearch(_searchController.text, generation);
    }
  }

  Future<void> _retryCurrentResults() async {
    if (_searchActive) {
      await _searchNow();
    } else {
      await _refreshLibraryForCurrentFilter();
    }
  }

  Future<void> _reloadItemsIgnoringErrors() async {
    try {
      await _reloadItems();
    } catch (_) {
      // A mensagem genérica da operação original continua sendo exibida.
    }
  }

  Future<void> _reloadCategories() async {
    if (mounted) {
      setState(() {
        _areCategoriesLoading = true;
        _categoriesErrorMessage = null;
      });
    }
    try {
      final categories = await _categoryRepository.loadRootCategorySummaries();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      if (mounted) {
        setState(() {
          _categoriesErrorMessage = 'Não foi possível carregar as pastas.';
        });
      }
    } finally {
      if (mounted) setState(() => _areCategoriesLoading = false);
    }
  }

  Future<void> _reloadRecentFolders() async {
    final generation = ++_recentFoldersGeneration;
    try {
      final folders = await _recentFolderRepository.load();
      if (!mounted || generation != _recentFoldersGeneration) return;
      setState(() => _recentFolders = folders);
    } catch (_) {
      if (!mounted || generation != _recentFoldersGeneration) return;
      setState(() => _recentFolders = const []);
    }
  }

  Future<void> _recordFolderAccess(int categoryId) async {
    try {
      await _recentFolderRepository.recordAccess(categoryId);
    } catch (_) {
      // Preferências recentes não bloqueiam a navegação principal.
    }
  }

  Future<bool> _reloadTagCount() async {
    final tags = await _tagRepository.loadTagSummaries();
    final selected = _selectedTag;
    final refreshed = selected == null
        ? null
        : tags
              .where((summary) => summary.tag.id == selected.id)
              .map((summary) => summary.tag)
              .firstOrNull;
    final invalid = selected != null && refreshed == null;
    if (mounted) {
      setState(() {
        if (invalid) {
          _selectedTag = null;
        } else if (refreshed != null) {
          _selectedTag = refreshed;
        }
      });
    }
    return invalid;
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
          recentFolderRepository: _recentFolderRepository,
          classificationReprocessor:
              _classificationQueue is IndividualClassificationReprocessor
              ? _classificationQueue as IndividualClassificationReprocessor
              : null,
        ),
      ),
    );
    await _reloadCategories();
    await _reloadRecentFolders();
  }

  Future<void> _openCategory(CategorySummary summary) async {
    await _recordFolderAccess(summary.category.id);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      buildCategoryDetailRoute(
        summary: summary,
        categoryRepository: _categoryRepository,
        mediaRepository: _mediaRepository,
        ocrRepository: _ocrRepository,
        ocrQueue: _ocrQueue,
        tagRepository: _tagRepository,
        recentFolderRepository: _recentFolderRepository,
        classificationReprocessor:
            _classificationQueue is IndividualClassificationReprocessor
            ? _classificationQueue as IndividualClassificationReprocessor
            : null,
      ),
    );
    await _reloadCategories();
    await _reloadRecentFolders();
  }

  Future<void> _openTags() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TagsPage(repository: _tagRepository)),
    );
    try {
      final invalid = await _reloadTagCount();
      if (invalid) await _retryCurrentResults();
    } catch (_) {
      // Uma falha no contador não impede o uso da biblioteca.
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          coordinator: _automaticImportCoordinator,
          settingsRepository: _automaticSettingsRepository,
          existingScreenshotInventoryCoordinator:
              _existingScreenshotInventoryCoordinator,
          historicalArchivePreparationCoordinator:
              _historicalArchivePreparationCoordinator,
        ),
      ),
    );
    if (!mounted) return;
    await _automaticImportCoordinator.resume();
    await _reloadItemsIgnoringErrors();
    await _reloadCategories();
    await _reloadRecentFolders();
    await _reloadTagCountIgnoringErrors();
    if (_searchActive) await _searchNow();
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
          classificationReprocessor:
              _classificationQueue is IndividualClassificationReprocessor
              ? _classificationQueue as IndividualClassificationReprocessor
              : null,
          thumbnailGateway:
              widget.mediaStoreContentGateway ??
              const MethodChannelMediaStoreContentGateway(),
        ),
      ),
    );
    await _reloadCategories();
    await _reloadTagCountIgnoringErrors();
    if (_selectedTag != null) {
      await _reloadItemsIgnoringErrors();
    }
    if (removed == true) {
      await _reloadItemsIgnoringErrors();
      if (_searchActive) {
        await _searchNow();
      }
    } else {
      final state = await _refreshOcrState(item.id);
      if (_searchActive &&
          (_selectedTag != null ||
              state == OcrItemState.completedWithText ||
              state == OcrItemState.completedWithoutText)) {
        await _searchNow();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-print-button'),
        onPressed: _isLoading ? null : _pickScreenshots,
        tooltip: 'Escolher screenshot existente',
        icon: _isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Adicionar print'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          scrollCacheExtent: const ScrollCacheExtent.pixels(600),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AppHeader(
                          onOpenTags: _openTags,
                          onOpenSettings: _openSettings,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _SearchField(
                                controller: _searchController,
                                showClearAction:
                                    _searchController.text.isNotEmpty,
                                onChanged: _onSearchChanged,
                                onSubmitted: _submitSearch,
                                onClear: _clearSearch,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              key: const Key('open-tag-filter'),
                              onPressed: _openTagFilter,
                              tooltip: _selectedTag == null
                                  ? 'Filtrar biblioteca por etiqueta'
                                  : 'Alterar filtro de etiqueta',
                              isSelected: _selectedTag != null,
                              icon: const Icon(Icons.filter_alt_outlined),
                              selectedIcon: const Icon(Icons.filter_alt),
                            ),
                          ],
                        ),
                        if (_selectedTag != null ||
                            _filterErrorMessage != null) ...[
                          const SizedBox(height: 8),
                          _ActiveTagFilter(
                            tag: _selectedTag,
                            isLoading: _isFiltering,
                            errorMessage: _filterErrorMessage,
                            onClear: () => unawaited(_applyTagFilter(null)),
                            onRetry: () => unawaited(_retryCurrentResults()),
                          ),
                        ],
                        if (_automaticImportState !=
                                AutomaticImportUiState.disabled &&
                            _automaticImportState !=
                                AutomaticImportUiState.active) ...[
                          const SizedBox(height: 10),
                          _AutomaticImportNotice(
                            state: _automaticImportState,
                            onAction: () => unawaited(_openSettings()),
                          ),
                        ],
                        if (_errorMessage != null ||
                            _duplicateMessage != null) ...[
                          const SizedBox(height: 10),
                          _ImportFeedback(
                            errorMessage: _errorMessage,
                            infoMessage: _duplicateMessage,
                            onRetry: _initialPageFailed
                                ? () => unawaited(_initialize())
                                : null,
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_recentFolders.isNotEmpty) ...[
                          const _SectionTitle(
                            'Pastas recentes',
                            key: Key('recent-folders-title'),
                          ),
                          const SizedBox(height: 8),
                          _RecentFoldersSection(
                            folders: _recentFolders,
                            onFolder: (folder) => _openCategory(
                              CategorySummary(
                                category: folder.category,
                                mediaCount: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        _SectionHeader(
                          title: 'Pastas',
                          actionLabel: 'Gerenciar pastas',
                          actionKey: const Key('categories-summary'),
                          onAction: _openCategories,
                        ),
                        const SizedBox(height: 8),
                        _FoldersSection(
                          categories: _categories,
                          isLoading: _areCategoriesLoading,
                          errorMessage: _categoriesErrorMessage,
                          onAll: () => unawaited(_applyTagFilter(null)),
                          onCategory: _openCategory,
                          onCreate: _openCategories,
                          onRetry: _reloadCategories,
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Expanded(
                              child: _SectionTitle(
                                'Todos os prints',
                                key: Key('all-prints-title'),
                              ),
                            ),
                            Text(
                              '${_searchActive ? _searchResults.length : _mediaItems.length} '
                              '${(_searchActive ? _searchResults.length : _mediaItems.length) == 1 ? 'item' : 'itens'}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        if (_searchActive) ...[
                          const SizedBox(height: 8),
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
                            onRetry: () => unawaited(_retryCurrentResults()),
                          ),
                          if (!_isSearching &&
                              _searchErrorMessage == null &&
                              _searchResults.isEmpty)
                            _EmptySearchState(
                              message: 'Nenhum print corresponde à pesquisa.',
                              onClearFilter: _selectedTag == null
                                  ? null
                                  : () => unawaited(_applyTagFilter(null)),
                            )
                          else if (_searchResults.isNotEmpty)
                            const SizedBox(height: 8),
                        ] else if (_mediaItems.isNotEmpty) ...[
                          const SizedBox(height: 10),
                        ] else if (!_isLoading && !_isFiltering) ...[
                          const SizedBox(height: 10),
                          _EmptySearchState(
                            message: _selectedTag == null
                                ? 'Nenhum print salvo.'
                                : 'Nenhum print encontrado com esta etiqueta.',
                            onClearFilter: _selectedTag == null
                                ? null
                                : () => unawaited(_applyTagFilter(null)),
                            actionLabel: _selectedTag == null
                                ? 'Adicionar print'
                                : null,
                            onAction: _selectedTag == null
                                ? _pickScreenshots
                                : null,
                          ),
                        ] else if (_isLoading) ...[
                          const SizedBox(height: 20),
                          const Center(child: CircularProgressIndicator()),
                        ],
                        if ((_searchActive && _searchResults.isNotEmpty) ||
                            (!_searchActive && _mediaItems.isNotEmpty)) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Salvo neste dispositivo.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_searchActive && _searchResults.isNotEmpty)
              SliverPadding(
                padding: _gridPadding(context),
                sliver: ScreenshotSliverGrid(
                  mediaItems: _searchResults
                      .map((result) => result.mediaItem)
                      .toList(growable: false),
                  ocrStates: _ocrStates,
                  snippets: {
                    for (final result in _searchResults)
                      result.mediaItem.id: result.snippet,
                  },
                  onItemTap: _openDetails,
                  thumbnailGateway:
                      widget.mediaStoreContentGateway ??
                      const MethodChannelMediaStoreContentGateway(),
                ),
              )
            else if (!_searchActive && _mediaItems.isNotEmpty)
              SliverPadding(
                padding: _gridPadding(context),
                sliver: ScreenshotSliverGrid(
                  mediaItems: _mediaItems,
                  ocrStates: _ocrStates,
                  onItemTap: _openDetails,
                  thumbnailGateway:
                      widget.mediaStoreContentGateway ??
                      const MethodChannelMediaStoreContentGateway(),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              sliver: SliverToBoxAdapter(child: _buildPageFooter()),
            ),
          ],
        ),
      ),
    );
  }

  EdgeInsets _gridPadding(BuildContext context) {
    return const EdgeInsets.symmetric(horizontal: 16);
  }

  Widget _buildPageFooter() {
    if (_isLoadingNextPage) {
      return Semantics(
        label: 'Carregando mais prints',
        child: const Center(
          child: SizedBox.square(
            key: Key('next-page-loading'),
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_nextPageErrorMessage case final message?) {
      return Semantics(
        liveRegion: true,
        label: message,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(message)),
            const SizedBox(width: 8),
            TextButton(
              key: const Key('retry-next-page'),
              onPressed: () => unawaited(_loadNextPage()),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.onOpenTags, required this.onOpenSettings});

  final VoidCallback onOpenTags;
  final VoidCallback onOpenSettings;

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
                'MemoShot',
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
          key: const Key('open-settings'),
          onPressed: onOpenSettings,
          tooltip: 'Configurações',
          icon: const Icon(Icons.settings_outlined),
        ),
        PopupMenuButton<String>(
          key: const Key('home-actions-menu'),
          tooltip: 'Mais ações',
          onSelected: (action) {
            if (action == 'tags') onOpenTags();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'tags',
              child: ListTile(
                leading: Icon(Icons.label_outline),
                title: Text('Gerenciar etiquetas'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
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
        key: const Key('home-search-field'),
        controller: controller,
        enabled: true,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Pesquisar nos seus prints...',
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
  const _SectionTitle(this.text, {super.key});

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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.actionKey,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final Key actionKey;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SectionTitle(title, key: const Key('folders-title'))),
        IconButton(
          key: actionKey,
          onPressed: onAction,
          tooltip: actionLabel,
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    );
  }
}

class _FoldersSection extends StatelessWidget {
  const _FoldersSection({
    required this.categories,
    required this.isLoading,
    required this.errorMessage,
    required this.onAll,
    required this.onCategory,
    required this.onCreate,
    required this.onRetry,
  });

  final List<CategorySummary> categories;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onAll;
  final ValueChanged<CategorySummary> onCategory;
  final VoidCallback onCreate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (isLoading) {
      return const SizedBox(
        height: 76,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorMessage != null) {
      return _CompactMessage(
        icon: Icons.folder_off_outlined,
        message: errorMessage!,
        actionLabel: 'Tentar novamente',
        onAction: onRetry,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FolderTile(
                key: const Key('all-folder'),
                name: 'Todos',
                count: null,
                onTap: onAll,
              ),
              for (final summary in categories) ...[
                const SizedBox(width: 8),
                _FolderTile(
                  key: Key('folder-${summary.category.id}'),
                  name: summary.category.name,
                  count: summary.mediaCount,
                  onTap: () => onCategory(summary),
                ),
              ],
            ],
          ),
        ),
        if (categories.isEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Nenhuma pasta criada.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Criar pasta'),
            ),
          ),
        ],
      ],
    );
  }
}

class _RecentFoldersSection extends StatelessWidget {
  const _RecentFoldersSection({required this.folders, required this.onFolder});

  final List<RecentFolder> folders;
  final ValueChanged<RecentFolder> onFolder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        key: const Key('recent-folders-list'),
        scrollDirection: Axis.horizontal,
        itemCount: folders.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final folder = folders[index];
          return Tooltip(
            message: folder.fullPath,
            child: _FolderTile(
              key: Key('recent-folder-${folder.category.id}'),
              name: folder.category.name,
              count: null,
              semanticLabel: 'Abrir pasta ${folder.fullPath}',
              onTap: () => onFolder(folder),
            ),
          );
        },
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    super.key,
    required this.name,
    required this.count,
    required this.onTap,
    this.semanticLabel,
  });

  final String name;
  final int? count;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label:
          semanticLabel ??
          (count == null
              ? 'Pasta $name'
              : 'Pasta $name, $count ${count == 1 ? 'print' : 'prints'}'),
      child: SizedBox(
        width: 112,
        height: 52,
        child: Card(
          margin: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: onTap,
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: count == null ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (count != null)
                    Text(
                      '$count ${count == 1 ? 'print' : 'prints'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutomaticImportNotice extends StatelessWidget {
  const _AutomaticImportNotice({required this.state, required this.onAction});

  final AutomaticImportUiState state;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final (message, action) = switch (state) {
      AutomaticImportUiState.accessRequired => (
        'Permita o acesso às imagens para organizar novos prints.',
        'Conceder acesso',
      ),
      AutomaticImportUiState.limitedAccess => (
        'O acesso parcial às imagens impede a organização de novos prints.',
        'Revisar acesso',
      ),
      _ => (
        'A organização automática não está disponível neste dispositivo.',
        'Tentar novamente',
      ),
    };
    return _CompactMessage(
      key: const Key('automatic-import-notice'),
      icon: Icons.warning_amber_rounded,
      message: message,
      actionLabel: action,
      onAction: onAction,
    );
  }
}

class _ImportFeedback extends StatelessWidget {
  const _ImportFeedback({
    required this.errorMessage,
    required this.infoMessage,
    this.onRetry,
  });

  final String? errorMessage;
  final String? infoMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final error = errorMessage != null;
    return _CompactMessage(
      icon: error ? Icons.error_outline : Icons.info_outline,
      message: error ? errorMessage! : infoMessage!,
      actionLabel: onRetry == null ? null : 'Tentar novamente',
      onAction: onRetry,
    );
  }
}

class _CompactMessage extends StatelessWidget {
  const _CompactMessage({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.secondary),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
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
    required this.onRetry,
  });

  final String query;
  final int resultCount;
  final bool isSearching;
  final String? errorMessage;
  final bool hasPendingItems;
  final VoidCallback onRetry;

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
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({
    required this.message,
    this.onClearFilter,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final VoidCallback? onClearFilter;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onClearFilter != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onClearFilter,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpar filtro'),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveTagFilter extends StatelessWidget {
  const _ActiveTagFilter({
    required this.tag,
    required this.isLoading,
    required this.errorMessage,
    required this.onClear,
    required this.onRetry,
  });

  final Tag? tag;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onClear;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tag != null)
          Semantics(
            label: 'Filtro ativo: etiqueta ${tag!.name}',
            child: InputChip(
              key: const Key('active-tag-filter-chip'),
              avatar: isLoading
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.7),
                    )
                  : const Icon(Icons.label_outline, size: 18),
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  'Etiqueta: ${tag!.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              deleteIcon: const Icon(Icons.close, size: 18),
              deleteButtonTooltipMessage: 'Limpar filtro',
              onDeleted: isLoading ? null : onClear,
            ),
          ),
        if (errorMessage != null) ...[
          Text(
            errorMessage!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.error),
          ),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ],
    );
  }
}

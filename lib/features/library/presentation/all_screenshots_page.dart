import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../../core/media/original_media_viewer.dart';
import '../../../core/media_store/media_store_content.dart';
import '../../../core/text/text_normalizer.dart';
import '../../categories/data/category_repository.dart';
import '../../classification/application/classification_processor.dart';
import '../../ocr/data/ocr_repository.dart';
import '../../processing/data/ocr_queue_processor.dart';
import '../../processing/domain/processing_job.dart';
import '../../tags/data/tag_repository.dart';
import '../../tags/domain/tag.dart';
import '../../tags/presentation/tag_filter_dialog.dart';
import '../data/media_item_repository.dart';
import '../domain/media_item.dart';
import '../domain/media_page.dart';
import '../domain/screenshot_search_result.dart';
import 'screenshot_detail_page.dart';
import 'screenshot_grid.dart';

class AllScreenshotsPage extends StatefulWidget {
  const AllScreenshotsPage({
    required this.mediaRepository,
    required this.ocrRepository,
    required this.ocrQueue,
    required this.categoryRepository,
    required this.tagRepository,
    this.classificationReprocessor,
    this.initialQuery = '',
    this.initialTag,
    this.autofocusSearch = false,
    this.thumbnailGateway = const MethodChannelMediaStoreContentGateway(),
    this.originalMediaViewer = const MethodChannelOriginalMediaViewer(),
    super.key,
  });

  final MediaItemRepository mediaRepository;
  final OcrRepository ocrRepository;
  final OcrQueue ocrQueue;
  final CategoryRepository categoryRepository;
  final TagRepository tagRepository;
  final IndividualClassificationReprocessor? classificationReprocessor;
  final String initialQuery;
  final Tag? initialTag;
  final bool autofocusSearch;
  final MediaStoreContentGateway thumbnailGateway;
  final OriginalMediaViewer originalMediaViewer;

  @override
  State<AllScreenshotsPage> createState() => _AllScreenshotsPageState();
}

class _AllScreenshotsPageState extends State<AllScreenshotsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextNormalizer _normalizer = const TextNormalizer();
  late final TextEditingController _searchController;
  Timer? _debounce;
  Tag? _selectedTag;
  List<MediaItem> _items = const [];
  List<ScreenshotSearchResult> _searchResults = const [];
  Map<int, OcrItemState> _ocrStates = const {};
  MediaPageCursor? _nextCursor;
  bool _loading = true;
  bool _loadingNext = false;
  String? _initialError;
  String? _nextError;
  int _generation = 0;

  bool get _searchActive =>
      _normalizer.normalize(_searchController.text).isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedTag = widget.initialTag;
    _searchController = TextEditingController(text: widget.initialQuery);
    _scrollController.addListener(_handleScroll);
    unawaited(_loadFirst());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFirst() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _initialError = null;
      _nextError = null;
      _nextCursor = null;
    });
    try {
      final loaded = await _loadPage(cursor: null);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = loaded.items;
        _searchResults = loaded.searchResults;
        _ocrStates = loaded.ocrStates;
        _nextCursor = loaded.nextCursor;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _initialError = 'Não foi possível carregar seus prints.';
      });
    }
  }

  Future<_LoadedLibraryPage> _loadPage({
    required MediaPageCursor? cursor,
  }) async {
    final request = MediaPageRequest(
      cursor: cursor,
      tagIds: {?_selectedTag?.id},
    );
    final repository = widget.mediaRepository;
    List<MediaItem> items;
    List<ScreenshotSearchResult> searchResults = const [];
    MediaPageCursor? nextCursor;
    if (_searchActive) {
      final page = repository is PagedMediaItemRepository
          ? await repository.searchMediaPageByTags(
              _searchController.text,
              request,
            )
          : MediaPage<ScreenshotSearchResult>(
              items: await repository.searchRecognizedText(
                _searchController.text,
                tagId: _selectedTag?.id,
                limit: defaultMediaPageSize,
              ),
              nextCursor: null,
            );
      searchResults = page.items;
      items = page.items.map((result) => result.mediaItem).toList();
      nextCursor = page.nextCursor;
    } else {
      final page = repository is PagedMediaItemRepository
          ? await repository.loadMediaPageByTags(request)
          : MediaPage<MediaItem>(
              items: (await repository.loadAvailableItems(
                tagId: _selectedTag?.id,
              )).take(defaultMediaPageSize).toList(),
              nextCursor: null,
            );
      items = page.items;
      nextCursor = page.nextCursor;
    }
    final states = <int, OcrItemState>{};
    for (final item in items) {
      states[item.id] = await widget.ocrQueue.loadState(item.id);
    }
    return _LoadedLibraryPage(
      items: items,
      searchResults: searchResults,
      ocrStates: states,
      nextCursor: nextCursor,
    );
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 600) {
      unawaited(_loadNext());
    }
  }

  Future<void> _loadNext() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingNext) return;
    final generation = _generation;
    setState(() {
      _loadingNext = true;
      _nextError = null;
    });
    try {
      final loaded = await _loadPage(cursor: cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        final ids = _items.map((item) => item.id).toSet();
        _items = [..._items, ...loaded.items.where((item) => ids.add(item.id))];
        if (_searchActive) {
          final resultIds = _searchResults
              .map((result) => result.mediaItem.id)
              .toSet();
          _searchResults = [
            ..._searchResults,
            ...loaded.searchResults.where(
              (result) => resultIds.add(result.mediaItem.id),
            ),
          ];
        }
        _ocrStates = {..._ocrStates, ...loaded.ocrStates};
        _nextCursor = loaded.nextCursor;
        _loadingNext = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingNext = false;
        _nextError = 'Não foi possível carregar mais prints.';
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _loadFirst);
    setState(() {});
  }

  Future<void> _openTagFilter() async {
    final selection = await showDialog<TagFilterSelection>(
      context: context,
      builder: (_) => TagFilterDialog(
        repository: widget.tagRepository,
        selectedTagId: _selectedTag?.id,
      ),
    );
    if (!mounted || selection == null) return;
    setState(() => _selectedTag = selection.tag);
    await _loadFirst();
  }

  Future<void> _openDetails(MediaItem item) async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScreenshotDetailPage(
          mediaItem: item,
          mediaRepository: widget.mediaRepository,
          ocrRepository: widget.ocrRepository,
          ocrQueue: widget.ocrQueue,
          categoryRepository: widget.categoryRepository,
          tagRepository: widget.tagRepository,
          classificationReprocessor: widget.classificationReprocessor,
          thumbnailGateway: widget.thumbnailGateway,
          originalMediaViewer: widget.originalMediaViewer,
        ),
      ),
    );
    if (!mounted) return;
    if (removed == true) {
      setState(() {
        _items = _items.where((value) => value.id != item.id).toList();
        _searchResults = _searchResults
            .where((value) => value.mediaItem.id != item.id)
            .toList();
        _ocrStates = {..._ocrStates}..remove(item.id);
      });
      return;
    }
    final refreshed = await widget.mediaRepository.loadById(item.id);
    if (!mounted || refreshed == null) return;
    setState(() {
      _items = [
        for (final value in _items)
          if (value.id == refreshed.id) refreshed else value,
      ];
      _searchResults = [
        for (final value in _searchResults)
          if (value.mediaItem.id == refreshed.id)
            ScreenshotSearchResult(mediaItem: refreshed, snippet: value.snippet)
          else
            value,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _searchActive
        ? _searchResults.map((result) => result.mediaItem).toList()
        : _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca')),
      body: SafeArea(
        child: CustomScrollView(
          key: const PageStorageKey('all-screenshots-scroll'),
          controller: _scrollController,
          scrollCacheExtent: const ScrollCacheExtent.pixels(600),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('library-search-field'),
                        controller: _searchController,
                        autofocus: widget.autofocusSearch,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Pesquisar nos seus prints...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpar pesquisa',
                                  onPressed: () {
                                    _searchController.clear();
                                    unawaited(_loadFirst());
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      key: const Key('library-tag-filter'),
                      onPressed: _openTagFilter,
                      tooltip: 'Filtrar biblioteca por etiqueta',
                      isSelected: _selectedTag != null,
                      icon: const Icon(Icons.filter_alt_outlined),
                      selectedIcon: const Icon(Icons.filter_alt),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedTag case final tag?)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      label: Text(tag.name),
                      onDeleted: () {
                        setState(() => _selectedTag = null);
                        unawaited(_loadFirst());
                      },
                    ),
                  ),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_initialError case final message?)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _LibraryMessage(
                  message: message,
                  actionLabel: 'Tentar novamente',
                  onAction: _loadFirst,
                ),
              )
            else if (visibleItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _LibraryMessage(
                  message: _searchActive || _selectedTag != null
                      ? 'Nenhum print corresponde aos filtros.'
                      : 'Nenhum print salvo.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    _searchActive ? 'Resultados' : 'Todos os prints',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: ScreenshotSliverGrid(
                  mediaItems: visibleItems,
                  ocrStates: _ocrStates,
                  snippets: {
                    for (final result in _searchResults)
                      result.mediaItem.id: result.snippet,
                  },
                  onItemTap: _openDetails,
                  thumbnailGateway: widget.thumbnailGateway,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverToBoxAdapter(child: _buildFooter()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    if (_loadingNext) {
      return const Center(
        child: SizedBox.square(
          key: Key('library-next-page-loading'),
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_nextError case final message?) {
      return _LibraryMessage(
        message: message,
        actionLabel: 'Tentar novamente',
        onAction: _loadNext,
      );
    }
    return const SizedBox.shrink();
  }
}

final class _LoadedLibraryPage {
  const _LoadedLibraryPage({
    required this.items,
    required this.searchResults,
    required this.ocrStates,
    required this.nextCursor,
  });

  final List<MediaItem> items;
  final List<ScreenshotSearchResult> searchResults;
  final Map<int, OcrItemState> ocrStates;
  final MediaPageCursor? nextCursor;
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const Key('library-message-action'),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

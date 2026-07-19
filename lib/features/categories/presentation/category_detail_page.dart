import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../library/data/media_item_repository.dart';
import '../../library/domain/media_item.dart';
import '../../library/domain/media_page.dart';
import '../../library/presentation/screenshot_detail_page.dart';
import '../../library/presentation/screenshot_grid.dart';
import '../../ocr/data/ocr_repository.dart';
import '../../processing/data/ocr_queue_processor.dart';
import '../../processing/domain/processing_job.dart';
import '../../tags/data/tag_repository.dart';
import '../data/category_repository.dart';
import '../data/recent_folder_repository.dart';
import '../domain/category.dart';
import 'folder_management_dialogs.dart';

const categoryDetailRouteName = '/categories/detail';

Route<bool> buildCategoryDetailRoute({
  required CategorySummary summary,
  required CategoryRepository categoryRepository,
  required MediaItemRepository mediaRepository,
  required OcrRepository ocrRepository,
  required OcrQueue ocrQueue,
  required TagRepository tagRepository,
  RecentFolderRepository? recentFolderRepository,
}) {
  return MaterialPageRoute<bool>(
    settings: RouteSettings(
      name: categoryDetailRouteName,
      arguments: summary.category.id,
    ),
    builder: (_) => CategoryDetailPage(
      summary: summary,
      categoryRepository: categoryRepository,
      mediaRepository: mediaRepository,
      ocrRepository: ocrRepository,
      ocrQueue: ocrQueue,
      tagRepository: tagRepository,
      recentFolderRepository: recentFolderRepository,
    ),
  );
}

class CategoryDetailPage extends StatefulWidget {
  const CategoryDetailPage({
    required this.summary,
    required this.categoryRepository,
    required this.mediaRepository,
    required this.ocrRepository,
    required this.ocrQueue,
    required this.tagRepository,
    this.recentFolderRepository,
    super.key,
  });

  final CategorySummary summary;
  final CategoryRepository categoryRepository;
  final MediaItemRepository mediaRepository;
  final OcrRepository ocrRepository;
  final OcrQueue ocrQueue;
  final TagRepository tagRepository;
  final RecentFolderRepository? recentFolderRepository;

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late Category _category = widget.summary.category;
  CategoryPath? _path;
  List<CategorySummary> _children = const [];
  List<MediaItem> _items = const [];
  Map<int, OcrItemState> _ocrStates = const {};
  bool _folderLoading = true;
  bool _childrenLoading = true;
  bool _itemsLoading = true;
  bool _isLoadingNextPage = false;
  String? _nextPageError;
  MediaPageCursor? _nextCursor;
  int _itemCount = 0;
  bool _loadedFolderOnce = false;
  bool _dialogOpen = false;
  String? _folderError;
  String? _childrenError;
  String? _itemsError;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _itemCount = widget.summary.mediaCount;
    _scrollController.addListener(_handleScroll);
    unawaited(_load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _folderLoading = true;
        _childrenLoading = true;
        _itemsLoading = true;
        _isLoadingNextPage = false;
        _nextPageError = null;
        _nextCursor = null;
        _folderError = null;
        _childrenError = null;
        _itemsError = null;
      });
    }

    try {
      final category = await widget.categoryRepository.findCategoryById(
        _category.id,
      );
      if (!mounted || generation != _loadGeneration) return;
      if (category == null) {
        if (_loadedFolderOnce) {
          Navigator.of(context).pop(true);
          return;
        }
        setState(() {
          _folderLoading = false;
          _folderError = 'Pasta não encontrada.';
          _childrenLoading = false;
          _itemsLoading = false;
        });
        return;
      }
      final path = await widget.categoryRepository.loadPath(category.id);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _category = category;
        _path = path;
        _folderLoading = false;
        _loadedFolderOnce = true;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _folderLoading = false;
        _folderError = 'Não foi possível carregar a pasta.';
        _childrenLoading = false;
        _itemsLoading = false;
      });
      return;
    }

    await Future.wait([_loadChildren(generation), _loadItems(generation)]);
  }

  Future<void> _loadChildren(int generation) async {
    try {
      final children = await widget.categoryRepository
          .loadChildCategorySummaries(_category.id);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _children = children;
        _childrenLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _childrenLoading = false;
        _childrenError = 'Não foi possível carregar as subpastas.';
      });
    }
  }

  Future<void> _loadItems(int generation) async {
    try {
      final repository = widget.categoryRepository;
      final previousItemCount = _items.length;
      var page = repository is PagedCategoryRepository
          ? await repository.loadMediaPageByCategory(_category.id)
          : MediaPage<MediaItem>(
              items: await repository.loadMediaForCategory(_category.id),
              nextCursor: null,
            );
      final items = [...page.items];
      while (repository is PagedCategoryRepository &&
          items.length < previousItemCount &&
          page.nextCursor != null) {
        page = await repository.loadMediaPageByCategory(
          _category.id,
          MediaPageRequest(cursor: page.nextCursor),
        );
        items.addAll(page.items);
      }
      final states = <int, OcrItemState>{};
      for (final item in items) {
        states[item.id] = await widget.ocrQueue.loadState(item.id);
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items = items;
        if (repository is! PagedCategoryRepository) {
          _itemCount = items.length;
        }
        _ocrStates = states;
        _nextCursor = page.nextCursor;
        _nextPageError = null;
        _itemsLoading = false;
      });
      unawaited(_loadItemCount(generation));
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _itemsLoading = false;
        _itemsError = 'Não foi possível carregar os prints desta pasta.';
      });
    }
  }

  Future<void> _loadItemCount(int generation) async {
    final repository = widget.categoryRepository;
    if (repository is! PagedCategoryRepository) return;
    try {
      final count = await repository.countMediaItemsByCategory(_category.id);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _itemCount = count);
    } catch (_) {
      // A contagem independente não bloqueia a grade.
    }
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 600) {
      unawaited(_loadNextPage());
    }
  }

  Future<void> _loadNextPage() async {
    final cursor = _nextCursor;
    final repository = widget.categoryRepository;
    if (cursor == null ||
        _isLoadingNextPage ||
        repository is! PagedCategoryRepository) {
      return;
    }
    final generation = _loadGeneration;
    setState(() {
      _isLoadingNextPage = true;
      _nextPageError = null;
    });
    try {
      final page = await repository.loadMediaPageByCategory(
        _category.id,
        MediaPageRequest(cursor: cursor),
      );
      final states = <int, OcrItemState>{};
      for (final item in page.items) {
        states[item.id] = await widget.ocrQueue.loadState(item.id);
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        final existing = _items.map((item) => item.id).toSet();
        _items = [
          ..._items,
          ...page.items.where((item) => existing.add(item.id)),
        ];
        _ocrStates = {..._ocrStates, ...states};
        _nextCursor = page.nextCursor;
        _isLoadingNextPage = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoadingNextPage = false;
        _nextPageError = 'Não foi possível carregar mais prints.';
      });
    }
  }

  Future<void> _openItem(MediaItem item) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScreenshotDetailPage(
          mediaItem: item,
          mediaRepository: widget.mediaRepository,
          ocrRepository: widget.ocrRepository,
          ocrQueue: widget.ocrQueue,
          categoryRepository: widget.categoryRepository,
          tagRepository: widget.tagRepository,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openChild(CategorySummary summary) async {
    await _recordAccess(summary.category.id);
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      buildCategoryDetailRoute(
        summary: summary,
        categoryRepository: widget.categoryRepository,
        mediaRepository: widget.mediaRepository,
        ocrRepository: widget.ocrRepository,
        ocrQueue: widget.ocrQueue,
        tagRepository: widget.tagRepository,
        recentFolderRepository: widget.recentFolderRepository,
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _withDialog(Future<void> Function() operation) async {
    if (_dialogOpen) return;
    setState(() => _dialogOpen = true);
    try {
      await operation();
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  Future<void> _createChild() => _withDialog(() async {
    final created = await showCreateCategoryDialog(
      context,
      widget.categoryRepository,
      fixedParent: _category,
    );
    if (created != null && mounted) await _load();
  });

  Future<void> _rename() => _withDialog(() async {
    final renamed = await showRenameCategoryDialog(
      context,
      widget.categoryRepository,
      _category,
    );
    if (renamed != null && mounted) await _load();
  });

  Future<void> _move() => _withDialog(() async {
    final moved = await showMoveCategoryDialog(
      context,
      widget.categoryRepository,
      _category,
    );
    if (moved != null && mounted) await _load();
  });

  Future<void> _delete() => _withDialog(() async {
    final deleted = await confirmCategoryDeletion(
      context,
      widget.categoryRepository,
      CategorySummary(category: _category, mediaCount: _itemCount),
    );
    if (deleted) {
      try {
        await widget.recentFolderRepository?.remove(_category.id);
      } catch (_) {
        // O histórico nunca bloqueia a exclusão já concluída da pasta.
      }
      if (mounted) Navigator.pop(context, true);
    }
  });

  Future<void> _openAncestor(Category category) async {
    await _recordAccess(category.id);
    if (!mounted) return;
    Navigator.of(context).popUntil(
      (route) =>
          route.settings.name == categoryDetailRouteName &&
          route.settings.arguments == category.id,
    );
  }

  Future<void> _recordAccess(int categoryId) async {
    try {
      await widget.recentFolderRepository?.recordAccess(categoryId);
    } catch (_) {
      // Falhas nas preferências não impedem a navegação entre pastas.
    }
  }

  void _openFoldersRoot() {
    Navigator.of(
      context,
    ).popUntil((route) => route.settings.name != categoryDetailRouteName);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _category.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: colors.surface,
        foregroundColor: colors.primary,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Ações da pasta',
            enabled: !_dialogOpen,
            onSelected: (action) {
              if (action == 'create-child') unawaited(_createChild());
              if (action == 'rename') unawaited(_rename());
              if (action == 'move') unawaited(_move());
              if (action == 'delete') unawaited(_delete());
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'create-child',
                child: Text('Nova subpasta'),
              ),
              const PopupMenuItem(value: 'rename', child: Text('Renomear')),
              const PopupMenuItem(value: 'move', child: Text('Mover')),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Excluir pasta',
                  style: TextStyle(color: colors.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          scrollCacheExtent: const ScrollCacheExtent.pixels(600),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_folderLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (_folderError != null)
                          _SectionError(
                            message: _folderError!,
                            onRetry: () => unawaited(_load()),
                          )
                        else ...[
                          _CategoryBreadcrumb(
                            path: _path!,
                            onFolders: _openFoldersRoot,
                            onAncestor: (category) =>
                                unawaited(_openAncestor(category)),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Subpastas',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          if (_childrenLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (_childrenError != null)
                            _SectionError(
                              message: _childrenError!,
                              onRetry: () => unawaited(_load()),
                            )
                          else if (_children.isEmpty)
                            Text(
                              'Nenhuma subpasta.',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            )
                          else
                            ..._children.map(
                              (summary) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _SubfolderTile(
                                  summary: summary,
                                  onTap: () => _openChild(summary),
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Prints nesta pasta',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              if (!_itemsLoading && _itemsError == null)
                                Text(
                                  '$_itemCount ${_itemCount == 1 ? 'print' : 'prints'}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_itemsLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (_itemsError != null)
                            _SectionError(
                              message: _itemsError!,
                              onRetry: () => unawaited(_load()),
                            )
                          else if (_items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 28),
                              child: Center(
                                child: Text('Nenhum print nesta pasta.'),
                              ),
                            )
                          else
                            const SizedBox(height: 2),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!_itemsLoading && _itemsError == null && _items.isNotEmpty)
              SliverPadding(
                padding: _gridPadding(context),
                sliver: ScreenshotSliverGrid(
                  mediaItems: _items,
                  ocrStates: _ocrStates,
                  onItemTap: _openItem,
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
            key: Key('category-next-page-loading'),
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_nextPageError case final message?) {
      return Semantics(
        liveRegion: true,
        label: message,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(message)),
            const SizedBox(width: 8),
            TextButton(
              key: const Key('category-retry-next-page'),
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

class _CategoryBreadcrumb extends StatelessWidget {
  const _CategoryBreadcrumb({
    required this.path,
    required this.onFolders,
    required this.onAncestor,
  });

  final CategoryPath path;
  final VoidCallback onFolders;
  final ValueChanged<Category> onAncestor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Caminho da pasta: Pastas, ${path.categories.map((item) => item.name).join(', ')}',
      child: SingleChildScrollView(
        key: const Key('category-breadcrumb'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            TextButton(
              key: const Key('breadcrumb-folders'),
              onPressed: onFolders,
              child: const Text('Pastas'),
            ),
            for (var index = 0; index < path.categories.length; index++) ...[
              const Icon(Icons.chevron_right, size: 18),
              if (index == path.categories.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    path.categories[index].name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              else
                TextButton(
                  key: Key('breadcrumb-${path.categories[index].id}'),
                  onPressed: () => onAncestor(path.categories[index]),
                  child: Text(path.categories[index].name),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubfolderTile extends StatelessWidget {
  const _SubfolderTile({required this.summary, required this.onTap});

  final CategorySummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final printText =
        '${summary.mediaCount} ${summary.mediaCount == 1 ? 'print' : 'prints'}';
    final childText =
        '${summary.childCount} ${summary.childCount == 1 ? 'subpasta' : 'subpastas'}';
    return Card(
      margin: EdgeInsets.zero,
      child: Semantics(
        button: true,
        label: 'Abrir pasta ${summary.category.name}, $printText, $childText',
        child: ListTile(
          key: Key('subfolder-${summary.category.id}'),
          onTap: onTap,
          leading: const Icon(Icons.folder_outlined),
          title: Text(
            summary.category.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('$printText · $childText'),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
      ],
    );
  }
}

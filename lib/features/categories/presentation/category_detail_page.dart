import 'package:flutter/material.dart';

import '../../library/data/media_item_repository.dart';
import '../../library/domain/media_item.dart';
import '../../library/presentation/screenshot_detail_page.dart';
import '../../library/presentation/screenshot_grid.dart';
import '../../ocr/data/ocr_repository.dart';
import '../../processing/data/ocr_queue_processor.dart';
import '../../processing/domain/processing_job.dart';
import '../../tags/data/tag_repository.dart';
import '../data/category_repository.dart';
import '../domain/category.dart';
import 'categories_page.dart';

class CategoryDetailPage extends StatefulWidget {
  const CategoryDetailPage({
    required this.summary,
    required this.categoryRepository,
    required this.mediaRepository,
    required this.ocrRepository,
    required this.ocrQueue,
    required this.tagRepository,
    super.key,
  });

  final CategorySummary summary;
  final CategoryRepository categoryRepository;
  final MediaItemRepository mediaRepository;
  final OcrRepository ocrRepository;
  final OcrQueue ocrQueue;
  final TagRepository tagRepository;

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  late Category _category = widget.summary.category;
  late int _mediaCount = widget.summary.mediaCount;
  List<MediaItem> _items = const [];
  Map<int, OcrItemState> _ocrStates = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.categoryRepository.loadMediaForCategory(
        _category.id,
      );
      final summaries = await widget.categoryRepository.loadCategories();
      final matching = summaries.where(
        (summary) => summary.category.id == _category.id,
      );
      final states = <int, OcrItemState>{};
      for (final item in items) {
        states[item.id] = await widget.ocrQueue.loadState(item.id);
      }
      if (mounted) {
        setState(() {
          _items = items;
          _mediaCount = matching.isEmpty
              ? items.length
              : matching.single.mediaCount;
          _ocrStates = states;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar a categoria.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
    await _load();
  }

  Future<void> _rename() async {
    final renamed = await showRenameCategoryDialog(
      context,
      widget.categoryRepository,
      _category,
    );
    if (renamed != null && mounted) setState(() => _category = renamed);
  }

  Future<void> _delete() async {
    final deleted = await confirmCategoryDeletion(
      context,
      widget.categoryRepository,
      CategorySummary(category: _category, mediaCount: _mediaCount),
    );
    if (deleted && mounted) Navigator.pop(context, true);
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
            tooltip: 'Ações da categoria',
            onSelected: (action) {
              if (action == 'rename') _rename();
              if (action == 'delete') _delete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Renomear')),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Excluir categoria',
                  style: TextStyle(color: colors.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$_mediaCount '
                    '${_mediaCount == 1 ? 'screenshot' : 'screenshots'}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    Text(_error!, style: TextStyle(color: colors.error))
                  else if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('Nenhum screenshot nesta categoria.'),
                      ),
                    )
                  else
                    ScreenshotGrid(
                      mediaItems: _items,
                      ocrStates: _ocrStates,
                      onItemTap: _openItem,
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

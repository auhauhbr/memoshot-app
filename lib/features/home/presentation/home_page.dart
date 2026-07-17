import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/database/contexto_database.dart' show ContextoDatabase;
import '../../../core/media/image_picker_screenshot_picker.dart';
import '../../../core/media/screenshot_picker.dart';
import '../../../core/media/screenshot_storage.dart';
import '../../../core/ocr/ml_kit_text_recognition_service.dart';
import '../../library/data/media_item_repository.dart';
import '../../library/data/media_item_store.dart';
import '../../library/domain/media_item.dart';
import '../../library/domain/selected_screenshot.dart';
import '../../library/presentation/screenshot_detail_page.dart';
import '../../ocr/data/ocr_repository.dart';
import '../../ocr/data/ocr_result_store.dart';
import '../../processing/data/ocr_job_scheduler.dart';
import '../../processing/data/ocr_queue_processor.dart';
import '../../processing/data/processing_job_store.dart';
import '../../processing/domain/processing_job.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.screenshotPicker,
    this.mediaRepository,
    this.ocrRepository,
    this.ocrQueue,
  });

  final ScreenshotPicker? screenshotPicker;
  final MediaItemRepository? mediaRepository;
  final OcrRepository? ocrRepository;
  final OcrQueue? ocrQueue;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ScreenshotPicker _screenshotPicker;
  late final MediaItemRepository _mediaRepository;
  late final OcrRepository _ocrRepository;
  late final OcrQueue _ocrQueue;
  late final bool _ownsMediaRepository;
  ContextoDatabase? _ownedAuxiliaryDatabase;
  StreamSubscription<int>? _queueSubscription;
  final List<MediaItem> _mediaItems = [];
  final Map<int, OcrItemState> _ocrStates = {};
  bool _isLoading = true;
  String? _errorMessage;
  String? _duplicateMessage;

  @override
  void initState() {
    super.initState();
    _screenshotPicker =
        widget.screenshotPicker ?? ImagePickerScreenshotPicker();
    _ownsMediaRepository = widget.mediaRepository == null;
    final database =
        widget.mediaRepository == null ||
            widget.ocrRepository == null ||
            widget.ocrQueue == null
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
    if (!_ownsMediaRepository) {
      _ownedAuxiliaryDatabase = database;
    }
    _queueSubscription = _ocrQueue.changes.listen(_refreshOcrState);
    _initialize();
  }

  @override
  void dispose() {
    unawaited(_disposeResources());
    super.dispose();
  }

  Future<void> _disposeResources() async {
    await _queueSubscription?.cancel();
    await _ocrQueue.close();
    if (_ownsMediaRepository) {
      await _mediaRepository.close();
    } else if (_ownedAuxiliaryDatabase != null) {
      await _ownedAuxiliaryDatabase!.close();
    }
  }

  Future<void> _initialize() async {
    try {
      await _reloadItems();
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

  Future<void> _refreshOcrState(int mediaItemId) async {
    try {
      final state = await _ocrQueue.loadState(mediaItemId);
      if (mounted) {
        setState(() {
          _ocrStates[mediaItemId] = state;
        });
      }
    } catch (_) {
      // Uma falha de leitura do estado não bloqueia a biblioteca.
    }
  }

  Future<void> _reloadItemsIgnoringErrors() async {
    try {
      await _reloadItems();
    } catch (_) {
      // A mensagem genérica da operação original continua sendo exibida.
    }
  }

  Future<void> _openDetails(MediaItem item) async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ScreenshotDetailPage(
          mediaItem: item,
          mediaRepository: _mediaRepository,
          ocrRepository: _ocrRepository,
          ocrQueue: _ocrQueue,
        ),
      ),
    );
    if (removed == true) {
      await _reloadItemsIgnoringErrors();
    } else {
      await _refreshOcrState(item.id);
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
                  const _SearchField(),
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
                          icon: Icons.folder_outlined,
                          title: 'Categorias',
                          count: '0 categorias',
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
                  if (_mediaItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _LibraryGrid(
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
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return const TextField(
      enabled: false,
      decoration: InputDecoration(
        hintText: 'Pesquisar screenshots',
        prefixIcon: Icon(Icons.search, size: 20),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        isDense: true,
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
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final String count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
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

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({
    required this.mediaItems,
    required this.ocrStates,
    required this.onItemTap,
  });

  final List<MediaItem> mediaItems;
  final Map<int, OcrItemState> ocrStates;
  final ValueChanged<MediaItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: colors.secondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Salvo neste dispositivo.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          key: const Key('persisted-screenshot-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: mediaItems.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            final item = mediaItems[index];
            return Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('screenshot-tile-${item.id}'),
                onTap: () => onItemTap(item),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(item.privatePath),
                            key: ValueKey(item.id),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                ColoredBox(
                                  color: colors.surfaceContainerLow,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colors.surface.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.open_in_full,
                                size: 14,
                                color: colors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _OcrStatusLabel(
                      state: ocrStates[item.id] ?? OcrItemState.notScheduled,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _OcrStatusLabel extends StatelessWidget {
  const _OcrStatusLabel({required this.state});

  final OcrItemState state;

  @override
  Widget build(BuildContext context) {
    if (state == OcrItemState.notScheduled) {
      return const SizedBox(height: 24);
    }
    final colors = Theme.of(context).colorScheme;
    final (label, icon) = switch (state) {
      OcrItemState.pending => ('Aguardando', Icons.schedule_outlined),
      OcrItemState.processing => ('Processando', null),
      OcrItemState.completedWithText => (
        'Texto extraído',
        Icons.check_circle_outline,
      ),
      OcrItemState.completedWithoutText => (
        'Sem texto',
        Icons.check_circle_outline,
      ),
      OcrItemState.failed => ('Falha', Icons.error_outline),
      OcrItemState.notScheduled => ('', null),
    };
    return SizedBox(
      height: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state == OcrItemState.processing)
              const SizedBox.square(
                dimension: 11,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            else
              Icon(icon, size: 13, color: colors.secondary),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: state == OcrItemState.failed
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/database/contexto_database.dart' show ContextoDatabase;
import '../../../core/media/image_picker_screenshot_picker.dart';
import '../../../core/media/screenshot_picker.dart';
import '../../../core/media/screenshot_storage.dart';
import '../../library/data/media_item_repository.dart';
import '../../library/data/media_item_store.dart';
import '../../library/domain/media_item.dart';
import '../../library/domain/selected_screenshot.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.screenshotPicker, this.mediaRepository});

  final ScreenshotPicker? screenshotPicker;
  final MediaItemRepository? mediaRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ScreenshotPicker _screenshotPicker;
  late final MediaItemRepository _mediaRepository;
  late final bool _ownsMediaRepository;
  final List<MediaItem> _mediaItems = [];
  final Set<String> _sessionSourcePaths = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _screenshotPicker =
        widget.screenshotPicker ?? ImagePickerScreenshotPicker();
    _ownsMediaRepository = widget.mediaRepository == null;
    _mediaRepository =
        widget.mediaRepository ??
        LocalMediaItemRepository(
          store: DriftMediaItemStore(ContextoDatabase()),
          storage: PrivateScreenshotStorage(),
        );
    _initialize();
  }

  @override
  void dispose() {
    if (_ownsMediaRepository) {
      unawaited(_mediaRepository.close());
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _reloadItems();
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

    final pendingPaths = <String>{};
    final newItems = selected.where(
      (item) =>
          !_sessionSourcePaths.contains(item.path) &&
          pendingPaths.add(item.path),
    );
    final itemsToImport = newItems.toList(growable: false);
    if (itemsToImport.isEmpty) {
      return;
    }

    final imported = await _mediaRepository.importScreenshots(itemsToImport);
    _sessionSourcePaths.addAll(itemsToImport.map((item) => item.path));
    if (!mounted) {
      return;
    }
    setState(() {
      _mediaItems.insertAll(0, imported.reversed);
    });
  }

  Future<void> _reloadItems() async {
    final items = await _mediaRepository.loadAvailableItems();
    if (mounted) {
      setState(() {
        _mediaItems
          ..clear()
          ..addAll(items);
      });
    }
  }

  Future<void> _reloadItemsIgnoringErrors() async {
    try {
      await _reloadItems();
    } catch (_) {
      // A mensagem genérica da operação original continua sendo exibida.
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
                    onPressed: _isLoading ? null : _pickScreenshots,
                  ),
                  if (_mediaItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _LibraryGrid(mediaItems: _mediaItems),
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
    required this.onPressed,
  });

  final bool isLoading;
  final String? errorMessage;
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
          ],
        ),
      ),
    );
  }
}

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({required this.mediaItems});

  final List<MediaItem> mediaItems;

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
          ),
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.file(
                  File(mediaItems[index].privatePath),
                  key: ValueKey(mediaItems[index].id),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: colors.surfaceContainerLow,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
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

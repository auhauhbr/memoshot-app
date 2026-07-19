import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/automatic_import/automatic_screenshot_source.dart';
import '../application/existing_screenshot_inventory_coordinator.dart';
import '../application/historical_archive_preparation_coordinator.dart';
import '../domain/existing_screenshot_candidate.dart';
import '../domain/existing_screenshot_scan.dart';
import '../domain/historical_media_import_job.dart';

class ExistingScreenshotInventoryPage extends StatefulWidget {
  const ExistingScreenshotInventoryPage({
    super.key,
    required this.coordinator,
    this.preparationCoordinator,
  });

  final ExistingScreenshotInventoryCoordinator coordinator;
  final HistoricalArchivePreparationCoordinator? preparationCoordinator;

  @override
  State<ExistingScreenshotInventoryPage> createState() =>
      _ExistingScreenshotInventoryPageState();
}

class _ExistingScreenshotInventoryPageState
    extends State<ExistingScreenshotInventoryPage>
    with WidgetsBindingObserver {
  ExistingScreenshotInventorySummary _summary =
      const ExistingScreenshotInventorySummary.empty();
  MediaPermissionStatus _permission = MediaPermissionStatus.unsupported;
  ExistingScreenshotScanProgress _progress =
      const ExistingScreenshotScanProgress(
        examinedCount: 0,
        recognizedCount: 0,
      );
  bool _loading = true;
  bool _mapping = false;
  bool _permissionChanging = false;
  String? _error;
  int _generation = 0;
  HistoricalPreparationProgress? _preparationProgress;
  StreamSubscription<void>? _preparationSubscription;
  bool _changingPreparation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preparationSubscription = widget.preparationCoordinator?.changes.listen(
      (_) => unawaited(_refreshProgress()),
    );
    unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_mapping) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    unawaited(_preparationSubscription?.cancel());
    unawaited(widget.coordinator.cancel());
    super.dispose();
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    if (mounted) setState(() => _loading = true);
    try {
      final preparationCoordinator = widget.preparationCoordinator;
      final results = await Future.wait<Object>([
        widget.coordinator.loadSummary(),
        widget.coordinator.permissionStatus(),
        if (preparationCoordinator != null)
          preparationCoordinator.loadProgress(),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _summary = results[0] as ExistingScreenshotInventorySummary;
        _permission = results[1] as MediaPermissionStatus;
        if (results.length > 2) {
          _preparationProgress = results[2] as HistoricalPreparationProgress;
        }
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar o inventário.';
      });
    }
  }

  Future<void> _refreshProgress() async {
    final coordinator = widget.preparationCoordinator;
    if (coordinator == null) return;
    try {
      final progress = await coordinator.loadProgress();
      if (mounted) setState(() => _preparationProgress = progress);
    } catch (_) {
      // O inventário continua utilizável se a contagem falhar.
    }
  }

  Future<void> _startPreparation() async {
    final coordinator = widget.preparationCoordinator;
    final progress = _preparationProgress;
    if (coordinator == null || progress == null || _changingPreparation) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preparar acervo para organização?'),
        content: Text(
          '${progress.availableCount} disponíveis\n'
          '${progress.preparedCount} já preparados\n'
          '${progress.remainingCount} restantes\n'
          '${progress.unavailableCount} indisponíveis\n\n'
          '${_summary.lastScanWasPartial ? 'O acesso às imagens é parcial.\n\n' : ''}'
          'O MemoShot adicionará referências aos screenshots na biblioteca. '
          'Nenhuma imagem será copiada ou movida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-prepare-archive'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Preparar acervo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _changePreparation(coordinator.start);
  }

  Future<void> _pausePreparation() async {
    final coordinator = widget.preparationCoordinator;
    if (coordinator != null) await _changePreparation(coordinator.pause);
  }

  Future<void> _resumePreparation() async {
    final coordinator = widget.preparationCoordinator;
    if (coordinator != null) await _changePreparation(coordinator.resume);
  }

  Future<void> _changePreparation(Future<void> Function() action) async {
    if (_changingPreparation) return;
    setState(() => _changingPreparation = true);
    try {
      await action();
      await _refreshProgress();
    } catch (_) {
      _showMessage('Não foi possível atualizar a preparação do acervo.');
    } finally {
      if (mounted) setState(() => _changingPreparation = false);
    }
  }

  Future<void> _map() async {
    if (_mapping || !_canMap) return;
    final generation = ++_generation;
    setState(() {
      _mapping = true;
      _error = null;
      _progress = const ExistingScreenshotScanProgress(
        examinedCount: 0,
        recognizedCount: 0,
      );
    });
    try {
      final result = await widget.coordinator.scan(
        onProgress: (progress) {
          if (mounted && generation == _generation) {
            setState(() => _progress = progress);
          }
        },
      );
      if (!mounted || generation != _generation) return;
      if (result.outcome == ExistingScreenshotScanOutcome.accessUnavailable) {
        setState(() => _error = 'O acesso às imagens não está disponível.');
      }
      await _refreshAfterOperation(generation);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _mapping = false;
        _error = 'Não foi possível mapear seus screenshots.';
      });
    }
  }

  Future<void> _cancel() async {
    if (!_mapping) return;
    final generation = ++_generation;
    setState(() => _mapping = false);
    await widget.coordinator.cancel();
    if (!mounted || generation != _generation) return;
    await _refreshAfterOperation(generation);
  }

  Future<void> _refreshAfterOperation(int generation) async {
    try {
      final summary = await widget.coordinator.loadSummary();
      if (!mounted || generation != _generation) return;
      setState(() {
        _summary = summary;
        _mapping = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _mapping = false);
      }
    }
  }

  Future<void> _permissionAction() async {
    if (_permissionChanging || _mapping) return;
    if (_permission == MediaPermissionStatus.permanentlyDenied) {
      try {
        await widget.coordinator.openAppSettings();
      } catch (_) {
        _showMessage('Não foi possível abrir as configurações do Android.');
      }
      return;
    }
    if (_permission == MediaPermissionStatus.unsupported) {
      await _refresh();
      return;
    }
    final generation = ++_generation;
    setState(() => _permissionChanging = true);
    try {
      final permission = await widget.coordinator.requestPermission();
      if (!mounted || generation != _generation) return;
      setState(() => _permission = permission);
    } catch (_) {
      if (mounted && generation == _generation) {
        _showMessage('Não foi possível atualizar o acesso às imagens.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _permissionChanging = false);
      }
    }
  }

  Future<void> _clearInventory() async {
    final preparation = widget.preparationCoordinator;
    if (preparation != null && !await preparation.canClearInventory()) {
      if (!mounted) return;
      _showMessage(
        'A preparação possui itens em andamento. Conclua a preparação antes de limpar o inventário.',
      );
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar inventário?'),
        content: const Text(
          'Isso remove somente o inventário de screenshots encontrados. '
          'Nenhuma imagem será excluída.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('confirm-clear-inventory'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Limpar inventário'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.coordinator.clearInventory();
      await _refresh();
    } catch (_) {
      _showMessage('Não foi possível limpar o inventário.');
    }
  }

  bool get _canMap =>
      _permission == MediaPermissionStatus.fullAccess ||
      _permission == MediaPermissionStatus.limitedAccess;

  String? get _permissionActionLabel => switch (_permission) {
    MediaPermissionStatus.notRequested ||
    MediaPermissionStatus.denied => 'Conceder acesso',
    MediaPermissionStatus.limitedAccess => 'Revisar acesso',
    MediaPermissionStatus.permanentlyDenied => 'Abrir configurações do Android',
    MediaPermissionStatus.unsupported => 'Tentar novamente',
    MediaPermissionStatus.fullAccess => null,
  };

  void _showMessage(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final hasInventory =
        _summary.hasCompletedScan ||
        _summary.availableCount > 0 ||
        _summary.unavailableCount > 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acervo existente'),
        actions: [
          if (hasInventory && !_mapping)
            PopupMenuButton<String>(
              key: const Key('inventory-menu'),
              tooltip: 'Mais opções',
              onSelected: (value) {
                if (value == 'clear') unawaited(_clearInventory());
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'clear', child: Text('Limpar inventário')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            if (_loading)
              const Center(
                child: CircularProgressIndicator(
                  key: Key('inventory-initial-loading'),
                ),
              )
            else if (_mapping)
              _MappingState(progress: _progress, onCancel: _cancel)
            else if (_error != null)
              _ErrorState(message: _error!, onRetry: _canMap ? _map : _refresh)
            else ...[
              if (_permission == MediaPermissionStatus.limitedAccess)
                _PermissionNotice(
                  message:
                      'O acesso é parcial. O inventário incluirá apenas as imagens permitidas.',
                  actionLabel: 'Revisar acesso',
                  onAction: _permissionChanging ? null : _permissionAction,
                )
              else if (!_canMap)
                _PermissionNotice(
                  message: _permission == MediaPermissionStatus.unsupported
                      ? 'Não foi possível verificar o acesso às imagens.'
                      : 'O acesso às imagens é necessário para localizar seus screenshots.',
                  actionLabel: _permissionActionLabel!,
                  onAction: _permissionChanging ? null : _permissionAction,
                ),
              if (!_canMap ||
                  _permission == MediaPermissionStatus.limitedAccess)
                const SizedBox(height: 16),
              if (_summary.hasCompletedScan)
                _CompletedState(
                  summary: _summary,
                  preparation: _preparationProgress,
                  changingPreparation: _changingPreparation,
                  onPrepare: widget.preparationCoordinator == null
                      ? null
                      : _startPreparation,
                  onPause: _pausePreparation,
                  onResume: _resumePreparation,
                  onUpdate: _map,
                )
              else
                _NeverMappedState(
                  discoveredCount: _summary.availableCount,
                  canMap: _canMap,
                  onMap: _map,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NeverMappedState extends StatelessWidget {
  const _NeverMappedState({
    required this.discoveredCount,
    required this.canMap,
    required this.onMap,
  });

  final int discoveredCount;
  final bool canMap;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Organize os prints que já estão no celular',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'O MemoShot analisará somente os metadados necessários para localizar '
          'seus screenshots. Nenhuma imagem será copiada ou movida nesta etapa.',
        ),
        if (discoveredCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            '$discoveredCount ${discoveredCount == 1 ? 'screenshot localizado' : 'screenshots localizados'} em um mapeamento interrompido.',
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('start-inventory-scan'),
          onPressed: canMap ? onMap : null,
          child: const Text('Mapear meus screenshots'),
        ),
      ],
    );
  }
}

class _MappingState extends StatelessWidget {
  const _MappingState({required this.progress, required this.onCancel});

  final ExistingScreenshotScanProgress progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LinearProgressIndicator(key: Key('inventory-scan-progress')),
        const SizedBox(height: 20),
        Text(
          'Mapeando seus screenshots…',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text('${progress.examinedCount} imagens examinadas'),
        const SizedBox(height: 6),
        Text('${progress.recognizedCount} screenshots encontrados'),
        const SizedBox(height: 24),
        OutlinedButton(
          key: const Key('cancel-inventory-scan'),
          onPressed: onCancel,
          child: const Text('Cancelar mapeamento'),
        ),
      ],
    );
  }
}

class _CompletedState extends StatelessWidget {
  const _CompletedState({
    required this.summary,
    required this.preparation,
    required this.changingPreparation,
    required this.onPrepare,
    required this.onPause,
    required this.onResume,
    required this.onUpdate,
  });

  final ExistingScreenshotInventorySummary summary;
  final HistoricalPreparationProgress? preparation;
  final bool changingPreparation;
  final VoidCallback? onPrepare;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final count = summary.availableCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          count == 1
              ? 'Encontramos 1 screenshot'
              : 'Encontramos $count screenshots',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text('$count disponíveis'),
        if (summary.lastCompletedScanAt case final date?) ...[
          const SizedBox(height: 6),
          Text('Última varredura: ${_formatDate(date)}'),
        ],
        if (summary.lastScanWasPartial) ...[
          const SizedBox(height: 12),
          const Text(
            'O acesso era parcial. O inventário inclui apenas as imagens permitidas.',
          ),
        ],
        const SizedBox(height: 12),
        const Text('Nenhuma imagem foi copiada ou movida.'),
        if (preparation case final progress?) ...[
          const SizedBox(height: 20),
          Text(
            '${progress.preparedCount} de ${progress.availableCount} preparados',
            key: const Key('archive-preparation-progress'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text('${progress.waitingCount} aguardando'),
          if (progress.processingCount > 0)
            Text('${progress.processingCount} em processamento'),
          if (progress.unavailableCount > 0)
            Text('${progress.unavailableCount} não disponíveis'),
          if (progress.failedCount > 0)
            Text('${progress.failedCount} com falha'),
          const SizedBox(height: 12),
          if (progress.state == HistoricalPreparationState.completed ||
              progress.remainingCount == 0)
            const Text('Acervo preparado para organização.')
          else if (progress.state == HistoricalPreparationState.active)
            OutlinedButton(
              key: const Key('pause-archive-preparation'),
              onPressed: changingPreparation ? null : onPause,
              child: const Text('Pausar preparação'),
            )
          else if (progress.state == HistoricalPreparationState.paused)
            FilledButton(
              key: const Key('resume-archive-preparation'),
              onPressed: changingPreparation ? null : onResume,
              child: const Text('Continuar preparação'),
            )
          else if (progress.remainingCount > 0 && onPrepare != null) ...[
            const Text(
              'Adicione os screenshots encontrados à biblioteca sem copiar as imagens.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('prepare-existing-archive'),
              onPressed: changingPreparation ? null : onPrepare,
              child: const Text('Preparar acervo para organização'),
            ),
          ],
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('update-inventory'),
          onPressed: onUpdate,
          child: const Text('Atualizar inventário'),
        ),
      ],
    );
  }

  static String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
      ],
    );
  }
}

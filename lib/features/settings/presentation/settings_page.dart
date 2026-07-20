import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/automatic_import/automatic_screenshot_source.dart';
import '../../automatic_import/automatic_screenshot_import_coordinator.dart';
import '../../automatic_import/data/automatic_import_settings_repository.dart';
import '../../existing_screenshots/application/existing_screenshot_inventory_coordinator.dart';
import '../../existing_screenshots/application/historical_archive_preparation_coordinator.dart';
import '../../existing_screenshots/presentation/existing_screenshot_inventory_page.dart';

enum UsageContextStatus { enabled, disabled, accessRequired, unavailable }

abstract interface class UsageContextSettings {
  Future<UsageContextStatus> status();

  Future<UsageContextStatus> setEnabled(bool enabled);

  Future<void> openAccessSettings();
}

class MethodChannelUsageContextSettings implements UsageContextSettings {
  const MethodChannelUsageContextSettings();

  static const _channel = MethodChannel(
    'br.com.jeffersont.memoshot/preferences',
  );

  @override
  Future<UsageContextStatus> status() async =>
      _decode(await _channel.invokeMethod<String>('usageContextStatus'));

  @override
  Future<UsageContextStatus> setEnabled(bool enabled) async => _decode(
    await _channel.invokeMethod<String>('setUsageContextEnabled', {
      'enabled': enabled,
    }),
  );

  @override
  Future<void> openAccessSettings() =>
      _channel.invokeMethod<void>('openUsageAccessSettings');

  UsageContextStatus _decode(String? value) =>
      UsageContextStatus.values
          .where((status) => status.name == value)
          .firstOrNull ??
      UsageContextStatus.unavailable;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.coordinator,
    required this.settingsRepository,
    required this.existingScreenshotInventoryCoordinator,
    this.historicalArchivePreparationCoordinator,
    this.usageContextSettings = const MethodChannelUsageContextSettings(),
  });

  final AutomaticScreenshotImportCoordinator coordinator;
  final AutomaticImportSettingsRepository settingsRepository;
  final ExistingScreenshotInventoryCoordinator
  existingScreenshotInventoryCoordinator;
  final HistoricalArchivePreparationCoordinator?
  historicalArchivePreparationCoordinator;
  final UsageContextSettings usageContextSettings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  bool _enabled = false;
  bool _isLoading = true;
  bool _isChanging = false;
  bool _isRefreshing = false;
  MediaPermissionStatus _permission = MediaPermissionStatus.unsupported;
  int _generation = 0;
  UsageContextStatus _usageContextStatus = UsageContextStatus.disabled;
  bool _isChangingUsageContext = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isChanging) unawaited(_refresh(reconcile: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    super.dispose();
  }

  Future<void> _refresh({bool reconcile = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    final generation = ++_generation;
    if (mounted) setState(() => _isLoading = true);
    try {
      if (reconcile) await widget.coordinator.resume();
      final settings = await widget.settingsRepository.load();
      final permission = await widget.coordinator.permissionStatus();
      UsageContextStatus usageContextStatus;
      try {
        usageContextStatus = await widget.usageContextSettings.status().timeout(
          const Duration(milliseconds: 500),
        );
      } catch (_) {
        usageContextStatus = UsageContextStatus.unavailable;
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _enabled = settings.enabled;
        _permission = permission;
        _usageContextStatus = usageContextStatus;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _isLoading = false);
      _showMessage('Não foi possível atualizar a configuração.');
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _toggleUsageContext(bool value) async {
    if (_isChangingUsageContext) return;
    if (value) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Identificar aplicativo da captura'),
          content: const Text(
            'O Android permite consultar qual aplicativo estava em uso perto do momento do print. '
            'O MemoShot consulta apenas uma janela curta por nova captura e não armazena o histórico completo.',
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
      if (accepted != true || !mounted) return;
    }
    setState(() => _isChangingUsageContext = true);
    try {
      final status = await widget.usageContextSettings.setEnabled(value);
      if (!mounted) return;
      setState(() => _usageContextStatus = status);
      if (value && status == UsageContextStatus.accessRequired) {
        await widget.usageContextSettings.openAccessSettings();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _usageContextStatus = UsageContextStatus.unavailable);
        _showMessage('Não foi possível abrir o acesso de uso.');
      }
    } finally {
      if (mounted) setState(() => _isChangingUsageContext = false);
    }
  }

  Future<void> _toggle(bool value) async {
    if (_isChanging) return;
    final previous = _enabled;
    final generation = ++_generation;
    setState(() {
      _enabled = value;
      _isChanging = true;
    });
    try {
      if (value) {
        final permission = await widget.coordinator.enable();
        if (permission != MediaPermissionStatus.fullAccess) {
          _showPermissionMessage(permission);
        }
      } else {
        final fullyReconciled = await widget.coordinator.disable();
        if (!fullyReconciled) {
          _showMessage('Não foi possível atualizar a configuração.');
        }
      }
      final settings = await widget.settingsRepository.load();
      final permission = await widget.coordinator.permissionStatus();
      if (!mounted || generation != _generation) return;
      setState(() {
        _enabled = settings.enabled;
        _permission = permission;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _enabled = previous);
      _showMessage(
        value
            ? 'Não foi possível ativar a organização automática.'
            : 'Não foi possível atualizar a configuração.',
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isChanging = false);
      }
    }
  }

  Future<void> _handlePermissionAction() async {
    if (_isChanging) return;
    if (_permission == MediaPermissionStatus.permanentlyDenied) {
      await widget.coordinator.openAppSettings();
      return;
    }
    if (_permission == MediaPermissionStatus.unsupported) {
      await _refresh(reconcile: true);
      return;
    }
    final generation = ++_generation;
    setState(() => _isChanging = true);
    try {
      final permission = await widget.coordinator
          .requestPermissionAndApplyDefault();
      if (permission != MediaPermissionStatus.fullAccess) {
        _showPermissionMessage(permission);
      }
      final settings = await widget.settingsRepository.load();
      if (!mounted || generation != _generation) return;
      setState(() {
        _enabled = settings.enabled;
        _permission = permission;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        _showMessage('Não foi possível atualizar a configuração.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isChanging = false);
      }
    }
  }

  void _showPermissionMessage(MediaPermissionStatus permission) {
    _showMessage(
      permission == MediaPermissionStatus.permanentlyDenied
          ? 'Abra as configurações do Android para conceder o acesso.'
          : 'Permita o acesso às imagens para ativar esta função.',
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String get _permissionLabel => switch (_permission) {
    MediaPermissionStatus.fullAccess => 'Acesso permitido',
    MediaPermissionStatus.limitedAccess => 'Acesso parcial',
    MediaPermissionStatus.unsupported => 'Indisponível neste dispositivo',
    _ => 'Acesso não permitido',
  };

  String? get _permissionAction => switch (_permission) {
    MediaPermissionStatus.notRequested ||
    MediaPermissionStatus.denied => 'Conceder acesso',
    MediaPermissionStatus.limitedAccess => 'Revisar acesso',
    MediaPermissionStatus.permanentlyDenied => 'Abrir configurações do Android',
    MediaPermissionStatus.unsupported => 'Tentar novamente',
    MediaPermissionStatus.fullAccess => null,
  };

  String get _usageContextLabel => switch (_usageContextStatus) {
    UsageContextStatus.enabled => 'Ativado',
    UsageContextStatus.disabled => 'Desativado',
    UsageContextStatus.accessRequired => 'Acesso necessário',
    UsageContextStatus.unavailable => 'Indisponível',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (_isLoading || _isChanging)
              const LinearProgressIndicator(key: Key('settings-progress')),
            const _SectionTitle('Captura e organização'),
            Card(
              child: Column(
                children: [
                  Semantics(
                    label:
                        'Captura e organização automática. Detecta novos screenshots e adiciona-os ao MemoShot.',
                    child: SwitchListTile(
                      key: const Key('automatic-import-switch'),
                      title: const Text('Captura e organização automática'),
                      subtitle: const Text(
                        'Detecta novos screenshots e adiciona-os ao MemoShot.',
                      ),
                      value: _enabled,
                      onChanged: _isLoading || _isChanging ? null : _toggle,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('Permissão de imagens'),
                    subtitle: Text(_permissionLabel),
                  ),
                  if (_permissionAction != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          key: const Key('permission-action'),
                          onPressed: _isLoading || _isChanging
                              ? null
                              : _handlePermissionAction,
                          child: Text(_permissionAction!),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const _SectionTitle('Reconhecimento de origem'),
            Card(
              child: SwitchListTile(
                key: const Key('usage-context-switch'),
                secondary: const Icon(Icons.apps_outlined),
                title: const Text('Identificar o aplicativo usado na captura'),
                subtitle: Text(
                  'Ajuda o MemoShot a distinguir prints do WhatsApp, Instagram, lojas e navegadores. '
                  'O histórico completo de uso não é armazenado.\n$_usageContextLabel',
                ),
                value:
                    _usageContextStatus == UsageContextStatus.enabled ||
                    _usageContextStatus == UsageContextStatus.accessRequired,
                onChanged:
                    _isLoading ||
                        _isChanging ||
                        _isChangingUsageContext ||
                        _usageContextStatus == UsageContextStatus.unavailable
                    ? null
                    : _toggleUsageContext,
              ),
            ),
            const _SectionTitle('Acervo existente'),
            Card(
              child: ListTile(
                key: const Key('open-existing-screenshot-inventory'),
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Organizar screenshots antigos'),
                subtitle: const Text(
                  'Localize os prints que já estão no dispositivo e prepare-os para organização.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isLoading || _isChanging
                    ? null
                    : () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => ExistingScreenshotInventoryPage(
                            coordinator:
                                widget.existingScreenshotInventoryCoordinator,
                            preparationCoordinator:
                                widget.historicalArchivePreparationCoordinator,
                          ),
                        ),
                      ),
              ),
            ),
            const _SectionTitle('Privacidade'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'O reconhecimento de texto e a organização são processados localmente. '
                  'Os arquivos são gerenciados no dispositivo e, nesta versão, screenshots e OCR não são enviados para servidores.',
                ),
              ),
            ),
            const _SectionTitle('Sobre o MemoShot'),
            const Card(
              child: ListTile(
                leading: Icon(Icons.auto_awesome_outlined),
                title: Text('MemoShot'),
                subtitle: Text('Capturou, organizou.'),
              ),
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

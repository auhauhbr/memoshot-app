import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/automatic_import/automatic_screenshot_source.dart';
import '../../automatic_import/automatic_screenshot_import_coordinator.dart';
import '../../automatic_import/data/automatic_import_settings_repository.dart';
import '../../existing_screenshots/application/existing_screenshot_inventory_coordinator.dart';
import '../../existing_screenshots/presentation/existing_screenshot_inventory_page.dart';
import '../../review_notifications/application/review_notification_coordinator.dart';
import '../../review_notifications/domain/review_notification.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.coordinator,
    required this.settingsRepository,
    required this.reviewNotificationCoordinator,
    required this.existingScreenshotInventoryCoordinator,
  });

  final AutomaticScreenshotImportCoordinator coordinator;
  final AutomaticImportSettingsRepository settingsRepository;
  final ReviewNotificationCoordinator reviewNotificationCoordinator;
  final ExistingScreenshotInventoryCoordinator
  existingScreenshotInventoryCoordinator;

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
  ReviewNotificationState _reviewNotificationState =
      const ReviewNotificationState.disabled();
  int _generation = 0;

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
      final reviewNotificationState = await widget.reviewNotificationCoordinator
          .loadState();
      if (!mounted || generation != _generation) return;
      setState(() {
        _enabled = settings.enabled;
        _permission = permission;
        _reviewNotificationState = reviewNotificationState;
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

  Future<void> _toggleReviewNotifications(bool value) async {
    if (_isChanging) return;
    final generation = ++_generation;
    setState(() => _isChanging = true);
    try {
      if (value) {
        final state = await widget.reviewNotificationCoordinator.enable();
        if (!mounted || generation != _generation) return;
        setState(() => _reviewNotificationState = state);
        if (!state.enabled) {
          _showMessage(
            state.permission == ReviewNotificationPermission.blocked
                ? 'As notificações estão bloqueadas nas configurações do Android.'
                : 'Permissão não concedida.',
          );
        }
      } else {
        await widget.reviewNotificationCoordinator.disable();
        final state = await widget.reviewNotificationCoordinator.loadState();
        if (!mounted || generation != _generation) return;
        setState(() => _reviewNotificationState = state);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        _showMessage('Não foi possível atualizar as notificações.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isChanging = false);
      }
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      await widget.reviewNotificationCoordinator.openAndroidSettings();
    } catch (_) {
      _showMessage('Não foi possível abrir as configurações do Android.');
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

  String get _reviewNotificationLabel {
    final permissionLabel = switch (_reviewNotificationState.permission) {
      ReviewNotificationPermission.blocked =>
        'Bloqueadas nas configurações do Android',
      ReviewNotificationPermission.denied
          when _reviewNotificationState.promptHandled =>
        'Permissão não concedida',
      _ => null,
    };
    if (permissionLabel != null) return permissionLabel;
    return _reviewNotificationState.enabled ? 'Ativadas' : 'Desativadas';
  }

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
                          ),
                        ),
                      ),
              ),
            ),
            const _SectionTitle('Notificações'),
            Card(
              child: Column(
                children: [
                  Semantics(
                    label:
                        'Notificações de revisão. Avise quando um print precisar da sua confirmação.',
                    child: SwitchListTile(
                      key: const Key('review-notifications-switch'),
                      title: const Text('Notificações de revisão'),
                      subtitle: const Text(
                        'Avise quando um print precisar da sua confirmação.',
                      ),
                      value: _reviewNotificationState.enabled,
                      onChanged: _isLoading || _isChanging
                          ? null
                          : _toggleReviewNotifications,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Estado'),
                    subtitle: Text(_reviewNotificationLabel),
                  ),
                  if (_reviewNotificationState.permission ==
                      ReviewNotificationPermission.blocked)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          key: const Key('open-notification-settings'),
                          onPressed: _isLoading || _isChanging
                              ? null
                              : _openNotificationSettings,
                          child: const Text('Abrir configurações do Android'),
                        ),
                      ),
                    ),
                ],
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

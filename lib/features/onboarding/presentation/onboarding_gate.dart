import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/automatic_import/automatic_screenshot_source.dart';
import '../data/onboarding_repository.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.repository,
    required this.automaticScreenshotSource,
    required this.child,
  });

  final OnboardingRepository repository;
  final AutomaticScreenshotSource automaticScreenshotSource;
  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _completed;
  bool _isFinishing = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    final cachedCompletion = widget.repository.cachedCompletion;
    if (cachedCompletion == null) {
      unawaited(_load());
    } else {
      _completed = cachedCompletion;
    }
  }

  Future<void> _load() async {
    var completed = false;
    try {
      completed = await widget.repository.isCompleted();
    } catch (_) {
      // Uma falha de leitura não impede a apresentação inicial.
    }
    if (mounted) setState(() => _completed = completed);
  }

  Future<void> _finish({required bool requestPermission}) async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    if (requestPermission) {
      try {
        await widget.automaticScreenshotSource.requestPermission();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível solicitar o acesso agora.'),
            ),
          );
        }
      }
    }
    try {
      await widget.repository.complete();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar esta escolha.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _completed = true;
          _isFinishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_completed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_completed!) return widget.child;
    return _OnboardingPage(
      step: _step,
      isFinishing: _isFinishing,
      onNext: () => setState(() => _step++),
      onAllow: () => unawaited(_finish(requestPermission: true)),
      onNotNow: () => unawaited(_finish(requestPermission: false)),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.step,
    required this.isFinishing,
    required this.onNext,
    required this.onAllow,
    required this.onNotNow,
  });

  final int step;
  final bool isFinishing;
  final VoidCallback onNext;
  final VoidCallback onAllow;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Capturou, organizou.',
      'Tudo no seu dispositivo',
      'Permita o acesso aos seus prints',
    ];
    const descriptions = [
      'O MemoShot ajuda a encontrar e organizar seus prints automaticamente.',
      'O reconhecimento de texto e a organização são processados localmente.',
      'O acesso é necessário para detectar novas capturas e adicioná-las à sua biblioteca.',
    ];
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    step == 0
                        ? Icons.auto_awesome_outlined
                        : step == 1
                        ? Icons.phone_android_outlined
                        : Icons.photo_library_outlined,
                    size: 72,
                    color: colors.primary,
                    semanticLabel: 'MemoShot',
                  ),
                  const SizedBox(height: 36),
                  Text(
                    titles[step],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    descriptions[step],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 44),
                  Semantics(
                    label: 'Etapa ${step + 1} de 3',
                    child: LinearProgressIndicator(value: (step + 1) / 3),
                  ),
                  const SizedBox(height: 28),
                  if (step < 2)
                    FilledButton(
                      key: const Key('onboarding-next'),
                      onPressed: onNext,
                      child: const Text('Continuar'),
                    )
                  else ...[
                    FilledButton.icon(
                      key: const Key('onboarding-allow'),
                      onPressed: isFinishing ? null : onAllow,
                      icon: isFinishing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Permitir acesso'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('onboarding-not-now'),
                      onPressed: isFinishing ? null : onNotNow,
                      child: const Text('Agora não'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

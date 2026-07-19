import 'package:flutter/services.dart';

import '../text/text_normalizer.dart';

const localVisualAnalyzerChannelName =
    'br.com.jeffersont.memoshot/local_visual_analyzer';
const localVisualAnalyzerVersion = 'mlkit-image-labeling-17.0.9';

final class VisualLabel {
  VisualLabel({required String key, required double confidence, this.index})
    : key = const TextNormalizer().normalize(key),
      confidence = confidence.clamp(0, 1).toDouble();

  final String key;
  final double confidence;
  final int? index;
}

final class VisualAnalysisResult {
  VisualAnalysisResult({
    required List<VisualLabel> labels,
    required this.analyzerVersion,
    this.duration,
  }) : labels = List.unmodifiable(labels);

  final List<VisualLabel> labels;
  final String analyzerVersion;
  final Duration? duration;
}

abstract interface class LocalVisualAnalyzer {
  Future<VisualAnalysisResult> analyze(String localPath);

  Future<void> close();
}

class MethodChannelLocalVisualAnalyzer implements LocalVisualAnalyzer {
  MethodChannelLocalVisualAnalyzer([
    this._channel = const MethodChannel(localVisualAnalyzerChannelName),
  ]);

  final MethodChannel _channel;
  bool _closed = false;
  int _generation = 0;

  @override
  Future<VisualAnalysisResult> analyze(String localPath) async {
    if (_closed) throw StateError('Analisador visual encerrado.');
    final generation = _generation;
    final watch = Stopwatch()..start();
    final values = await _channel.invokeListMethod<Object?>('analyze', {
      'localPath': localPath,
    });
    watch.stop();
    if (_closed || generation != _generation) {
      throw StateError('Resultado visual tardio ignorado.');
    }
    final byKey = <String, VisualLabel>{};
    for (final value in values ?? const <Object?>[]) {
      if (value is! Map<Object?, Object?>) continue;
      final rawKey = value['key'];
      final rawConfidence = value['confidence'];
      final rawIndex = value['index'];
      if (rawKey is! String || rawConfidence is! num) continue;
      final label = VisualLabel(
        key: rawKey,
        confidence: rawConfidence.toDouble(),
        index: rawIndex is int ? rawIndex : null,
      );
      if (label.key.isEmpty) continue;
      final previous = byKey[label.key];
      if (previous == null || label.confidence > previous.confidence) {
        byKey[label.key] = label;
      }
    }
    final labels = byKey.values.toList(growable: false)
      ..sort((first, second) {
        final confidence = second.confidence.compareTo(first.confidence);
        return confidence != 0 ? confidence : first.key.compareTo(second.key);
      });
    return VisualAnalysisResult(
      labels: labels,
      analyzerVersion: localVisualAnalyzerVersion,
      duration: watch.elapsed,
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _generation++;
    try {
      await _channel.invokeMethod<void>('close');
    } catch (_) {
      // O encerramento da composição continua mesmo se o canal já terminou.
    }
  }
}

LocalVisualAnalyzer createLocalVisualAnalyzer() =>
    MethodChannelLocalVisualAnalyzer();

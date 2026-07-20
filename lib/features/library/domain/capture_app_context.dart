enum CaptureAppConfidence {
  high('high'),
  medium('medium'),
  low('low');

  const CaptureAppConfidence(this.databaseValue);

  final String databaseValue;

  static CaptureAppConfidence? fromDatabase(String value) {
    return CaptureAppConfidence.values
        .where((confidence) => confidence.databaseValue == value)
        .firstOrNull;
  }
}

enum NormalizedCaptureAppKey {
  whatsapp,
  instagram,
  amazon,
  mercadoLivre,
  mercadoPago,
  linkedin,
  github,
  brave,
  chrome,
  firefox,
  browser;

  static NormalizedCaptureAppKey? fromDatabase(String? value) {
    if (value == null) return null;
    return NormalizedCaptureAppKey.values
        .where((key) => key.name == value)
        .firstOrNull;
  }

  bool get isBrowser => switch (this) {
    brave || chrome || firefox || browser => true,
    _ => false,
  };
}

final class CaptureAppContext {
  const CaptureAppContext({
    required this.packageName,
    required this.normalizedAppKey,
    required this.eventTimestamp,
    required this.captureTimestamp,
    required this.deltaMilliseconds,
    required this.confidenceLevel,
    required this.createdAt,
  });

  final String packageName;
  final NormalizedCaptureAppKey? normalizedAppKey;
  final DateTime eventTimestamp;
  final DateTime captureTimestamp;
  final int deltaMilliseconds;
  final CaptureAppConfidence confidenceLevel;
  final DateTime createdAt;
}

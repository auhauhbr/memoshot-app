class AutomaticImportSettings {
  const AutomaticImportSettings({
    required this.enabled,
    required this.hasStoredPreference,
    required this.updatedAt,
    this.lastMediaId,
    this.enabledAt,
    this.lastScanAt,
  });

  factory AutomaticImportSettings.disabled() => AutomaticImportSettings(
    enabled: false,
    hasStoredPreference: false,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  final bool enabled;
  final bool hasStoredPreference;
  final int? lastMediaId;
  final DateTime? enabledAt;
  final DateTime? lastScanAt;
  final DateTime updatedAt;
}

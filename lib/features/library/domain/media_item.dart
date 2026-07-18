class MediaItem {
  const MediaItem({
    required this.id,
    required this.privatePath,
    required this.internalName,
    required this.importedAt,
    required this.sourceMode,
    required this.status,
    this.importOrigin = ImportOrigin.picker,
    this.mimeType,
    this.mediaHash,
    this.capturedAt,
  });

  final int id;
  final String privatePath;
  final String internalName;
  final String? mimeType;
  final String? mediaHash;
  final DateTime importedAt;
  final DateTime? capturedAt;
  final String sourceMode;
  final String status;
  final ImportOrigin importOrigin;

  DateTime get effectiveCapturedAt => capturedAt ?? importedAt;
}

enum ImportOrigin {
  picker('picker'),
  shared('shared'),
  automatic('automatic');

  const ImportOrigin(this.databaseValue);

  final String databaseValue;

  static ImportOrigin fromDatabase(String value) {
    return ImportOrigin.values.firstWhere(
      (origin) => origin.databaseValue == value,
      orElse: () => ImportOrigin.picker,
    );
  }
}

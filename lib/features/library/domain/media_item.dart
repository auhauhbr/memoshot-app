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
  });

  final int id;
  final String privatePath;
  final String internalName;
  final String? mimeType;
  final String? mediaHash;
  final DateTime importedAt;
  final String sourceMode;
  final String status;
  final ImportOrigin importOrigin;
}

enum ImportOrigin {
  picker('picker'),
  shared('shared');

  const ImportOrigin(this.databaseValue);

  final String databaseValue;

  static ImportOrigin fromDatabase(String value) {
    return ImportOrigin.values.firstWhere(
      (origin) => origin.databaseValue == value,
      orElse: () => ImportOrigin.picker,
    );
  }
}

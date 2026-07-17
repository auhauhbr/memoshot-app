class MediaItem {
  const MediaItem({
    required this.id,
    required this.privatePath,
    required this.internalName,
    required this.importedAt,
    required this.sourceMode,
    required this.status,
    this.mimeType,
  });

  final int id;
  final String privatePath;
  final String internalName;
  final String? mimeType;
  final DateTime importedAt;
  final String sourceMode;
  final String status;
}

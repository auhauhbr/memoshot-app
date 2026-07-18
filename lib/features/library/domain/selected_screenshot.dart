class SelectedScreenshot {
  const SelectedScreenshot({
    required this.path,
    this.mimeType,
    this.capturedAt,
  });

  final String path;
  final String? mimeType;
  final DateTime? capturedAt;
}

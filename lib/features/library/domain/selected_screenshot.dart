import 'capture_app_context.dart';

class SelectedScreenshot {
  const SelectedScreenshot({
    required this.path,
    this.mimeType,
    this.capturedAt,
    this.captureAppContext,
  });

  final String path;
  final String? mimeType;
  final DateTime? capturedAt;
  final CaptureAppContext? captureAppContext;
}

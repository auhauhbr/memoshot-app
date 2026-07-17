import '../../features/library/domain/selected_screenshot.dart';

abstract interface class ScreenshotPicker {
  Future<List<SelectedScreenshot>> pickScreenshots();

  Future<List<SelectedScreenshot>> retrieveLostScreenshots();
}

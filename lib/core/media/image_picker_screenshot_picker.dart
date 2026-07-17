import 'package:image_picker/image_picker.dart';

import '../../features/library/domain/selected_screenshot.dart';
import 'screenshot_picker.dart';

class ImagePickerScreenshotPicker implements ScreenshotPicker {
  ImagePickerScreenshotPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<List<SelectedScreenshot>> pickScreenshots() async {
    final images = await _imagePicker.pickMultiImage();
    return images
        .map((image) => SelectedScreenshot(path: image.path))
        .toList(growable: false);
  }

  @override
  Future<List<SelectedScreenshot>> retrieveLostScreenshots() async {
    final response = await _imagePicker.retrieveLostData();
    if (response.isEmpty) {
      return const [];
    }
    if (response.exception != null) {
      throw response.exception!;
    }

    return (response.files ?? const <XFile>[])
        .map((image) => SelectedScreenshot(path: image.path))
        .toList(growable: false);
  }
}

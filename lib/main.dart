import 'package:flutter/material.dart';

import 'app/memoshot_app.dart';
import 'core/ocr/media_ocr_input.dart';
import 'features/background_processing/background_entrypoint.dart';

void main() {
  runApp(MemoShotApp(mediaOcrInputResolver: createMediaOcrInputResolver()));
}

@pragma('vm:entry-point')
Future<void> memoshotBackgroundEntrypoint() =>
    runMemoShotBackgroundEntrypoint();

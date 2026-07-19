import 'package:flutter/material.dart';

import 'app/memoshot_app.dart';
import 'features/background_processing/background_entrypoint.dart';

void main() {
  runApp(const MemoShotApp());
}

@pragma('vm:entry-point')
Future<void> memoshotBackgroundEntrypoint() =>
    runMemoShotBackgroundEntrypoint();

import 'media_item.dart';

class ScreenshotSearchResult {
  const ScreenshotSearchResult({
    required this.mediaItem,
    required this.snippet,
  });

  final MediaItem mediaItem;
  final String snippet;
}

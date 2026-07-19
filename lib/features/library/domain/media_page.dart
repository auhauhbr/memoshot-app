import 'media_item.dart';

const defaultMediaPageSize = 60;
const maximumMediaPageSize = 60;
const homeRecentMediaItemLimit = 12;

final class MediaPageCursor {
  const MediaPageCursor({required this.capturedAt, required this.id});

  final DateTime capturedAt;
  final int id;
}

final class MediaPageRequest {
  const MediaPageRequest({
    this.cursor,
    this.pageSize = defaultMediaPageSize,
    this.tagIds = const {},
  });

  final MediaPageCursor? cursor;
  final int pageSize;
  final Set<int> tagIds;

  int get effectivePageSize => pageSize.clamp(1, maximumMediaPageSize);
}

final class MediaPage<T> {
  const MediaPage({required this.items, required this.nextCursor});

  final List<T> items;
  final MediaPageCursor? nextCursor;

  bool get hasNextPage => nextCursor != null;

  static MediaPageCursor cursorFor(MediaItem item) =>
      MediaPageCursor(capturedAt: item.effectiveCapturedAt, id: item.id);
}

enum IncomingMediaType { image, other }

class IncomingSharedMedia {
  const IncomingSharedMedia({
    required this.path,
    required this.type,
    this.mimeType,
  });

  final String path;
  final IncomingMediaType type;
  final String? mimeType;
}

abstract interface class IncomingShareSource {
  Future<List<IncomingSharedMedia>> getInitialMedia();

  Stream<List<IncomingSharedMedia>> get mediaStream;

  Future<void> reset();
}

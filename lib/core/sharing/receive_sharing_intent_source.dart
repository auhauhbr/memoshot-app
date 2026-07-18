import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'incoming_share_source.dart';

class ReceiveSharingIntentSource implements IncomingShareSource {
  const ReceiveSharingIntentSource();

  @override
  Future<List<IncomingSharedMedia>> getInitialMedia() async {
    return _map(await ReceiveSharingIntent.instance.getInitialMedia());
  }

  @override
  Stream<List<IncomingSharedMedia>> get mediaStream {
    return ReceiveSharingIntent.instance.getMediaStream().map(_map);
  }

  @override
  Future<void> reset() async {
    await ReceiveSharingIntent.instance.reset();
  }

  List<IncomingSharedMedia> _map(List<SharedMediaFile> files) {
    return files
        .map(
          (file) => IncomingSharedMedia(
            path: file.path,
            mimeType: file.mimeType,
            type: file.type == SharedMediaType.image
                ? IncomingMediaType.image
                : IncomingMediaType.other,
          ),
        )
        .toList(growable: false);
  }
}

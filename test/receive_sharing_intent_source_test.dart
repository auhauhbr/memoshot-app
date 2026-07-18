import 'dart:async';

import 'package:memoshot/core/sharing/incoming_share_source.dart';
import 'package:memoshot/core/sharing/receive_sharing_intent_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  test('mapeia somente o tipo image como imagem recebida', () async {
    final stream = StreamController<List<SharedMediaFile>>.broadcast();
    addTearDown(stream.close);
    ReceiveSharingIntent.setMockValues(
      initialMedia: [
        SharedMediaFile(
          path: '/tmp/imagem.png',
          type: SharedMediaType.image,
          mimeType: 'image/png',
        ),
        SharedMediaFile(
          path: '/tmp/video.mp4',
          type: SharedMediaType.video,
          mimeType: 'video/mp4',
        ),
      ],
      mediaStream: stream.stream,
    );
    const source = ReceiveSharingIntentSource();

    final media = await source.getInitialMedia();

    expect(media.first.type, IncomingMediaType.image);
    expect(media.first.mimeType, 'image/png');
    expect(media.last.type, IncomingMediaType.other);
    await source.reset();
    expect(await source.getInitialMedia(), isEmpty);
  });
}

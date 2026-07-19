import 'dart:async';

import 'package:flutter/services.dart';

const reviewNavigationChannelName =
    'br.com.jeffersont.memoshot/review_navigation';

abstract interface class ReviewNavigationSource {
  Future<void> start(Future<void> Function() onReviewQueueRequested);

  Future<void> dispose();
}

class MethodChannelReviewNavigationSource implements ReviewNavigationSource {
  MethodChannelReviewNavigationSource([
    this._channel = const MethodChannel(reviewNavigationChannelName),
  ]);

  final MethodChannel _channel;
  Future<void> Function()? _onReviewQueueRequested;
  bool _handling = false;

  @override
  Future<void> start(Future<void> Function() onReviewQueueRequested) async {
    _onReviewQueueRequested = onReviewQueueRequested;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'destinationAvailable') await _consume();
    });
    await _consume();
  }

  Future<void> _consume() async {
    if (_handling) return;
    _handling = true;
    try {
      final destination = await _channel.invokeMethod<String>(
        'consumePendingDestination',
      );
      if (destination == 'reviewQueue') {
        await _onReviewQueueRequested?.call();
      }
    } finally {
      _handling = false;
    }
  }

  @override
  Future<void> dispose() async {
    _onReviewQueueRequested = null;
    _channel.setMethodCallHandler(null);
  }
}

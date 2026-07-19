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
  bool _handling = false;

  @override
  Future<void> start(Future<void> Function() onReviewQueueRequested) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'destinationAvailable') await _consume();
    });
    await _consume();
  }

  Future<void> _consume() async {
    if (_handling) return;
    _handling = true;
    try {
      await _channel.invokeMethod<String>('consumePendingDestination');
    } finally {
      _handling = false;
    }
  }

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
  }
}

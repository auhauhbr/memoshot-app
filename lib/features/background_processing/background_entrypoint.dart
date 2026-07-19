import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'background_processing_composition.dart';

const backgroundProcessingChannelName =
    'br.com.jeffersont.memoshot/background_processing';

Future<void> runMemoShotBackgroundEntrypoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  const channel = MethodChannel(backgroundProcessingChannelName);
  BackgroundProcessingComposition? composition;
  String terminalMethod = 'completed';
  Map<String, Object> payload = const <String, Object>{
    'resultCode': 'completed',
  };
  try {
    await channel.invokeMethod<void>('ready');
    composition = BackgroundProcessingComposition.create();
    final summary = await composition.runner.run();
    payload = summary.toChannelPayload();
  } catch (_) {
    terminalMethod = 'retryableFailure';
    payload = <String, Object>{'resultCode': 'runnerFailure'};
  } finally {
    try {
      await composition?.close();
    } catch (_) {
      // O processo headless será encerrado pelo worker após a resposta técnica.
    }
  }
  await channel.invokeMethod<void>(terminalMethod, payload);
}

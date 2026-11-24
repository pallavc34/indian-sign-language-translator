import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sign_language_translator/screens/MainScaffold.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Microphone result signs HELLO twice, word by word, then rests', (
    tester,
  ) async {
    // Audio input is deliberately deterministic. The WebView, GLB renderer,
    // speech plugin result decoding and every playback callback run on device.
    const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var listened = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'listen') listened = true;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    Future<void> until(bool Function() condition, String description) async {
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (!condition() && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 45));
      }
      expect(condition(), isTrue, reason: description);
    }

    Future<void> result(String text, int type) async {
      final payload = jsonEncode({
        'alternates': [
          {'recognizedWords': text, 'confidence': 1.0},
        ],
        'resultType': type,
      });
      final data = const StandardMethodCodec().encodeMethodCall(
        MethodCall('textRecognition', payload),
      );
      await messenger.handlePlatformMessage(channel.name, data, (_) {});
      await tester.pump();
    }

    bool stopVisible() =>
        find.byTooltip('Stop signing').evaluate().isNotEmpty;

    await tester.pumpWidget(const MaterialApp(home: MainScaffold()));
    final mic = find.byTooltip('Microphone');
    await until(
      () => find
          .byWidgetPredicate(
            (widget) =>
                widget is IconButton &&
                widget.tooltip == 'Microphone' &&
                widget.onPressed != null,
          )
          .evaluate()
          .isNotEmpty,
      'Saniya loads and enables the microphone',
    );
    await tester.tap(mic);
    await until(() => listened, 'The microphone starts the speech recognizer');
    await result('hel', 0);
    expect(stopVisible(), isFalse);
    await result('Hello hello!', 2);
    await until(stopVisible, 'Playback starts after the final transcript');
    await until(() => !stopVisible(), 'Playback finishes and Saniya rests');
    await tester.tap(find.text('Hello'));
    await until(stopVisible, 'Replay starts');
    await tester.tap(find.byTooltip('Stop signing'));
    await until(() => !stopVisible(), 'Stop cancels playback');
    expect(tester.takeException(), isNull);
  });
}

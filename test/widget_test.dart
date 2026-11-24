import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sign_language_translator/screens/SignsToSpeechTranslator.dart';

void main() {
  testWidgets('Signs to Speech adds and removes selected letters',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignsToSpeechTranslator()));

    const emptyPrompt = 'Tap signs to build words...';
    final letterA = find.byWidgetPredicate(
      (widget) =>
          widget is Image && widget.image == const AssetImage('images/a.png'),
    );
    expect(find.text(emptyPrompt), findsOneWidget);

    await tester.tap(letterA);
    await tester.pump();
    expect(find.text('a'), findsOneWidget);

    await tester.tap(find.byTooltip('Backspace'));
    await tester.pump();
    expect(find.text(emptyPrompt), findsOneWidget);
  });
}

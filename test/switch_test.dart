import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sign_language_translator/screens/MainScaffold.dart';
import 'package:sign_language_translator/widgets/ModeSwitch.dart';

void main() {
  testWidgets('mode switch toggles between the two screens', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MainScaffold()));
    await tester.pump();

    expect(find.text('Say or type a word'), findsOneWidget);
    await tester.tap(find.byType(ModeSwitch));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tap signs to build words...'), findsOneWidget);

    await tester.tap(find.byType(ModeSwitch));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Say or type a word'), findsOneWidget);
  });
}

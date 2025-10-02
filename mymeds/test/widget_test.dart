// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:mymeds/main.dart';

void main() {
  testWidgets('MyMeds app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyMedsApp());

    // Verify that our home screen is displayed
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('Ver mapa de farmacias'), findsOneWidget);
    expect(find.text('Sube tu prescripción'), findsOneWidget);
    expect(find.text('Ver tu perfil'), findsOneWidget);
  });
}

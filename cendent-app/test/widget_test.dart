import 'package:flutter_test/flutter_test.dart';
import 'package:cendent_app/main.dart';

void main() {
  testWidgets('App arranca sin token', (WidgetTester tester) async {
    await tester.pumpWidget(const CendentApp(session: null));
    await tester.pumpAndSettle();
    expect(find.text('CENDENT'), findsWidgets);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:cendent_app/main.dart';

void main() {
  testWidgets('App arranca sin token', (WidgetTester tester) async {
    await tester.pumpWidget(const CendentApp(session: null));
    await tester.pumpAndSettle();
    // Sin sesión hay que caer en el login. Se comprueba contra lo que esa
    // pantalla dibuja de verdad: la marca sólo aparece como título del
    // MaterialApp (que no es un widget de texto) y en la barra lateral del
    // HomeScreen, que aquí no llega a montarse.
    expect(find.text('SGIAP'), findsOneWidget);
    expect(find.text('Inicio de sesión'), findsOneWidget);
  });
}

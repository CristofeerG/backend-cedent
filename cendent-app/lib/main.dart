import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await AuthService().getSavedSession();
  runApp(CendentApp(session: session));
}

class CendentApp extends StatelessWidget {
  final LoginResult? session;
  const CendentApp({super.key, this.session});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CEDENT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: session != null
          ? HomeScreen(
              idSucursal: session!.idSucursal,
              rol: session!.rol,
              nomUsuario: session!.nomUsuario,
              nomSucursal: session!.nomSucursal,
            )
          : const LoginScreen(),
    );
  }
}

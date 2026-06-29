import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginResult {
  final String accessToken;
  final int idUsuario;
  final String nomUsuario;
  final String rol;
  final int idSucursal;
  final String nomSucursal;
  const LoginResult({
    required this.accessToken,
    required this.idUsuario,
    required this.nomUsuario,
    required this.rol,
    required this.idSucursal,
    required this.nomSucursal,
  });
}

class AuthService {
  static const String _baseUrl = 'http://localhost:3000';
  static const _kToken = 'access_token';
  static const _kNomUsuario = 'nom_usuario';
  static const _kRol = 'rol';
  static const _kIdSucursal = 'id_sucursal';
  static const _kNomSucursal = 'nom_sucursal';

  Future<({LoginResult? result, String? error})> login(
      String nomUsuario, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nom_usuario': nomUsuario, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String?;
        if (token == null) {
          return (result: null, error: 'Respuesta inesperada del servidor');
        }

        final idSucursal = (data['id_sucursal'] as int?) ?? 1;
        final nom = data['nom_usuario'] as String? ?? nomUsuario;
        final rol = data['rol'] as String? ?? 'usuario';
        final nomSucursal = data['nom_sucursal'] as String? ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kToken, token);
        await prefs.setString(_kNomUsuario, nom);
        await prefs.setString(_kRol, rol);
        await prefs.setInt(_kIdSucursal, idSucursal);
        await prefs.setString(_kNomSucursal, nomSucursal);

        return (
          result: LoginResult(
            accessToken: token,
            idUsuario: data['id_usuario'] as int? ?? 0,
            nomUsuario: nom,
            rol: rol,
            idSucursal: idSucursal,
            nomSucursal: nomSucursal,
          ),
          error: null,
        );
      }

      return (result: null, error: 'Usuario o contraseña incorrectos');
    } catch (_) {
      return (result: null, error: 'No se pudo conectar con el servidor');
    }
  }

  Future<LoginResult?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    if (token == null) return null;
    return LoginResult(
      accessToken: token,
      idUsuario: 0,
      nomUsuario: prefs.getString(_kNomUsuario) ?? 'Usuario',
      rol: prefs.getString(_kRol) ?? 'usuario',
      idSucursal: prefs.getInt(_kIdSucursal) ?? 1,
      nomSucursal: prefs.getString(_kNomSucursal) ?? '',
    );
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kNomUsuario);
    await prefs.remove(_kRol);
    await prefs.remove(_kIdSucursal);
    await prefs.remove(_kNomSucursal);
  }
}

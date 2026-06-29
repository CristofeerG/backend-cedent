import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();

  bool _cargando = false;
  bool _verPassword = false;
  String? _errorMensaje;

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    final (:result, :error) = await _authService.login(
      _usuarioCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;

    if (result != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            idSucursal: result.idSucursal,
            rol: result.rol,
            nomUsuario: result.nomUsuario,
            nomSucursal: result.nomSucursal,
          ),
        ),
      );
    } else {
      setState(() {
        _errorMensaje = error;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F7),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        _buildLogo(),
                        const SizedBox(height: 24),
                        _buildCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildFooter(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        SvgPicture.asset(
          'assets/images/LogoCendent.svg',
          width: 180,
        ),
        const SizedBox(height: 16),
        const Text(
          'SGIAP',
          style: TextStyle(
            color: Colors.black,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sistema de Gestión de Inventario y Analítica Predictiva',
          style: TextStyle(
            color: Color.fromARGB(255, 81, 170, 243),
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Inicio de sesión',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D1B2A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ingresa tus credenciales para continuar',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF78909C),
              ),
            ),
            const SizedBox(height: 28),

            // Campo usuario
            _buildLabel('Usuario'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _usuarioCtrl,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                hint: 'Nombre de usuario',
                icon: Icons.person_outline_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa tu usuario' : null,
            ),
            const SizedBox(height: 20),

            // Campo contraseña
            _buildLabel('Contraseña'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: !_verPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _iniciarSesion(),
              decoration: _inputDecoration(
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _verPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF90A4AE),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _verPassword = !_verPassword),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
            ),
            const SizedBox(height: 12),

            // Mensaje de error
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _errorMensaje != null
                  ? Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEF9A9A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFC62828), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMensaje!,
                              style: const TextStyle(
                                color: Color(0xFFC62828),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Botón
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _cargando ? null : _iniciarSesion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF90CAF9),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _cargando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Ingresar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF37474F),
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Daniel's CENDENT S.A.  ·  Centro de Especialidades Odontológicas",
            style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            '© 2026 — Todos los derechos reservados',
            style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF90A4AE), size: 20),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF1976D2), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF5350)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFFEF5350), width: 1.5),
      ),
    );
  }
}

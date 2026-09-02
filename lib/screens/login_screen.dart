import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _cargando = false;
  String? _error;

  Future<void> _iniciarSesion() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final usuario = await AuthService().iniciarSesionConGoogle();
      if (usuario == null && mounted) {
        setState(() => _cargando = false); // canceló el login
      }
      // Si sí inició sesión, el AuthGate en main.dart se encarga de
      // redirigir automáticamente a la pantalla que corresponda.
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo iniciar sesión: $e';
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', height: 150),
                const SizedBox(height: 20),
                const Text(
                  'REGISTROS PRV TRANSITO',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Inicia sesión con tu cuenta de Google institucional para continuar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  icon: _cargando
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.login),
                  label: Text(_cargando ? 'Ingresando...' : 'Iniciar sesión con Google'),
                  onPressed: _cargando ? null : _iniciarSesion,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

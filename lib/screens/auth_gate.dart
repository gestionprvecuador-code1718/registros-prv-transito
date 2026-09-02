import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'identificacion_screen.dart';
import 'pendiente_screen.dart';
import 'home_screen.dart';

/// Controla el flujo de acceso: sin sesión -> Login; con sesión pero sin
/// perfil -> Identificación (pedir PRV); con perfil pero no aprobado ->
/// Pendiente; aprobado -> Home (la app de verdad).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().cambiosDeSesion,
      builder: (context, snapshotAuth) {
        if (snapshotAuth.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final usuario = snapshotAuth.data;
        if (usuario == null) return const LoginScreen();

        return StreamBuilder(
          stream: AuthService().observarPerfil(usuario.uid),
          builder: (context, snapshotPerfil) {
            if (snapshotPerfil.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final datos = snapshotPerfil.data?.data();
            if (datos == null) return IdentificacionScreen(usuario: usuario);

            final aprobado = datos['aprobado'] == true;
            if (!aprobado) return PendienteScreen(patio: datos['patio'] ?? '');

            return const HomeScreen();
          },
        );
      },
    );
  }
}

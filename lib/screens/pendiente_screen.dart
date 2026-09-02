import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class PendienteScreen extends StatelessWidget {
  final String patio;
  const PendienteScreen({super.key, required this.patio});

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
                const Icon(Icons.hourglass_top, size: 72, color: Colors.orange),
                const SizedBox(height: 20),
                const Text(
                  'Solicitud pendiente de aprobación',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu solicitud para "$patio" fue enviada. Un administrador debe aprobarla antes de que puedas usar la app. '
                  'Esta pantalla se actualiza sola en cuanto te aprueben.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                  onPressed: () => AuthService().cerrarSesion(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

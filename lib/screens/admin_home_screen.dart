import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_usuarios_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_login_screen.dart';

/// Home del panel de administrador. Se llega aquí solo después de un
/// login exitoso en AdminLoginScreen con esAdmin == true.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Nacional'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _botonGrande(
              context,
              icon: Icons.people,
              titulo: 'Usuarios',
              subtitulo: 'Aprobar, rechazar y revocar acceso de policías',
              color: Colors.blue.shade700,
              destino: const AdminUsuariosScreen(),
            ),
            const SizedBox(height: 16),
            _botonGrande(
              context,
              icon: Icons.bar_chart,
              titulo: 'Dashboard',
              subtitulo: 'Productividad por CRV / patio a nivel nacional',
              color: Colors.teal.shade700,
              destino: const AdminDashboardScreen(),
            ),
            // Aquí se agregarán más adelante: catálogo de patios/CRV,
            // reportes exportables, auditoría de pagos, etc.
          ],
        ),
      ),
    );
  }

  Widget _botonGrande(
    BuildContext context, {
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required Color color,
    required Widget destino,
  }) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destino),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

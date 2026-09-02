import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'screens/admin_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RegistrosPrvApp());
}

class RegistrosPrvApp extends StatelessWidget {
  const RegistrosPrvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REGISTROS PRV TRANSITO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1B4B8F), // azul institucional
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFF1B4B8F),
          foregroundColor: Colors.white,
        ),
      ),
      // La app normal de los policías sigue en "/" tal cual estaba.
      // El panel de administrador vive exclusivamente en "/admin".
      routes: {
        '/': (context) => const AuthGate(),
        '/admin': (context) => const AdminLoginScreen(),
      },
      initialRoute: Uri.base.path.startsWith('/admin') ? '/admin' : '/',
    );
  }
}

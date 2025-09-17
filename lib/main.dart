import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // 👈 para saber si hay sesión
import 'ui/home_screen.dart';
import 'ui/theme/app_theme.dart';

// 👉 Usa ClientesScreen como "Perfil" principal por ahora.
// Si tu pantalla de Perfil tiene otro nombre, luego cambiamos este import.
import 'ui/clientes_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MiReciboApp());
}

class MiReciboApp extends StatelessWidget {
  const MiReciboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mi Recibo',
      theme: AppTheme.materialTheme,
      home: const _StartGate(), // 👈 decide a dónde entrar según sesión
      routes: {
        // '/prestamista/registro': (context) => PrestamistaRegistroScreen(),
        // '/trabajador/registro':  (context) => TrabajadorRegistroScreen(),
      },
    );
  }
}

// 🔐 Puerta de inicio: si hay sesión -> Clientes (Perfil). Si no -> Home (Google).
class _StartGate extends StatelessWidget {
  const _StartGate();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Ya logueado -> pantalla principal (Perfil/Clientes)
      return const ClientesScreen();
    }
    // No logueado -> Home (botón Google)
    return const HomeScreen();
  }
}
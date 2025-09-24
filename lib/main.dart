import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 🌍 localización
import 'package:firebase_core/firebase_core.dart'; // Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // 👈 para saber si hay sesión
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔐 leer settings pin/biometría
import 'package:local_auth/local_auth.dart'; // 👆 huella/FaceID

import 'ui/home_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/clientes_screen.dart'; // Perfil / Clientes
import 'ui/pin_screen.dart'; // (si existe) pantalla de PIN

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

      // ✅ Español (incluye DatePicker/calendario en español)
      locale: const Locale('es'), // fuerza español; quítalo si quieres seguir el idioma del sistema
      supportedLocales: const [
        Locale('es', 'DO'),
        Locale('es', 'ES'),
        Locale('es'),
        Locale('en', 'US'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const _StartGate(), // 👈 decide a dónde entrar según sesión + PIN/huella
      routes: {
        // '/prestamista/registro': (context) => PrestamistaRegistroScreen(),
        // '/trabajador/registro':  (context) => TrabajadorRegistroScreen(),
      },
    );
  }
}

/// 🔐 Puerta de inicio y re-bloqueo al volver a foreground.
/// Reglas:
/// - Si no hay sesión -> HomeScreen.
/// - Si hay sesión:
///   - Leer prestamistas/{uid}.settings.{pinEnabled, biometria}
///   - Si ambos desactivados -> ClientesScreen.
///   - Si biometría ON -> intentar autenticar con huella/FaceID.
///       - Si OK -> ClientesScreen.
///       - Si falla/cancela -> si PIN ON -> PinScreen (fallback).
///   - Si solo PIN ON -> PinScreen.
class _StartGate extends StatefulWidget {
  const _StartGate();

  @override
  State<_StartGate> createState() => _StartGateState();
}

class _StartGateState extends State<_StartGate> with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _localAuth = LocalAuthentication();

  bool _checking = true;
  bool _unlocked = false; // estado de sesión desbloqueada dentro de la app

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _routeAccordingToState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-bloqueo al volver a primer plano si hay PIN/biometría configurados
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Solo re-evaluar si ya habíamos desbloqueado antes
      if (_unlocked) {
        _routeAccordingToState(relock: true);
      }
    }
  }

  Future<Map<String, dynamic>> _readSecuritySettings(User user) async {
    final snap = await _db.collection('prestamistas').doc(user.uid).get();
    final data = snap.data() ?? {};
    final settings = (data['settings'] as Map?) ?? {};
    return {
      'pinEnabled': settings['pinEnabled'] == true,
      'biometria': settings['biometria'] == true,
    };
  }

  Future<void> _routeAccordingToState({bool relock = false}) async {
    setState(() => _checking = true);

    final user = _auth.currentUser;
    if (user == null) {
      _unlocked = false;
      _replace(const HomeScreen());
      return;
    }

    final sec = await _readSecuritySettings(user);
    final pinOn = sec['pinEnabled'] == true;
    final bioOn = sec['biometria'] == true;

    // Si no hay seguridad activa, entrar directo.
    if (!pinOn && !bioOn) {
      _unlocked = true;
      _replace(const ClientesScreen());
      return;
    }

    // Intentar biometría primero si está activa
    if (bioOn) {
      final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (canCheck) {
        try {
          final ok = await _localAuth.authenticate(
            localizedReason: 'Autentícate para continuar',
            options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
          );
          if (ok) {
            _unlocked = true;
            _replace(const ClientesScreen());
            return;
          }
        } catch (_) {
          // si falla, cae al PIN si existe
        }
      }
      // Si biometría no está disponible o falló, usar PIN si está activo
      if (pinOn) {
        _goPin();
        return;
      }
      // Si no hay PIN, última opción: Home (por seguridad)
      _unlocked = false;
      _replace(const HomeScreen());
      return;
    }

    // Solo PIN
    if (pinOn) {
      _goPin();
      return;
    }

    // Fallback: entrar si nada aplica
    _unlocked = true;
    _replace(const ClientesScreen());
  }

  void _goPin() {
    _unlocked = false;
    // Navega a la pantalla de PIN esperando resultado.
    // Se asume que PinScreen hace Navigator.pop(context, true/false) al validar/cancelar.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PinScreen()),
      );
      if (ok == true && mounted) {
        _unlocked = true;
        _replace(const ClientesScreen());
      } else if (mounted) {
        // Si canceló o falló el PIN, llevar a Home por seguridad.
        _unlocked = false;
        _replace(const HomeScreen());
      }
    });
  }

  void _replace(Widget page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => page),
            (r) => false,
      );
      setState(() => _checking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pantalla mínima mientras decide
    return Scaffold(
      body: Center(
        child: _checking
            ? const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.8),
        )
            : const SizedBox.shrink(),
      ),
    );
  }
}

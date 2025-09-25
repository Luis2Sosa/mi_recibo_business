import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 🌍 localización
import 'package:firebase_core/firebase_core.dart'; // Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // 👈 para saber si hay sesión
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔐 leer settings lockEnabled

import 'ui/home_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/clientes_screen.dart'; // Perfil / Clientes
import 'ui/pin_screen.dart'; // Pantalla de PIN/biometría

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

      home: const _StartGate(), // 👈 decide a dónde entrar según sesión + lockEnabled
    );
  }
}

/// 🔐 Puerta de inicio y re-bloqueo al volver a foreground.
/// Reglas:
/// - Si no hay sesión -> HomeScreen.
/// - Si hay sesión -> leer prestamistas/{uid}.settings.lockEnabled
///   - lockEnabled = false -> ClientesScreen.
///   - lockEnabled = true  -> mostrar PinScreen (ofrece PIN o huella).
class _StartGate extends StatefulWidget {
  const _StartGate();

  @override
  State<_StartGate> createState() => _StartGateState();
}

class _StartGateState extends State<_StartGate> with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _checking = true;
  bool _unlocked = false;     // si ya se desbloqueó esta sesión en foreground
  bool _lockEnabled = false;  // configuración leída del perfil

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

  // Re-bloqueo al volver a primer plano si el switch está activo
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_unlocked && _lockEnabled) {
        _guardedUnlock(relock: true);
      }
    }
  }

  Future<Map<String, dynamic>> _readSettings(User user) async {
    final snap = await _db.collection('prestamistas').doc(user.uid).get();
    final data = snap.data() ?? {};
    final settings = (data['settings'] as Map?) ?? {};
    return {
      // 👇 único switch que gobierna bloqueo por PIN/biometría
      'lockEnabled': settings['lockEnabled'] == true,
    };
  }

  Future<void> _routeAccordingToState() async {
    setState(() => _checking = true);

    final user = _auth.currentUser;
    if (user == null) {
      _unlocked = false;
      _replace(const HomeScreen());
      return;
    }

    final s = await _readSettings(user);
    _lockEnabled = s['lockEnabled'] == true;

    if (!_lockEnabled) {
      _unlocked = true;
      _replace(const ClientesScreen());
      return;
    }

    await _guardedUnlock();
  }

  /// Muestra PinScreen. Si valida (PIN o huella), va a ClientesScreen; si falla/cancela, a Home.
  Future<void> _guardedUnlock({bool relock = false}) async {
    _unlocked = false;
    setState(() => _checking = true);

    // Navega a la pantalla de PIN/huella esperando resultado (true/false)
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PinScreen()),
    );

    if (!mounted) return;

    if (ok == true) {
      _unlocked = true;
      _replace(const ClientesScreen());
    } else {
      _unlocked = false;
      _replace(const HomeScreen());
    }
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

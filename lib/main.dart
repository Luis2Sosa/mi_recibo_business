import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 🌍 localización
import 'package:firebase_core/firebase_core.dart'; // Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // 👈 para saber si hay sesión
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔐 leer settings lockEnabled
import 'package:firebase_messaging/firebase_messaging.dart'; // 🔔 FCM

import 'ui/home_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/clientes_screen.dart'; // Perfil / Clientes
import 'ui/pin_screen.dart'; // Pantalla de PIN/biometría
// 🔔 Notificaciones Plus
import 'core/notifications_plus.dart';

/// 🔔 Handler de mensajes en background/terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Aquí podrías registrar métricas si quieres
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🔔 FCM básico (background)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _setupFCM(); // registra token + handlers

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
      scaffoldMessengerKey: NotificationsPlus.messengerKey,
      navigatorKey: NotificationsPlus.navigatorKey,

      // ✅ Localización: soporta ES/EN y respeta el idioma del sistema
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
      localeResolutionCallback: (deviceLocale, supported) {
        if (deviceLocale == null) return const Locale('es', 'DO');
        for (final l in supported) {
          if (l.languageCode == deviceLocale.languageCode) {
            return deviceLocale;
          }
        }
        return const Locale('es', 'DO');
      },

      home: const _StartGate(), // 👈 decide a dónde entrar según sesión + lockEnabled
    );
  }
}

/// 🔗 Helpers para abrir Clientes con intención (vencidos / hoy / pronto)
class AppIntents {
  static void openClientesVencidos(BuildContext context) {
    _openClientesWithIntent(context, 'vencidos');
  }

  static void openClientesHoy(BuildContext context) {
    _openClientesWithIntent(context, 'hoy');
  }

  static void openClientesPronto(BuildContext context) {
    _openClientesWithIntent(context, 'pronto');
  }

  static void _openClientesWithIntent(BuildContext context, String intent) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const ClientesScreen(),
        settings: RouteSettings(arguments: {'intent': intent}),
      ),
          (r) => false,
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
      // 🔔 Notificaciones Plus: app abierta sin PIN -> dispara recordatorios
      NotificationsPlus.onAppOpen(user.uid);
      // Sin intención especial al entrar normal
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
      // 🔔 Notificaciones Plus: app abierta tras desbloquear -> dispara recordatorios
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        NotificationsPlus.onAppOpen(uid);
      }
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
      // (El setState para _checking=false es redundante aquí porque esta vista se reemplaza)
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

/// ========= Navegación desde PUSH =========
void _routeFromPushIntent(String? intent) {
  if (intent == null || intent.isEmpty) return;
  final ctx = NotificationsPlus.navigatorKey.currentState?.context;
  if (ctx == null) return;

  switch (intent) {
    case 'vencidos':
      AppIntents.openClientesVencidos(ctx);
      break;
    case 'hoy':
      AppIntents.openClientesHoy(ctx);
      break;
    case 'pronto':
      AppIntents.openClientesPronto(ctx);
      break;
    default:
    // ignorar intents desconocidos
      break;
  }
}

/// 👇 NUEVO: helper para guardar/actualizar el token del usuario activo
Future<void> _writeFcmToken(String uid) async {
  final t = await FirebaseMessaging.instance.getToken();
  if (t != null) {
    await FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .set({
      'meta': {
        'fcmToken': t,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }
}

/// 🔔 Setup FCM: permisos, token y handlers
Future<void> _setupFCM() async {
  final messaging = FirebaseMessaging.instance;

  // Permiso (Android 13 requiere POST_NOTIFICATIONS en manifest)
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // Guarda token si ya hay sesión (centralizado)
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    await _writeFcmToken(uid);
  }

  // Si el token cambia (centralizado)
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      await _writeFcmToken(u.uid);
    }
  });

  // Foreground: muestra banner premium usando tu messengerKey (sin tocar otros archivos)
  FirebaseMessaging.onMessage.listen((msg) {
    final title = msg.notification?.title?.trim();
    final body  = msg.notification?.body?.trim();
    final parts = <String>[];
    if (title != null && title.isNotEmpty) parts.add(title);
    if (body  != null && body .isNotEmpty) parts.add(body);
    final text = parts.join(' · ');

    final messenger = NotificationsPlus.messengerKey.currentState;
    if (messenger == null || text.isEmpty) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          duration: const Duration(seconds: 2),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      );
  });

  // 👇 NUEVO: si la app se abrió desde CERRADA por tocar la notificación
  final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMsg != null) {
    _routeFromPushIntent(initialMsg.data['intent'] as String?);
  }

  // 👇 NUEVO: si la app estaba en background y la abren tocando la notificación
  FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    _routeFromPushIntent(msg.data['intent'] as String?);
  });

  // 👇 NUEVO: si el usuario inicia/cambia sesión después de arrancar, sube el token automáticamente
  FirebaseAuth.instance.authStateChanges().listen((u) {
    if (u != null) {
      _writeFcmToken(u.uid);
    }
  });
}

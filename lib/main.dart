import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'firebase_options.dart'; // ⭐ AGREGADO PARA WEB
import 'ui/home_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/clientes/clientes_screen.dart';
import 'ui/pin_screen.dart';
import 'core/notifications_plus.dart';
import 'ui/clientes/auto_filtro_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // ⭐ AGREGADO
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ INICIALIZACIÓN CORRECTA PARA ANDROID / iOS / WEB
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MiReciboApp());

  Future.microtask(_setupFCM);
  Future.microtask(SyncOfflinePagos.iniciar);
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
        return supported.firstWhere(
              (l) => l.languageCode == deviceLocale.languageCode,
          orElse: () => const Locale('es', 'DO'),
        );
      },

      home: const _StartGate(),
      routes: {
        '/clientes': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          final filtro = args?['initFiltro'] ?? 'prestamos';
          return ClientesScreen(initFiltro: filtro);
        },
      },
    );
  }
}

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

class _StartGate extends StatefulWidget {
  const _StartGate();

  @override
  State<_StartGate> createState() => _StartGateState();
}

class _StartGateState extends State<_StartGate> with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _checking = true;
  bool _unlocked = false;
  bool _lockEnabled = false;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_unlocked && _lockEnabled) {
        _guardedUnlock(relock: true);
      }
    }
  }

  Future<Map<String, dynamic>> _readSettings(User user) async {
    try {
      final snap = await _db
          .collection('prestamistas')
          .doc(user.uid)
          .get(const GetOptions(source: Source.cache));
      final data = snap.data() ?? {};
      final settings = (data['settings'] as Map?) ?? {};
      return {'lockEnabled': settings['lockEnabled'] == true};
    } catch (_) {}

    try {
      final snap = await _db
          .collection('prestamistas')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 4));
      final data = snap.data() ?? {};
      final settings = (data['settings'] as Map?) ?? {};
      return {'lockEnabled': settings['lockEnabled'] == true};
    } catch (_) {
      return {'lockEnabled': false};
    }
  }

  Future<void> _routeAccordingToState() async {
    setState(() => _checking = true);

    try {
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

        NotificationsPlus.onAppOpen(user.uid);

        final preferido = await AutoFiltroService.elegirFiltroPreferido();
        _replace(
          const ClientesScreen(),
          args: {'initFiltro': preferido.toString().split('.').last},
        );
        return;
      }

      await _guardedUnlock();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _guardedUnlock({bool relock = false}) async {
    _unlocked = false;
    setState(() => _checking = true);

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PinScreen()),
    );

    if (!mounted) return;

    if (ok == true) {
      _unlocked = true;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        NotificationsPlus.onAppOpen(uid);
      }

      final preferido = await AutoFiltroService.elegirFiltroPreferido();
      _replace(
        const ClientesScreen(),
        args: {'initFiltro': preferido.toString().split('.').last},
      );
    } else {
      _unlocked = false;
      _replace(const HomeScreen());
    }
  }

  void _replace(Widget page, {Map<String, dynamic>? args}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => page,
          settings: RouteSettings(arguments: args),
        ),
            (r) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
      break;
  }
}

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

Future<void> _setupFCM() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(alert: true, badge: true, sound: true);

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    await _writeFcmToken(uid);
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      await _writeFcmToken(u.uid);
    }
  });

  FirebaseMessaging.onMessage.listen((msg) {
    final title = msg.notification?.title?.trim();
    final body = msg.notification?.body?.trim();
    final parts = <String>[];
    if (title != null && title.isNotEmpty) parts.add(title);
    if (body != null && body.isNotEmpty) parts.add(body);
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

  final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMsg != null) {
    _routeFromPushIntent(initialMsg.data['intent'] as String?);
  }

  FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    _routeFromPushIntent(msg.data['intent'] as String?);
  });

  FirebaseAuth.instance.authStateChanges().listen((u) {
    if (u != null) {
      _writeFcmToken(u.uid);
    }
  });
}

class SyncOfflinePagos {
  static StreamSubscription<ConnectivityResult>? _sub;

  static void iniciar() {
    final subscription = Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        await _sincronizarPendientes();
      }
    });

    _sub = subscription as StreamSubscription<ConnectivityResult>;
  }

  static Future<void> _sincronizarPendientes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;

    try {
      final clientesSnap = await db
          .collection('prestamistas')
          .doc(user.uid)
          .collection('clientes')
          .get();

      for (final clienteDoc in clientesSnap.docs) {
        final pagosSnap = await clienteDoc.reference
            .collection('pagos')
            .where('pendienteSync', isEqualTo: true)
            .get();

        for (final pago in pagosSnap.docs) {
          await pago.reference.update({
            'pendienteSync': false,
            'fecha': FieldValue.serverTimestamp(),
          });
        }
      }

      debugPrint('✅ Pagos offline sincronizados correctamente');
    } catch (e) {
      debugPrint('⚠️ Error sincronizando pagos offline: $e');
    }
  }

  static void detener() {
    _sub?.cancel();
  }
}
